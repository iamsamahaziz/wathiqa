pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DOCKER_HOST  = "tcp://host.docker.internal:2375"
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
        // Ports dynamiques pour l'accès externe utilisateur
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
    }

    stages {

        stage('1. Démarrage') {
            steps {
                script {
                    // Détection robuste de la branche (Slug)
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_default"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    // Configuration DNS interne (Docker à Docker)
                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Ce pipeline est réservé aux branches feature/. Utilisez la branche main pour la prod."
                    }
                    
                    checkout scm
                    echo "--- Initialisation Pipeline Isolé ---"
                    echo "Branche  : ${rawBranch}"
                    echo "Slug DNS : ${env.BRANCH_SLUG}"
                    echo "Commit   : ${env.GIT_COMMIT?.take(8)}"
                }
            }
        }

        stage('2. Vérification Globale') {
            parallel {
                stage('Structure du Projet') {
                    steps {
                        sh '''
                        echo "--- Inventaire du dépôt ---"
                        find . -maxdepth 2 -not -path '*/.*'
                        echo "--- Documents RAG ---"
                        [ -d "documents" ] && ls -1 documents | wc -l | xargs echo "Documents trouvés :" || echo "Dossier documents MANQUANT"
                        '''
                    }
                }
                stage('Contrôle Qualité (Audit)') {
                    steps {
                        sh '''
                        echo "=== 1. Scan Python ==="
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +
                        
                        echo "=== 2. Validation JSON ==="
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open('{}'))" \\; -print
                        
                        echo "=== 3. Audit HTML/YAML ==="
                        find . -name "*.html" ! -path "*/venv/*" ! -path "*/.*" -exec grep -qE "<html>|<head>|<body>" {} \\; -print
                        [ -s "Wathiqa.bpz" ] && echo "Wathiqa.bpz : OK"
                        '''
                    }
                }
            }
        }

        stage('3. Lancement des Services Isolés') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    // Utilisation du réseau fstm_network partagé
                    sh 'docker network create fstm_network || true'

                    sh """
                    docker run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant
                    docker run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n
                    """
                    
                    echo "Services lancés. Attente de stabilisation..."
                    sleep 15
                }
            }
        }

        stage('4. Vérification des Services') {
            parallel {
                stage('Qdrant (Isolé)') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                echo "Qdrant ne répond pas, tentative de redémarrage..."
                                sh "docker restart qdrant_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "Qdrant injoignable sur ${env.QDRANT_URL}"
                            echo "Qdrant Isolé : OK"
                        }
                    }
                }
                stage('n8n (Isolé)') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                echo "n8n ne répond pas, tentative de redémarrage..."
                                sh "docker restart n8n_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "n8n injoignable sur ${env.N8N_URL}"
                            echo "n8n Isolé : OK"
                        }
                    }
                }
                stage('Botpress (Cloud)') {
                    steps {
                        script {
                            def ok = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                            echo "Botpress : ${ok ? 'OK' : 'AVERTISSEMENT (Non bloquant)'}"
                        }
                    }
                }
            }
        }

        stage('5. Installation & Dépendances') {
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install --upgrade pip --quiet
                "$PIP" install -r requirements.txt --quiet
                '''
            }
        }

        stage('6. Indexation IA (Load)') {
            steps {
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh """
                    export MISTRAL_KEY=\$MISTRAL_KEY
                    export QDRANT_URL=${env.QDRANT_URL}
                    "\$PYTHON" load.py
                    """
                }
                // Vérification de l'indexation (Logique identique au main)
                sh """
                COLLECTIONS=\$(curl -sf "${env.QDRANT_URL}/collections" | python3 -c "
import sys, json
data = json.load(sys.stdin)
cols = data.get('result', {}).get('collections', [])
print(len(cols))
")
                [ "\$COLLECTIONS" -gt 0 ] && echo "Indexation réussie : \$COLLECTIONS collection(s) trouvée(s)." || { echo "Erreur : Aucune collection indexée."; exit 1; }
                """
            }
        }

        stage('7. Prêt pour Tests') {
            steps {
                script {
                    echo "=== ENVIRONNEMENT DE DÉVELOPPEMENT PRÊT ==="
                    echo "Branche : ${env.BRANCH_SLUG}"
                    echo "Accès Navigateur Qdrant : http://localhost:${env.QDRANT_PORT}"
                    echo "Accès Navigateur n8n    : http://localhost:${env.N8N_PORT}"
                    echo "Accès Interne DNS       : ${env.QDRANT_URL}"
                }
            }
        }
    }

    post {
        success { echo "Pipeline Succès — Branche ${env.BRANCH_SLUG} opérationnelle." }
        failure {
            script {
                echo "Pipeline Échec — Nettoyage des services isolés..."
                sh "docker stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "docker rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

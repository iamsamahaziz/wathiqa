pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
        // Les ports sont conservés uniquement pour l'accès externe par l'utilisateur
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
    }

    stages {

        stage('1. Demarrage') {
            steps {
                script {
                    // Correction pour le cas où BRANCH_NAME est null (Pipeline standard)
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_default"
                    // On retire le préfixe 'origin/' si présent et on nettoie
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    // Configuration du DNS Interne (Docker à Docker)
                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Ce pipeline est pour les branches feature/ uniquement. Faites : git checkout -b feature/votre-nom"
                    }
                    checkout scm
                    echo "Branche Detectee : ${rawBranch}"
                    echo "Slug Utilisé     : ${env.BRANCH_SLUG}"
                    echo "Internal DNS     : ${env.QDRANT_URL}"
                    echo "Developpeur      : ${env.GIT_AUTHOR_NAME ?: 'inconnu'}"
                    echo "Commit           : ${env.GIT_COMMIT?.take(8)}"
                }
            }
        }

        stage('2. Verification des Fichiers') {
            parallel {

                stage('Structure du Projet') {
                    steps {
                        sh '''
                        echo "--- Fichiers du projet ---"
                        find . -maxdepth 2 -not -path '*/.*'
                        echo "--- Documents ---"
                        [ -d "documents" ] && ls -1 documents | wc -l | xargs echo "Nombre de documents :" || echo "Dossier documents manquant"
                        '''
                    }
                }

                stage('Qualite du Code') {
                    steps {
                        sh '''
                        echo "--- Verification Python ---"
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +

                        echo "--- Verification JSON ---"
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open('{}'))" \\; -print

                        echo "--- Verification YAML ---"
                        find . -name "*.yml" -o -name "*.yaml" ! -path "*/.*" -exec echo "OK: {}" \\;

                        echo "--- Verification HTML ---"
                        find . -name "*.html" ! -path "*/venv/*" ! -path "*/.*" -exec grep -qE "<html>|<head>|<body>" {} \\; -print || echo "Attention : HTML mal forme"

                        echo "--- Fichiers importants ---"
                        [ -s "Wathiqa.bpz" ] && echo "Wathiqa.bpz : OK" || echo "Wathiqa.bpz : manquant ou vide"
                        [ -d "documents" ] && find documents -type f -not -empty | wc -l | xargs echo "Documents OK :" || echo "Pas de documents"
                        '''
                    }
                }
            }
        }

        stage('3. Lancement des Services') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG

                    sh 'docker network create fstm_network || true'

                    sh """
                    docker run -d \
                        --name qdrant_${slug} \
                        --network fstm_network \
                        -p ${QDRANT_PORT}:6333 \
                        qdrant/qdrant
                    """

                    sh """
                    docker run -d \
                        --name n8n_${slug} \
                        --network fstm_network \
                        -p ${N8N_PORT}:5678 \
                        n8nio/n8n
                    """

                    sleep 15
                    echo "Qdrant : http://localhost:${QDRANT_PORT}"
                    echo "n8n    : http://localhost:${N8N_PORT}"
                }
            }
        }

        stage('4. Verification des Services') {
            parallel {

                stage('Qdrant') {
                    steps {
                        script {
                            def slug     = env.BRANCH_SLUG
                            def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                            def ok       = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)

                            // Restart auto si KO
                            if (!ok && hasDocker) {
                                echo "Qdrant KO, tentative de restart..."
                                sh "docker restart qdrant_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                            }

                            if (!ok) error "Qdrant ne repond pas sur ${QDRANT_URL}"
                            echo "Qdrant : OK"
                        }
                    }
                }

                stage('n8n') {
                    steps {
                        script {
                            def slug      = env.BRANCH_SLUG
                            def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                            def ok        = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)

                            // Restart auto si KO
                            if (!ok && hasDocker) {
                                echo "n8n KO, tentative de restart..."
                                sh "docker restart n8n_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                            }

                            if (!ok) error "n8n ne repond pas sur ${N8N_URL}"
                            echo "n8n : OK"
                        }
                    }
                }

                stage('Botpress') {
                    steps {
                        script {
                            def ok = false
                            for (int i = 1; i <= 3; i++) {
                                ok = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                                if (ok) break
                                echo "Botpress pas encore pret (${i}/3)..."
                                sleep 5
                            }
                            echo "Botpress : ${ok ? 'OK' : 'non disponible (non bloquant)'}"
                        }
                    }
                }
            }
        }

        stage('5. Installation Python') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install --upgrade pip --quiet
                "$PIP" install -r requirements.txt --quiet
                "$PIP" check && echo "Installation OK, pas de conflits."
                '''
            }
        }

        stage('6. Indexation des Documents') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh """
                    export MISTRAL_KEY=\$MISTRAL_KEY
                    export QDRANT_URL=${QDRANT_URL}
                    "\$PYTHON" load.py
                    """
                }
                sh """
                COLLECTIONS=\$(curl -sf "${QDRANT_URL}/collections" | python3 -c "
import sys, json
data = json.load(sys.stdin)
cols = data.get('result', {}).get('collections', [])
print(len(cols))
")
                [ "\$COLLECTIONS" -gt 0 ] && echo "\$COLLECTIONS collection(s) indexee(s)." || { echo "Aucune collection trouvee"; exit 1; }
                """
            }
        }

        stage('7. Pret') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    echo "Projet Wathiqa pret sur la branche ${env.BRANCH_SLUG}"
                    echo "--- Accès EXTERNE (Votre Navigateur) ---"
                    echo "Qdrant  : http://localhost:${env.QDRANT_PORT}"
                    echo "n8n     : http://localhost:${env.N8N_PORT}"
                    echo "--- Accès INTERNE (Jenkins/DNS) ---"
                    echo "Qdrant  : ${env.QDRANT_URL}"
                    echo "n8n     : ${env.N8N_URL}"
                    echo "Botpress: ${BOTPRESS_URL}"
                    echo "Conteneurs : qdrant_${slug} / n8n_${slug}"
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline reussi sur la branche ${env.BRANCH_SLUG}"
        }
        failure {
            script {
                def slug = env.BRANCH_SLUG
                echo "Pipeline en echec, suppression des conteneurs..."
                sh """
                docker stop qdrant_${slug} n8n_${slug} || true
                docker rm   qdrant_${slug} n8n_${slug} || true
                """
            }
        }
        aborted {
            echo "Pipeline annule."
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true,
                    patterns: [[pattern: 'venv/**', type: 'EXCLUDE']])
        }
    }
}

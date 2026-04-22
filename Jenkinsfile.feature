pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        // L'isolation est basée sur le numéro de build pour éviter les conflits de ports
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
    }

    stages {

        stage('1. Préparation de l\'Environnement') {
            steps {
                script {
                    // Calcul du slug de branche pour l'isolation des conteneurs
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_iso"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    // URLs internes pour les tests de santé
                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Pipeline de branche feature détecté sur le main. Arrêt par sécurité."
                    }
                    
                    checkout scm
                }
            }
        }

        stage('2. Déploiement des Services Isolés') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    echo "--- Déploiement des services pour : ${slug} ---"

                    // Nettoyage préventif
                    sh "docker stop qdrant_${slug} n8n_${slug} || true"
                    sh "docker rm   qdrant_${slug} n8n_${slug} || true"

                    // Création du réseau et lancement
                    sh "docker network create fstm_network || true"
                    sh "docker run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant"
                    sh "docker run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n"
                    
                    sleep 15
                }
            }
        }

        stage('3. Vérification de Santé') {
            parallel {
                stage('Qdrant Health') {
                    steps {
                        script {
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            if (!ok) error "Base Qdrant Isolé (${env.BRANCH_SLUG}) injoignable."
                        }
                    }
                }
                stage('n8n Health') {
                    steps {
                        script {
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            if (!ok) error "n8n Isolé (${env.BRANCH_SLUG}) injoignable."
                        }
                    }
                }
            }
        }

        stage('4. Indexation IA & RAG') {
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install -r requirements.txt --quiet
                '''
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh """
                    export MISTRAL_KEY=\$MISTRAL_KEY
                    export QDRANT_URL=${env.QDRANT_URL}
                    "\$PYTHON" load.py
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Isolation réussie pour la branche ${env.BRANCH_SLUG}."
        }
        failure {
            script {
                echo "Nettoyage après échec de la branche ${env.BRANCH_SLUG}..."
                sh "docker stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "docker rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

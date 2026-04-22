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
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
    }

    stages {

        stage('1. Initialisation (Isolée)') {
            steps {
                script {
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_default"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Pipeline réservé aux branches feature/. Utilisez le Jenkinsfile standard pour la prod."
                    }
                    
                    checkout scm
                    echo "--- Environnement Isolé Actif : ${env.BRANCH_SLUG} ---"
                }
            }
        }

        stage('2. Contrôles Qualité') {
            parallel {
                stage('Structure') {
                    steps {
                        sh 'find . -maxdepth 2 -not -path "*/.*"'
                    }
                }
                stage('Syntaxe Code') {
                    steps {
                        sh '''
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open(\'{}\'))" \\; -print
                        '''
                    }
                }
            }
        }

        stage('3. Déploiement Services') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    // Utilisation du socket standard (transparence totale via socat)
                    sh "docker network create fstm_network || true"
                    sh "docker run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant"
                    sh "docker run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n"
                    
                    echo "Services (Qdrant/n8n) déployés pour la branche ${slug}."
                    sleep 15
                }
            }
        }

        stage('4. Tests de Connexion') {
            parallel {
                stage('Qdrant Health') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "docker restart qdrant_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "Qdrant Isolé HS"
                        }
                    }
                }
                stage('n8n Health') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "docker restart n8n_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "n8n Isolé HS"
                        }
                    }
                }
            }
        }

        stage('5. Indexation IA & RAG') {
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
        success { echo "Félicitations ! Pipeline réussi et branche ${env.BRANCH_SLUG} isolée." }
        failure {
            script {
                echo "Échec détecté — Nettoyage forcé des services ${env.BRANCH_SLUG}..."
                sh "docker stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "docker rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

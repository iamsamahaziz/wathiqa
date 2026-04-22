pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        // Commande Docker forcée par le réseau TCP pour Windows
        DOCKER_CMD   = "docker -H tcp://host.docker.internal:2375"
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
    }

    stages {

        stage('1. Démarrage') {
            steps {
                script {
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_default"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Ce pipeline est réservé aux branches feature/."
                    }
                    
                    checkout scm
                    echo "--- Pilotage Docker forcé via : ${env.DOCKER_CMD} ---"
                }
            }
        }

        stage('2. Vérification Globale') {
            parallel {
                stage('Structure') {
                    steps {
                        sh 'find . -maxdepth 2 -not -path "*/.*"'
                    }
                }
                stage('Audit Qualité') {
                    steps {
                        sh '''
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open(\'{}\'))" \\; -print
                        '''
                    }
                }
            }
        }

        stage('3. Lancement des Services') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    // On force l'utilisation du réseau et du pont TCP
                    sh "${DOCKER_CMD} network create fstm_network || true"
                    sh "${DOCKER_CMD} run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant"
                    sh "${DOCKER_CMD} run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n"
                    
                    echo "Services isolés lancés."
                    sleep 15
                }
            }
        }

        stage('4. Vérification des Services') {
            parallel {
                stage('Qdrant') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "${DOCKER_CMD} restart qdrant_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "Échec Qdrant"
                        }
                    }
                }
                stage('n8n') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "${DOCKER_CMD} restart n8n_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "Échec n8n"
                        }
                    }
                }
            }
        }

        stage('5. Installation') {
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install -r requirements.txt --quiet
                '''
            }
        }

        stage('6. Indexation IA') {
            steps {
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
        failure {
            script {
                sh "${DOCKER_CMD} stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "${DOCKER_CMD} rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

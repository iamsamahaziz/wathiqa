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

        stage('1. Détection Réseau ( host.docker.internal )') {
            steps {
                script {
                    echo "=== Tentative de connexion via l'adresse standard Docker Windows ==="
                    
                    // On privilégie l'adresse universelle de Docker Desktop
                    def host = "host.docker.internal"
                    
                    // Test de résolution
                    def canResolve = (sh(script: "getent hosts ${host}", returnStatus: true) == 0)
                    
                    if (!canResolve) {
                        echo "ALERTE : host.docker.internal non résolu. Tentative de détection IP..."
                        host = sh(script: "ip route show | grep default | awk '{print \$3}'", returnStdout: true).trim()
                        if (!host) host = "172.17.0.1"
                    }

                    env.DOCKER_CMD = "docker -H tcp://${host}:2375"
                    echo "--- Pilotage Docker via : ${host} ---"
                    
                    // Test de connexion réel
                    sh "${env.DOCKER_CMD} version || echo 'ERREUR : Portail 2375 refusé. Assurez-vous que Docker Desktop expose bien le démon !'"

                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_default"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Pipeline réservé aux branches feature/."
                    }
                    
                    checkout scm
                }
            }
        }

        stage('2. Vérification du Projet') {
            parallel {
                stage('Validation Fichiers') {
                    steps {
                        sh 'find . -maxdepth 2 -not -path "*/.*"'
                    }
                }
                stage('Syntaxe Python/JSON') {
                    steps {
                        sh '''
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open(\'{}\'))" \\; -print
                        '''
                    }
                }
            }
        }

        stage('3. Lancement des Services Isolés') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    sh "${env.DOCKER_CMD} network create fstm_network || true"
                    sh "${env.DOCKER_CMD} run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant"
                    sh "${env.DOCKER_CMD} run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n"
                    
                    echo "Services isolés lancés."
                    sleep 15
                }
            }
        }

        stage('4. Vérification de Santé') {
            parallel {
                stage('Qdrant') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "${env.DOCKER_CMD} restart qdrant_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "Qdrant Isolé HS"
                        }
                    }
                }
                stage('n8n') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            if (!ok) {
                                sh "${env.DOCKER_CMD} restart n8n_${slug} || true"
                                sleep 10
                                ok = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                            }
                            if (!ok) error "n8n Isolé HS"
                        }
                    }
                }
            }
        }

        stage('5. Installation & Indexation IA') {
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
        failure {
            script {
                sh "${env.DOCKER_CMD} stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "${env.DOCKER_CMD} rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

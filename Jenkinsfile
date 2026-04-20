pipeline {
    agent any

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
    }

    environment {
        QDRANT_URL   = 'http://172.17.0.1:6333'
        N8N_URL      = 'http://172.17.0.1:5678'
        BOTPRESS_URL = 'https://botpress.com'
    }

    stages {
        stage('1. Récupération du Code') {
            steps {
                echo '🌐 Téléchargement de la dernière version du projet...'
                checkout scm
            }
        }

        stage('2. Vérifications & Self-Healing') {
            options { timeout(time: 3, unit: 'MINUTES') }
            steps {
                script {
                    echo "🔍 Vérification de la disponibilité de Docker..."
                    def dockerCheck = sh(script: 'docker ps > /dev/null 2>&1', returnStatus: true)

                    if (dockerCheck != 0) {
                        echo "⚠️ Docker n'est pas accessible. On continue sans self-healing."
                    }

                    echo "💓 Test de connexion : Qdrant..."
                    def qdrantCheck = sh(script: "curl --connect-timeout 5 --max-time 10 -sf ${env.QDRANT_URL}/ > /dev/null 2>&1", returnStatus: true)
                    if (qdrantCheck == 0) {
                        echo '✅ Qdrant est en ligne.'
                    } else {
                        echo '⚠️ Qdrant ne répond pas.'
                        if (dockerCheck == 0) {
                            echo 'Tentative de redémarrage...'
                            sh(script: 'timeout 15 docker restart desktop-qdrant-1 || true', returnStatus: true)
                            sleep 5
                        }
                    }

                    echo "💓 Test de connexion : n8n..."
                    def n8nCheck = sh(script: "curl --connect-timeout 5 --max-time 10 -sf ${env.N8N_URL}/ > /dev/null 2>&1", returnStatus: true)
                    if (n8nCheck == 0) {
                        echo '✅ n8n est en ligne.'
                    } else {
                        echo '⚠️ n8n ne répond pas.'
                        if (dockerCheck == 0) {
                            echo 'Tentative de redémarrage...'
                            sh(script: 'timeout 15 docker restart desktop-n8n-1 || true', returnStatus: true)
                            sleep 5
                        }
                    }
                }
            }
        }

        stage('3. Build & Install') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                echo '📦 Préparation de l\'environnement Python...'
                sh '''
                python3 -m venv venv || python -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        stage('4. Pipeline IA (Exécution)') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                echo '🚀 Lancement du traitement des documents Wathiqa...'
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh '''
                    export MISTRAL_KEY=$MISTRAL_KEY
                    export QDRANT_URL=$QDRANT_URL
                    ./venv/bin/python load.py || venv/Scripts/python load.py
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '🎉 WATHIQA PIPELINE TERMINÉ AVEC SUCCÈS !'
        }
        failure {
            echo '❌ ÉCHEC DU PIPELINE.'
        }
        aborted {
            echo '⏹️ PIPELINE ANNULÉ (timeout ou interruption manuelle).'
        }
    }
}

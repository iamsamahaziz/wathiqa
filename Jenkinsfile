pipeline {
    agent any

    stages {

        stage('1. Start Qdrant') {
            steps {
                echo '🚀 Lancement de Qdrant...'
                sh '''
                docker rm -f qdrant || true
                docker run -d --name qdrant -p 6333:6333 qdrant/qdrant
                sleep 5
                '''
            }
        }

        stage('2. Préparation') {
            steps {
                echo '📦 Récupération du code et installation...'
                sh '''
                python3 -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        stage('3. Pipeline IA') {
            steps {
                echo '🚀 Lancement script IA...'
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh './venv/bin/python load.py'
                }
            }
        }
    }

    post {
        always {
            echo '🧹 Nettoyage...'
            sh 'docker rm -f qdrant || true'
        }

        success {
            echo '🎉 Build réussi !'
        }

        failure {
            echo '❌ Build échoué'
        }
    }
}
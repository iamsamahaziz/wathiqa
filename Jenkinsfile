pipeline {
    agent any

    environment {
        // 🔐 clé Mistral depuis Jenkins Credentials
        MISTRAL_KEY = credentials('mistral-key')
    }

    stages {

        stage('1. Préparation') {
            steps {
                echo '📦 Récupération du code et installation de l-environnement...'

                sh 'python3 -m venv venv'
                sh './venv/bin/pip install --upgrade pip'
                sh './venv/bin/pip install -r requirements.txt'
            }
        }

        stage('2. Vérification') {
            steps {
                echo '🔍 Vérification des fichiers...'
                sh 'ls -la'
            }
        }

        stage('3. Entraînement / Pipeline IA') {
            steps {
                echo '🚀 Lancement du script IA...'

                // 🔐 on passe la clé au script
                sh '''
                export MISTRAL_KEY=$MISTRAL_KEY
                ./venv/bin/python load.py
                '''
            }
        }
    }

    post {
        success {
            echo '🎉 Bravo Samah ! Le build est réussi.'
        }

        failure {
            echo '❌ Build échoué - vérifier logs Jenkins'
        }

        always {
            echo '🏁 Fin du pipeline'
        }
    }
}

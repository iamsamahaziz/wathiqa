pipeline {
    agent any
    
    environment {
        QDRANT_URL = 'http://172.17.0.1:6333'
    }

    stages {

        stage('1. Préparation') {
            steps {
                echo '📦 Setup environment'
                sh '''
                python3 -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        stage('2. Pipeline IA') {
            steps {
                echo '🚀 Run IA script'

                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh '''
                    export MISTRAL_KEY=$MISTRAL_KEY
                    ./venv/bin/python load.py
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '🎉 Build réussi !'
        }

        failure {
            echo '❌ Build échoué'
        }
    }
}
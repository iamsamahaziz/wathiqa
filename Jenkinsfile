pipeline {
    agent any

    stages {
        stage('1. Préparation') {
            steps {
                echo 'Récupération du code et installation de l-environnement...'
                sh 'python3 -m venv venv'
                // Utilise ton fichier requirements.txt
                sh './venv/bin/pip install -r requirements.txt' 
            }
        }
        stage('2. Entraînement / Test IA') {
            steps {
                echo 'Lancement du script IA...'
                // Remplace main.py par le nom de ton script principal
                sh './venv/bin/python load.py' 
            }
        }
    }
    
    post {
        success {
            echo 'Bravo Samah ! Le build est réussi.'
        }
    }
}

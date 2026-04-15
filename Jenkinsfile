pipeline {
    agent any

    environment {
        // IPs cibles pour les tests de santé (Health Checks)
        QDRANT_URL = 'http://172.17.0.1:6333'
        N8N_URL     = 'http://172.17.0.1:5678'
    }

    stages {
        // --- ÉTAPE 1 : RÉCUPÉRATION ---
        stage('1. Récupération du Code (GitHub)') {
            steps {
                echo '🌐 Téléchargement de la dernière version du projet...'
                checkout scm
            }
        }

        // --- ÉTAPE 2 : QUALITÉ ---
        stage('2. Qualité du Code (Syntax Check)') {
            steps {
                echo '🔍 Vérification de la syntaxe Python...'
                sh '''
                python3 -m py_compile load.py || (echo "❌ ALERTE : Erreur de syntaxe détectée !" && exit 1)
                '''
                echo '✅ Syntaxe validée.'
            }
        }

        // --- ÉTAPE 3 : INFRASTRUCTURE ---
        stage('3. Tests de Santé (Health Checks)') {
            steps {
                echo '💓 Vérification de la disponibilité des serveurs...'
                script {
                    // Vérification Qdrant
                    sh "curl -f ${env.QDRANT_URL}/health || (echo '❌ ÉCHEC : Qdrant est hors-ligne !' && exit 1)"
                    
                    // Vérification n8n
                    sh "curl -f ${env.N8N_URL}/healthz || (echo '❌ ÉCHEC : n8n est inaccessible !' && exit 1)"
                    
                    // Vérification Botpress Cloud
                    sh "curl -s -Is https://api.botpress.cloud | grep -E 'HTTP/1.1 200|HTTP/2 200' || (echo '❌ ÉCHEC : Botpress Cloud est down !' && exit 1)"
                }
                echo '✅ Tous les services sont opérationnels.'
            }
        }

        // --- ÉTAPE 4 : INSTALLATION ---
        stage('4. Build & Install (Dépendances)') {
            steps {
                echo '📦 Préparation de l\'environnement virtuel et installation...'
                sh '''
                python3 -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        // --- ÉTAPE 5 : EXÉCUTION ---
        stage('5. Pipeline IA (Exécution)') {
            steps {
                echo '🚀 Lancement du traitement des documents Wathiqa...'
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
            echo '🎉 WATHIQA PIPELINE TERMINE AVEC SUCCES !'
        }
        failure {
            echo '❌ ÉCHEC DU PIPELINE : Veuillez consulter les logs pour identifier l\'étape en erreur.'
        }
    }
}

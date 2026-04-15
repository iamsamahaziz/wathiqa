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
                    // Test 1 : Qdrant (On teste la racine / qui répond toujours 200)
                    echo "Test de connexion : Qdrant..."
                    sh "curl -f ${env.QDRANT_URL}/ || (echo '❌ ALERTE JENKINS : Qdrant ne répond pas !' && exit 1)"
                    
                    // Test 2 : n8n (On teste la racine / car healthz peut varier selon la version)
                    echo "Test de connexion : n8n..."
                    sh "curl -f ${env.N8N_URL}/ || (echo '❌ ALERTE JENKINS : n8n est inaccessible !' && exit 1)"
                    
                    // Test 3 : Botpress Cloud (On accepte 200 ou les redirections 301/302)
                    echo "Checking Botpress Cloud..."
                    sh "curl -s -I https://api.botpress.cloud | grep -E 'HTTP/.* (200|301|302)' || (echo '❌ ALERTE JENKINS : Botpress Cloud inaccessible !' && exit 1)"
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

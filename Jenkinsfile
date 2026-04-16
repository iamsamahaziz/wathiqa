pipeline {
    agent any

    options {
        timeout(time: 15, unit: 'MINUTES') // Évite que le pipeline ne tourne indéfiniment
        retry(1)
        timestamps()
    }

    environment {
        // IPs du pont réseau Docker pour permettre à Jenkins (Conteneur) de voir le réseau hôte
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
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                script {
                    echo "🔍 Vérification de la disponibilité de Docker..."
                    // On vérifie si Docker est accessible avant toute commande complexe
                    def dockerCheck = sh(script: 'docker ps > /dev/null 2>&1', returnStatus: true)
                    
                    if (dockerCheck != 0) {
                        echo "⚠️ Docker n'est pas accessible ! Le pipeline risque de bloquer."
                        // On continue quand même pour les tests réseau, mais on ne tentera pas de 'docker restart'
                    }

                    echo "💓 Test de connexion : Qdrant..."
                    try {
                        sh "curl --connect-timeout 5 -f ${env.QDRANT_URL}/"
                        echo '✅ Qdrant est en ligne.'
                    } catch (Exception e) {
                        echo '⚠️ QDRANT EN PANNE !'
                        if (dockerCheck == 0) {
                            echo 'Tentative de redémarrage de Qdrant...'
                            sh 'docker restart desktop-qdrant-1 || true'
                        } else {
                            echo 'Impossible de redémarrer (Docker inaccessible).'
                        }
                    }

                    echo "💓 Test de connexion : n8n..."
                    try {
                        sh "curl --connect-timeout 5 -f ${env.N8N_URL}/"
                        echo '✅ n8n est en ligne.'
                    } catch (Exception e) {
                        echo '⚠️ N8N EN PANNE !'
                        if (dockerCheck == 0) {
                            echo 'Tentative de redémarrage de n8n...'
                            sh 'docker restart desktop-n8n-1 || true'
                        } else {
                            echo 'Impossible de redémarrer (Docker inaccessible).'
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
                    ./venv/bin/python load.py || venv/Scripts/python load.py
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
            echo '❌ ÉCHEC DU PIPELINE : Le pipeline a été arrêté (Timeout ou Erreur).'
        }
    }
}

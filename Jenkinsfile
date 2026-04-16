pipeline {
    agent any

    environment {
        // Paramètres réseau abstraits (Clean Code)
        QDRANT_URL   = 'http://localhost:6333'
        N8N_URL      = 'http://localhost:5678'
        BOTPRESS_URL = 'https://botpress.com'
    }

    stages {
        stage('1. Récupération du Code (GitHub)') {
            steps {
                echo '🌐 Téléchargement de la dernière version du projet...'
                checkout scm
            }
        }

        stage('2. Vérifications Préalables (Parallel)') {
            parallel {
                stage('Syntax Check (Python)') {
                    steps {
                        echo '🔍 Vérification de la syntaxe Python...'
                        sh 'python3 -m py_compile load.py || exit 1'
                        echo '✅ Syntaxe validée.'
                    }
                }
                
                stage('Health Checks & Self-Healing') {
                    steps {
                        echo '💓 Vérification des serveurs...'
                        script {
                            echo "Test de connexion : Qdrant (Self-Healing activé)..."
                            try {
                                sh "curl -f ${env.QDRANT_URL}/"
                                echo '✅ Qdrant répond parfaitement !'
                            } catch (Exception e) {
                                echo '⚠️ QDRANT EN PANNE ! Tentative d\'auto-réparation en cours...'
                                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                    sh 'docker restart desktop-qdrant-1'
                                }
                                sleep time: 10, unit: 'SECONDS'
                                sh "curl -f ${env.QDRANT_URL}/ || exit 1"
                            }

                            echo "Test de connexion : n8n (Self-Healing activé)..."
                            try {
                                sh "curl -f ${env.N8N_URL}/"
                                echo '✅ n8n répond parfaitement !'
                            } catch (Exception e) {
                                echo '⚠️ N8N EN PANNE ! Tentative d\'auto-réparation en cours...'
                                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                    sh 'docker restart desktop-n8n-1'
                                }
                                sleep time: 10, unit: 'SECONDS'
                                sh "curl -f ${env.N8N_URL}/ || exit 1"
                            }

                            echo "Checking Botpress Cloud (Avec Mécanisme Retry)..."
                            retry(3) {
                                sleep time: 5, unit: 'SECONDS'
                                sh "curl -s -I ${env.BOTPRESS_URL} | grep -E 'HTTP/.* (200|301|302)' || exit 1"
                            }
                        }
                    }
                }
            }
        }

        stage('3. Build & Install (Dépendances)') {
            steps {
                echo '📦 Préparation de l\'environnement avec système de Cache...'
                sh '''
                if [ ! -d "venv" ]; then
                    echo "📁 Création du VENV (Premier lancement)..."
                    python3 -m venv venv
                else
                    echo "⚡ VENV trouvé, utilisation du Cache (Gain de temps)..."
                fi
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        stage('4. Pipeline IA (Exécution)') {
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
        always {
            cleanWs()
        }
        success {
            echo '🎉 WATHIQA PIPELINE TERMINE AVEC SUCCES !'
        }
        failure {
            echo '❌ ÉCHEC DU PIPELINE : Veuillez consulter les logs pour identifier l\'étape en erreur.'
        }
    }
}

pipeline {
    agent any

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        QDRANT_URL   = 'http://172.17.0.1:6333'
        N8N_URL      = 'http://172.17.0.1:5678'
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
    }

    stages {

        // 1. Télécharge le code depuis GitHub
        stage('1. Récupération du Code') {
            steps {
                checkout scm
                echo "Commit : ${env.GIT_COMMIT?.take(8)} — Branche : ${env.GIT_BRANCH}"
            }
        }

        // 2. Vérifications en parallèle — les 3 checks tournent en même temps
        stage('2. Vérification') {
            parallel {

                stage('Fichiers') {
                    steps {
                        sh '''
                        MISSING=0
                        for FILE in load.py requirements.txt Wathiqa.json Wathiqa.bpz documents; do
                            if [ -e "$FILE" ]; then
                                echo "OK : $FILE"
                            else
                                echo "MANQUANT : $FILE"
                                MISSING=1
                            fi
                        done
                        [ "$MISSING" -eq 1 ] && exit 1 || echo "Tous les fichiers sont présents."
                        '''
                    }
                }

                stage('Syntaxe Python') {
                    steps {
                        sh 'python3 -m py_compile load.py && echo "Syntaxe Python OK"'
                    }
                }

                stage('Requirements') {
                    steps {
                        sh 'python3 -c "lines=open(\"requirements.txt\").readlines(); exit(0 if lines else 1)" && echo "requirements.txt OK"'
                    }
                }
            }
        }

        // 3. Vérification des services en parallèle — les 4 checks tournent en même temps
        //    Qdrant et n8n ont un redémarrage automatique si hors ligne
        stage('3. Vérification des Services') {
            options { timeout(time: 5, unit: 'MINUTES') }
            parallel {

                stage('Docker') {
                    steps {
                        script {
                            if (sh(script: 'docker ps', returnStatus: true) != 0)
                                error "Docker inaccessible — arrêt du pipeline."
                            echo "Docker OK"
                        }
                    }
                }

                stage('Qdrant') {
                    steps {
                        script {
                            if (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) != 0) {
                                sh 'docker restart desktop-qdrant-1 || true'
                                sleep 10
                                if (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) != 0)
                                    error "Qdrant hors ligne — arrêt du pipeline."
                            }
                            echo "Qdrant OK"
                        }
                    }
                }

                stage('n8n') {
                    steps {
                        script {
                            if (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) != 0) {
                                sh 'docker restart desktop-n8n-1 || true'
                                sleep 10
                                if (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) != 0)
                                    error "n8n hors ligne — arrêt du pipeline."
                            }
                            echo "n8n OK"
                        }
                    }
                }

                stage('Botpress') {
                    steps {
                        script {
                            if (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) != 0)
                                error "Botpress inaccessible — arrêt du pipeline."
                            echo "Botpress OK"
                        }
                    }
                }
            }
        }

        // 4. Crée l'environnement Python et installe les dépendances
        stage('4. Installation') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                sh '''
                [ ! -f "$PYTHON" ] && python3 -m venv venv

                "$PIP" install --upgrade pip --quiet
                "$PIP" install -r requirements.txt --quiet
                "$PIP" check && echo "Aucun conflit de dépendances."
                '''
            }
        }

        // 5. Lance l'indexation des documents dans Qdrant
        stage('5. Indexation IA') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh '''
                    export MISTRAL_KEY=$MISTRAL_KEY
                    export QDRANT_URL=$QDRANT_URL
                    "$PYTHON" load.py
                    '''
                }

                // Vérifie que l'indexation a bien créé des collections dans Qdrant
                sh '''
                COLLECTIONS=$(curl -sf "${QDRANT_URL}/collections" | python3 -c "
import sys, json
data = json.load(sys.stdin)
cols = data.get('result', {}).get('collections', [])
print(len(cols))
")
                [ "$COLLECTIONS" -gt 0 ] && echo "$COLLECTIONS collection(s) indexée(s)." || { echo "Aucune collection trouvée."; exit 1; }
                '''
            }
        }
    }

    post {
        success { echo "Pipeline terminé avec succès — commit ${env.GIT_COMMIT?.take(8)}" }
        failure { echo "Pipeline en échec — consultez les logs." }
        aborted { echo "Pipeline annulé." }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true,
                    patterns: [[pattern: 'venv/**', type: 'EXCLUDE']])
        }
    }
}

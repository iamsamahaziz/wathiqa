pipeline {
    agent any

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
    }

    environment {
        QDRANT_URL   = 'http://172.17.0.1:6333'
        N8N_URL      = 'http://172.17.0.1:5678'
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
    }

    stages {

        stage('1. Récupération du Code') {
            steps {
                echo '🌐 Téléchargement du projet depuis GitHub...'
                checkout scm
            }
        }

        stage('2. Vérification de Syntaxe') {
            steps {
                echo '🔍 Vérification des fichiers du projet...'
                sh '''
                echo "📄 Fichiers requis :"

                test -f load.py          && echo "✅ load.py trouvé"          || echo "❌ load.py MANQUANT"
                test -f requirements.txt && echo "✅ requirements.txt trouvé" || echo "❌ requirements.txt MANQUANT"
                test -f Wathiqa.json     && echo "✅ Wathiqa.json trouvé"     || echo "❌ Wathiqa.json MANQUANT"
                test -f Wathiqa.bpz      && echo "✅ Wathiqa.bpz trouvé"      || echo "❌ Wathiqa.bpz MANQUANT"
                test -d documents        && echo "✅ documents/ trouvé"        || echo "❌ documents/ MANQUANT"
                '''

                echo '🐍 Vérification de la syntaxe Python...'
                sh 'python3 -c "import py_compile; py_compile.compile(\"load.py\", doraise=True)" || python -c "import py_compile; py_compile.compile(\"load.py\", doraise=True)"'

                echo '✅ Syntaxe OK — Aucune erreur détectée.'
            }
        }

        stage('3. Self-Healing & Validation') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                script {
                    // 3.1 — Docker
                    echo '🐳 Vérification de Docker...'
                    def dockerOK = (sh(script: 'docker ps', returnStatus: true) == 0)
                    if (!dockerOK) {
                        error "❌ Docker est inaccessible ! Impossible de gérer les conteneurs. Arrêt du pipeline."
                    }
                    echo '✅ Docker OK'

                    // 3.2 — Qdrant
                    echo '🧠 Vérification de Qdrant...'
                    def qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    if (!qdrantOK) {
                        echo '⚠️ Qdrant KO. Tentative de réparation...'
                        sh 'timeout 20 docker restart desktop-qdrant-1 || true'
                        sleep 10
                        // Re-vérification après réparation
                        qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    }

                    if (!qdrantOK) {
                        error "❌ Qdrant est toujours HORS LIGNE après tentative de redémarrage. Arrêt du pipeline."
                    }
                    echo '✅ Qdrant OK'

                    // 3.3 — n8n
                    echo '⚙️ Vérification de n8n...'
                    def n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    if (!n8nOK) {
                        echo '⚠️ n8n KO. Tentative de réparation...'
                        sh 'timeout 20 docker restart desktop-n8n-1 || true'
                        sleep 10
                        // Re-vérification après réparation
                        n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    }

                    if (!n8nOK) {
                        error "❌ n8n est toujours HORS LIGNE après tentative de redémarrage. Arrêt du pipeline."
                    }
                    echo '✅ n8n OK'

                    // 3.4 — Botpress Cloud (Service externe)
                    echo '💬 Vérification de Botpress...'
                    def botpressOK = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                    if (!botpressOK) {
                        error "❌ Botpress Cloud est injoignable. Le chatbot ne pourra pas communiquer. Arrêt du pipeline."
                    }
                    echo '✅ Botpress OK'

                    // Résumé final
                    echo '══════════════════════════════════'
                    echo '📊 RÉSUMÉ SANTÉ :'
                    echo "   Docker   : ✅"
                    echo "   Qdrant   : ✅"
                    echo "   n8n      : ✅"
                    echo "   Botpress : ✅"
                    echo '══════════════════════════════════'
                }
            }
        }

        stage('4. Build & Install') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                echo '📦 Installation de Python...'
                sh '''
                python3 -m venv venv || python -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        stage('5. Pipeline IA') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                echo '🚀 Indexation des 57 documents...'
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
        success { echo '🎉 PIPELINE TERMINÉ AVEC SUCCÈS !' }
        failure { echo '❌ ÉCHEC DU PIPELINE.' }
        aborted { echo '⏹️ PIPELINE ANNULÉ.' }
    }
}

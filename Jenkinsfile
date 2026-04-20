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

        stage('3. Self-Healing') {
            options { timeout(time: 3, unit: 'MINUTES') }
            steps {
                script {

                    // 2.1 — Docker
                    echo '🐳 Vérification de Docker...'
                    def dockerOK = (sh(script: 'docker ps', returnStatus: true) == 0)
                    echo dockerOK ? '✅ Docker OK' : '⚠️ Docker inaccessible'

                    // 2.2 — Qdrant
                    echo '🧠 Vérification de Qdrant...'
                    def qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    echo qdrantOK ? '✅ Qdrant OK' : '❌ Qdrant KO'
                    if (!qdrantOK && dockerOK) {
                        echo '🔄 Redémarrage de Qdrant...'
                        sh 'timeout 15 docker restart desktop-qdrant-1 || true'
                        sleep 5
                    }

                    // 2.3 — n8n
                    echo '⚙️ Vérification de n8n...'
                    def n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    echo n8nOK ? '✅ n8n OK' : '❌ n8n KO'
                    if (!n8nOK && dockerOK) {
                        echo '🔄 Redémarrage de n8n...'
                        sh 'timeout 15 docker restart desktop-n8n-1 || true'
                        sleep 5
                    }

                    // 2.4 — Botpress Cloud
                    echo '💬 Vérification de Botpress...'
                    def botpressOK = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                    echo botpressOK ? '✅ Botpress OK' : '⚠️ Botpress injoignable'

                    // Résumé
                    echo '══════════════════════════════════'
                    echo '📊 RÉSUMÉ :'
                    echo "   Docker   : ${dockerOK   ? '✅' : '❌'}"
                    echo "   Qdrant   : ${qdrantOK   ? '✅' : '❌'}"
                    echo "   n8n      : ${n8nOK      ? '✅' : '❌'}"
                    echo "   Botpress : ${botpressOK ? '✅' : '❌'}"
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

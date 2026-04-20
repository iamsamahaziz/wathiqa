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
        VENV_DIR     = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
    }

    stages {

        // ─────────────────────────────────────────────
        // STAGE 1 — Récupération du code
        // ─────────────────────────────────────────────
        stage('1. Récupération du Code') {
            steps {
                echo '🌐 Téléchargement du projet depuis GitHub...'
                checkout scm
                echo "📌 Commit : ${env.GIT_COMMIT?.take(8) ?: 'inconnu'} — Branche : ${env.GIT_BRANCH ?: 'inconnue'}"
            }
        }

        // ─────────────────────────────────────────────
        // STAGE 2 — Vérification des fichiers + syntaxe
        // ─────────────────────────────────────────────
        stage('2. Vérification de Syntaxe') {
            steps {
                echo '🔍 Vérification des fichiers requis...'
                sh '''
                MISSING=0

                check_file() {
                    if [ -e "$1" ]; then
                        echo "✅ $1 trouvé"
                    else
                        echo "❌ $1 MANQUANT"
                        MISSING=1
                    fi
                }

                check_file load.py
                check_file requirements.txt
                check_file Wathiqa.json
                check_file Wathiqa.bpz
                check_file documents

                if [ "$MISSING" -eq 1 ]; then
                    echo "❌ Fichiers critiques manquants — arrêt du pipeline."
                    exit 1
                fi

                echo "✅ Tous les fichiers requis sont présents."
                '''

                echo '🐍 Vérification de la syntaxe Python...'
                sh '''
                python3 -c "
import py_compile, sys
try:
    py_compile.compile('load.py', doraise=True)
    print('✅ load.py — syntaxe OK')
except py_compile.PyCompileError as e:
    print(f'❌ Erreur de syntaxe dans load.py : {e}')
    sys.exit(1)
"
                '''

                echo '📦 Vérification du requirements.txt...'
                sh '''
                python3 -c "
import sys
with open('requirements.txt') as f:
    lines = [l.strip() for l in f if l.strip() and not l.startswith('#')]
if not lines:
    print('❌ requirements.txt est vide !')
    sys.exit(1)
print(f'✅ requirements.txt OK — {len(lines)} dépendances déclarées')
"
                '''
            }
        }

        // ─────────────────────────────────────────────
        // STAGE 3 — Self-Healing & Validation infra
        // ─────────────────────────────────────────────
        stage('3. Self-Healing & Validation') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                script {

                    // Helper : vérifie un service, tente un restart si KO, échoue si toujours KO
                    def checkService = { String name, String checkCmd, String restartCmd, int waitSec ->
                        echo "🔍 Vérification de ${name}..."
                        def ok = (sh(script: checkCmd, returnStatus: true) == 0)
                        if (!ok && restartCmd) {
                            echo "⚠️ ${name} KO — tentative de redémarrage..."
                            sh "${restartCmd} || true"
                            sleep waitSec
                            ok = (sh(script: checkCmd, returnStatus: true) == 0)
                        }
                        if (!ok) {
                            error "❌ ${name} est HORS LIGNE après tentative de réparation. Arrêt du pipeline."
                        }
                        echo "✅ ${name} OK"
                    }

                    // 3.1 — Docker (pas de restart possible, échec immédiat)
                    checkService(
                        'Docker',
                        'docker ps',
                        null,
                        0
                    )

                    // 3.2 — Qdrant
                    checkService(
                        'Qdrant',
                        "curl -sf --max-time 10 ${QDRANT_URL}",
                        'timeout 20 docker restart desktop-qdrant-1',
                        10
                    )

                    // 3.3 — n8n
                    checkService(
                        'n8n',
                        "curl -sf --max-time 10 ${N8N_URL}",
                        'timeout 20 docker restart desktop-n8n-1',
                        10
                    )

                    // 3.4 — Botpress Cloud (service externe, pas de restart)
                    checkService(
                        'Botpress',
                        "curl -sf --max-time 10 ${BOTPRESS_URL}",
                        null,
                        0
                    )

                    echo '══════════════════════════════════'
                    echo '📊 RÉSUMÉ SANTÉ : Docker ✅ | Qdrant ✅ | n8n ✅ | Botpress ✅'
                    echo '══════════════════════════════════'
                }
            }
        }

        // ─────────────────────────────────────────────
        // STAGE 4 — Build & Install (avec cache venv)
        // ─────────────────────────────────────────────
        stage('4. Build & Install') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                echo '📦 Création du venv et installation des dépendances...'
                sh '''
                # Crée le venv uniquement s'il n'existe pas déjà
                if [ ! -f "$VENV_DIR/bin/python" ]; then
                    echo "🆕 Création du venv..."
                    python3 -m venv "$VENV_DIR"
                else
                    echo "♻️  Venv existant réutilisé"
                fi

                "$PIP" install --upgrade pip --quiet
                "$PIP" install -r requirements.txt --quiet
                '''

                echo '🔎 Vérification des conflits de dépendances...'
                sh '"$PIP" check && echo "✅ Aucun conflit de dépendances" || { echo "❌ Conflits détectés"; exit 1; }'
            }
        }

        // ─────────────────────────────────────────────
        // STAGE 5 — Pipeline IA
        // ─────────────────────────────────────────────
        stage('5. Pipeline IA') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                echo '🚀 Indexation des documents dans Qdrant...'
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh '''
                    export MISTRAL_KEY=$MISTRAL_KEY
                    export QDRANT_URL=$QDRANT_URL
                    "$PYTHON" load.py
                    '''
                }

                echo '🔍 Vérification post-indexation dans Qdrant...'
                sh '''
                STATUS=$(curl -sf --max-time 10 "${QDRANT_URL}/collections" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    collections = data.get('result', {}).get('collections', [])
    if collections:
        print(f'✅ {len(collections)} collection(s) trouvée(s) dans Qdrant : {[c[\"name\"] for c in collections]}')
    else:
        print('❌ Aucune collection trouvée dans Qdrant après indexation')
        sys.exit(1)
except Exception as e:
    print(f'❌ Erreur lors de la vérification Qdrant : {e}')
    sys.exit(1)
" 2>&1)
                echo "$STATUS"
                echo "$STATUS" | grep -q "❌" && exit 1 || true
                '''
            }
        }
    }

    // ─────────────────────────────────────────────
    // POST — Notifications + nettoyage
    // ─────────────────────────────────────────────
    post {
        success {
            echo '🎉 PIPELINE TERMINÉ AVEC SUCCÈS !'
            echo "📌 Commit déployé : ${env.GIT_COMMIT?.take(8) ?: 'inconnu'}"
        }
        failure {
            echo '❌ ÉCHEC DU PIPELINE.'
            echo '💡 Consultez les logs ci-dessus pour identifier l\'étape en erreur.'
            // Décommenter pour activer les notifications email :
            // mail to: 'ton-email@example.com',
            //      subject: "❌ Pipeline échoué — ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //      body: "Voir les logs : ${env.BUILD_URL}"
        }
        aborted {
            echo '⏹️ PIPELINE ANNULÉ.'
        }
        cleanup {
            echo '🧹 Nettoyage du workspace...'
            cleanWs(
                deleteDirs: true,
                notFailBuild: true,
                patterns: [[pattern: 'venv/**', type: 'EXCLUDE']]  // conserve le venv pour le cache
            )
        }
    }
}

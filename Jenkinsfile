// ═══════════════════════════════════════════════════════════
// Fonctions utilitaires (pour rendre le code lisible)
// ═══════════════════════════════════════════════════════════

// Vérifie si un service répond (retourne true ou false)
def verifierService(String url) {
    return sh(
        script: "curl -sf --max-time 10 ${url}/ > /dev/null 2>&1",
        returnStatus: true
    ) == 0
}

// Tente de redémarrer un conteneur Docker
def redemarrerConteneur(String nomConteneur) {
    echo "🔄 Tentative de redémarrage de ${nomConteneur}..."
    sh(
        script: "timeout 15 docker restart ${nomConteneur} || true",
        returnStatus: true
    )
    sleep 5
}

// ═══════════════════════════════════════════════════════════
// Pipeline principal
// ═══════════════════════════════════════════════════════════
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

        // ─────────────────────────────────────────────────
        // STAGE 1 : Récupérer le code depuis GitHub
        // ─────────────────────────────────────────────────
        stage('1. Récupération du Code') {
            steps {
                echo '🌐 Téléchargement du projet depuis GitHub...'
                checkout scm
            }
        }

        // ─────────────────────────────────────────────────
        // STAGE 2 : Self-Healing (Vérification des services)
        // ─────────────────────────────────────────────────
        stage('2. Self-Healing') {
            options { timeout(time: 3, unit: 'MINUTES') }
            steps {
                script {

                    // 2.1 — Docker est-il accessible ?
                    echo '🐳 Vérification de Docker...'
                    def dockerOK = sh(
                        script: 'docker ps > /dev/null 2>&1',
                        returnStatus: true
                    ) == 0

                    if (dockerOK) {
                        echo '✅ Docker est accessible.'
                    } else {
                        echo '⚠️ Docker est inaccessible.'
                    }

                    // 2.2 — Qdrant est-il en ligne ?
                    echo '🧠 Vérification de Qdrant...'
                    def qdrantOK = verifierService(env.QDRANT_URL)

                    if (qdrantOK) {
                        echo '✅ Qdrant est en ligne.'
                    } else {
                        echo '❌ Qdrant ne répond pas !'
                        if (dockerOK) { redemarrerConteneur('desktop-qdrant-1') }
                    }

                    // 2.3 — n8n est-il en ligne ?
                    echo '⚙️ Vérification de n8n...'
                    def n8nOK = verifierService(env.N8N_URL)

                    if (n8nOK) {
                        echo '✅ n8n est en ligne.'
                    } else {
                        echo '❌ n8n ne répond pas !'
                        if (dockerOK) { redemarrerConteneur('desktop-n8n-1') }
                    }

                    // 2.4 — Botpress Cloud est-il joignable ?
                    echo '💬 Vérification de Botpress Cloud...'
                    def botpressOK = verifierService(env.BOTPRESS_URL)

                    if (botpressOK) {
                        echo '✅ Botpress Cloud est joignable.'
                    } else {
                        echo '⚠️ Botpress Cloud est injoignable.'
                    }

                    // Résumé final
                    echo '══════════════════════════════════'
                    echo '📊 RÉSUMÉ SELF-HEALING :'
                    echo "   Docker   : ${dockerOK   ? '✅ OK' : '❌ KO'}"
                    echo "   Qdrant   : ${qdrantOK   ? '✅ OK' : '❌ KO'}"
                    echo "   n8n      : ${n8nOK      ? '✅ OK' : '❌ KO'}"
                    echo "   Botpress : ${botpressOK ? '✅ OK' : '❌ KO'}"
                    echo '══════════════════════════════════'
                }
            }
        }

        // ─────────────────────────────────────────────────
        // STAGE 3 : Installer Python et les dépendances
        // ─────────────────────────────────────────────────
        stage('3. Build & Install') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                echo '📦 Création de l\'environnement Python...'
                sh '''
                python3 -m venv venv || python -m venv venv
                ./venv/bin/pip install --upgrade pip
                ./venv/bin/pip install -r requirements.txt
                '''
            }
        }

        // ─────────────────────────────────────────────────
        // STAGE 4 : Lancer le pipeline IA (indexation)
        // ─────────────────────────────────────────────────
        stage('4. Pipeline IA') {
            options { timeout(time: 10, unit: 'MINUTES') }
            steps {
                echo '🚀 Indexation des 57 documents dans Qdrant...'
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
        success {
            echo '🎉 WATHIQA PIPELINE TERMINÉ AVEC SUCCÈS !'
        }
        failure {
            echo '❌ ÉCHEC DU PIPELINE.'
        }
        aborted {
            echo '⏹️ PIPELINE ANNULÉ (timeout ou interruption manuelle).'
        }
    }
}

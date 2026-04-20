pipeline {
    agent any

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        QDRANT_URL   = 'http://qdrant:6333'
        N8N_URL      = 'http://n8n:5678'
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        PYTHON       = "python3"
        PIP          = "pip3"
    }

    stages {

        // 1. Télécharge le code depuis GitHub
        stage('1. Récupération du Code') {
            steps {
                checkout scm
                echo "Commit : ${env.GIT_COMMIT?.take(8)} — Projet Wathiqa"
            }
        }

        // 2. Vérification
        stage('2. Vérification') {
            parallel {
                stage('Fichiers') {
                    steps {
                        sh '''
                        MISSING=0
                        for FILE in load.py requirements.txt Wathiqa.json Wathiqa.bpz documents; do
                            if [ -e "$FILE" ]; then echo "OK : $FILE"; else echo "MANQUANT : $FILE"; MISSING=1; fi
                        done
                        [ "$MISSING" -eq 1 ] && exit 1 || echo "Fichiers OK."
                        '''
                    }
                }
                stage('Syntaxe Python') {
                    steps {
                        sh 'python3 -m py_compile load.py'
                    }
                }
            }
        }

        // 3. Vérification des Services
        stage('3. Vérification des Services') {
            steps {
                script {
                    // --- Docker Detection ---
                    def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                    if (!hasDocker) {
                        echo "AVERTISSEMENT : Docker introuvable. Auto-réparation désactivée."
                    }

                    // --- Qdrant ---
                    def qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    if (!qdrantOK) {
                        if (hasDocker) {
                            echo "Qdrant KO — tentative de redémarrage..."
                            sh 'docker restart fstm_qdrant || true'
                            sleep 10
                            qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                        }
                        if (!qdrantOK) error "Qdrant injoignable sur ${QDRANT_URL}"
                    }

                    // --- n8n ---
                    def n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    if (!n8nOK) {
                        if (hasDocker) {
                            echo "n8n KO — tentative de redémarrage..."
                            sh 'docker restart fstm_n8n || true'
                            sleep 10
                            n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                        }
                        if (!n8nOK) error "n8n injoignable sur ${N8N_URL}"
                    }
                }
            }
        }

                    // --- Botpress : 3 tentatives espacées de 5s ---
                    def botpressOK = false
                    for (int i = 1; i <= 3; i++) {
                        botpressOK = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                        if (botpressOK) break
                        echo "Botpress KO (tentative ${i}/3) — nouvel essai dans 5s..."
                        sleep 5
                    }
                    if (botpressOK)
                        echo "Botpress OK"
                    else
                        echo "AVERTISSEMENT : Botpress toujours inaccessible après 3 tentatives (non bloquant)."

                    // --- Résumé ---
                    echo "══════════════════════════════════"
                    echo "Docker   : ${dockerOK   ? 'OK' : 'AVERTISSEMENT'}"
                    echo "Qdrant   : ${qdrantOK   ? 'OK' : 'ECHEC'}"
                    echo "n8n      : ${n8nOK      ? 'OK' : 'ECHEC'}"
                    echo "Botpress : ${botpressOK ? 'OK' : 'AVERTISSEMENT'}"
                    echo "══════════════════════════════════"
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
                [ "$COLLECTIONS" -gt 0 ] && echo "$COLLECTIONS collection(s) indexee(s)." || { echo "Aucune collection trouvee."; exit 1; }
                '''
            }
        }
    }

    post {
        success { echo "Pipeline termine avec succes — commit ${env.GIT_COMMIT?.take(8)}" }
        failure { echo "Pipeline en echec — consultez les logs." }
        aborted { echo "Pipeline annule." }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true,
                    patterns: [[pattern: 'venv/**', type: 'EXCLUDE']])
        }
    }
}

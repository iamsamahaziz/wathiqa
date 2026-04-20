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
                        sh '''
                        python3 << 'PYEOF'
import sys
with open('requirements.txt') as f:
    lines = [l for l in f if l.strip() and not l.startswith('#')]
if not lines:
    print("requirements.txt est vide !")
    sys.exit(1)
print(f"requirements.txt OK — {len(lines)} dependances")
PYEOF
                        '''
                    }
                }
            }
        }

        // 3. Vérification des services en parallèle
        //
        //  Docker   : on détecte si Docker est accessible et on stocke le résultat.
        //             Si Docker est KO, on ne peut pas redémarrer Qdrant/n8n — on les
        //             vérifie quand même et on échoue proprement si nécessaire.
        //
        //  Qdrant   : BLOQUANT — si KO, on tente docker restart (si Docker OK).
        //  n8n      : BLOQUANT — idem.
        //  Botpress : on tente 3 fois avec 5s d'attente. Si toujours KO → warning seulement.

        stage('3. Vérification des Services') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                script {

                    // --- Docker ---
                    def dockerOK = (sh(script: 'docker ps', returnStatus: true) == 0)
                    if (dockerOK)
                        echo "Docker OK"
                    else
                        echo "AVERTISSEMENT : Docker inaccessible — les redémarrages automatiques sont désactivés."

                    // --- Qdrant ---
                    def qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    if (!qdrantOK) {
                        if (dockerOK) {
                            echo "Qdrant KO — tentative de redémarrage..."
                            sh 'docker restart desktop-qdrant-1 || true'
                            sleep 10
                            qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                            if (qdrantOK)
                                echo "Qdrant redémarré avec succès."
                            else
                                error "Qdrant toujours hors ligne après redémarrage — arrêt du pipeline."
                        } else {
                            error "Qdrant hors ligne et Docker inaccessible — impossible de réparer. Arrêt du pipeline."
                        }
                    } else {
                        echo "Qdrant OK"
                    }

                    // --- n8n ---
                    def n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    if (!n8nOK) {
                        if (dockerOK) {
                            echo "n8n KO — tentative de redémarrage..."
                            sh 'docker restart desktop-n8n-1 || true'
                            sleep 10
                            n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                            if (n8nOK)
                                echo "n8n redémarré avec succès."
                            else
                                error "n8n toujours hors ligne après redémarrage — arrêt du pipeline."
                        } else {
                            error "n8n hors ligne et Docker inaccessible — impossible de réparer. Arrêt du pipeline."
                        }
                    } else {
                        echo "n8n OK"
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

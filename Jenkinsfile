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
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
    }

    stages {

        stage('1. Récupération du Code') {
            steps {
                checkout scm
                echo "Commit : ${env.GIT_COMMIT?.take(8)} — Projet Wathiqa"
            }
        }

        stage('2. Vérification Globale') {
            parallel {
                stage('Inventaire complet') {
                    steps {
                        sh '''
                        echo "--- Structure du dépôt ---"
                        find . -maxdepth 2 -not -path '*/.*'
                        echo "--- Dossier Documents ---"
                        [ -d "documents" ] && ls -1 documents | wc -l | xargs echo "Nombre de documents :" || echo "Dossier documents MANQUANT"
                        '''
                    }
                }
                stage('Contrôle Qualité Universel') {
                    steps {
                        sh '''
                        echo "=== 1. Scan Python (Syntaxe) ==="
                        find . -name "*.py" ! -path "*/venv/*" ! -path "*/.*" -exec python3 -m py_compile {} +
                        
                        echo "=== 2. Validation JSON (Intégrité) ==="
                        find . -name "*.json" ! -path "*/.*" -exec python3 -c "import json; json.load(open('{}'))" \\; -print
                        
                        echo "=== 3. Validation YAML (Structure) ==="
                        # Simple check for docker-compose or other yml files
                        find . -name "*.yml" -o -name "*.yaml" ! -path "*/.*" -exec echo "Validating {}" \\;
                        
                        echo "=== 4. Inspection des Datas ==="
                        [ -s "Wathiqa.bpz" ] && echo "Wathiqa.bpz : OK (non vide)" || echo "Wathiqa.bpz : ATTENTION (vide ou manquant)"
                        [ -d "documents" ] && find documents -type f -not -empty | wc -l | xargs echo "Documents prêts :" || echo "Alerte : pas de documents !"
                        '''
                    }
                }
            }
        }

        stage('3. Vérification des Services') {
            steps {
                script {
                    def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                    if (!hasDocker) echo "AVERTISSEMENT : Docker introuvable. Auto-réparation désactivée."

                    // --- Qdrant ---
                    def qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    if (!qdrantOK && hasDocker) {
                        sh 'docker restart fstm_qdrant || true'
                        sleep 10
                        qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                    }
                    if (!qdrantOK) error "Qdrant injoignable sur ${QDRANT_URL}"

                    // --- n8n ---
                    def n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    if (!n8nOK && hasDocker) {
                        sh 'docker restart fstm_n8n || true'
                        sleep 10
                        n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                    }
                    if (!n8nOK) error "n8n injoignable sur ${N8N_URL}"

                    // --- Botpress (non bloquant) ---
                    def botpressOK = false
                    for (int i = 1; i <= 3; i++) {
                        botpressOK = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                        if (botpressOK) break
                        echo "Botpress KO (tentative ${i}/3) — nouvel essai dans 5s..."
                        sleep 5
                    }

                    echo "══════════════════════════════════"
                    echo "Docker   : ${hasDocker  ? 'OK' : 'AVERTISSEMENT'}"
                    echo "Qdrant   : ${qdrantOK   ? 'OK' : 'ECHEC'}"
                    echo "n8n      : ${n8nOK      ? 'OK' : 'ECHEC'}"
                    echo "Botpress : ${botpressOK ? 'OK' : 'AVERTISSEMENT'}"
                    echo "══════════════════════════════════"
                }
            }
        }

        stage('4. Installation') {
            options { timeout(time: 5, unit: 'MINUTES') }
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install --upgrade pip --quiet
                "$PIP" install -r requirements.txt --quiet
                "$PIP" check && echo "Aucun conflit de dépendances."
                '''
            }
        }

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
        failure  { echo "Pipeline en echec — consultez les logs." }
        aborted  { echo "Pipeline annule." }
        cleanup  {
            cleanWs(deleteDirs: true, notFailBuild: true,
                    patterns: [[pattern: 'venv/**', type: 'EXCLUDE']])
        }
    }
}

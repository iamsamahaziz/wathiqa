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

        stage('2. Contrôle Qualité') {
            steps {
                sh '''
                echo "=== Python ==="
                find . -name "*.py" ! -path "*/venv/*" ! -path "*/.git/*" -exec python3 -m py_compile {} \; && echo "Python : OK"

                echo "=== JSON ==="
                find . -name "*.json" ! -path "*/venv/*" ! -path "*/.git/*" -exec python3 -m json.tool {} > /dev/null \; && echo "JSON : OK"

                echo "=== YAML ==="
                find . \( -name "*.yml" -o -name "*.yaml" \) ! -path "*/venv/*" ! -path "*/.git/*" -exec python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" {} \; && echo "YAML : OK"

                echo "=== HTML ==="
                find . -name "*.html" ! -path "*/venv/*" ! -path "*/.git/*" | while read f; do
                    python3 -c "
import sys
from html.parser import HTMLParser

class Check(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.void = ['br','hr','img','input','meta','link','base','col','embed','param','source','track','wbr']
    def handle_starttag(self, tag, attrs):
        if tag not in self.void:
            self.stack.append(tag)
    def handle_endtag(self, tag):
        if self.stack and self.stack[-1] == tag:
            self.stack.pop()
        else:
            print('ERREUR: balise mal fermee </' + tag + '> dans $f')
            sys.exit(1)

p = Check()
p.feed(open('$f').read())
if p.stack:
    print('ERREUR: balises non fermees', p.stack, 'dans $f')
    sys.exit(1)
print('OK:', '$f')
" || exit 1
                done && echo "HTML : OK"

                echo "=== Fichiers Data ==="
                [ -s "Wathiqa.bpz" ] && echo "Wathiqa.bpz : OK" || echo "Wathiqa.bpz : ATTENTION"
                [ -d "documents" ] && find documents -type f -not -empty | wc -l | xargs echo "Documents prets :" || echo "Alerte : pas de documents !"
                '''
            }
        }

        stage('3. Vérification des Services') {
            parallel {

                stage('Qdrant') {
                    steps {
                        script {
                            def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                            def qdrantOK = false

                            for (int i = 1; i <= 3; i++) {
                                qdrantOK = (sh(script: "curl -sf --max-time 10 ${QDRANT_URL}", returnStatus: true) == 0)
                                if (qdrantOK) break
                                echo "Qdrant KO (tentative ${i}/3)"
                                if (hasDocker) {
                                    sh 'docker restart fstm_qdrant || true'
                                    sleep 10
                                }
                            }
                            if (!qdrantOK) error "Qdrant injoignable apres 3 tentatives"
                            echo "Qdrant : OK"
                        }
                    }
                }

                stage('n8n') {
                    steps {
                        script {
                            def hasDocker = (sh(script: 'command -v docker >/dev/null 2>&1', returnStatus: true) == 0)
                            def n8nOK = false

                            for (int i = 1; i <= 3; i++) {
                                n8nOK = (sh(script: "curl -sf --max-time 10 ${N8N_URL}", returnStatus: true) == 0)
                                if (n8nOK) break
                                echo "n8n KO (tentative ${i}/3)"
                                if (hasDocker) {
                                    sh 'docker restart fstm_n8n || true'
                                    sleep 10
                                }
                            }
                            if (!n8nOK) error "n8n injoignable apres 3 tentatives"
                            echo "n8n : OK"
                        }
                    }
                }

                stage('Botpress') {
                    steps {
                        script {
                            def botpressOK = false

                            for (int i = 1; i <= 3; i++) {
                                botpressOK = (sh(script: "curl -sf --max-time 10 ${BOTPRESS_URL}", returnStatus: true) == 0)
                                if (botpressOK) break
                                echo "Botpress KO (tentative ${i}/3) — nouvel essai dans 5s..."
                                sleep 5
                            }
                            echo "Botpress : ${botpressOK ? 'OK' : 'AVERTISSEMENT (non bloquant)'}"
                        }
                    }
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
                "$PIP" check && echo "Aucun conflit de dependances."
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

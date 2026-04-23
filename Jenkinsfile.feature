pipeline {
    agent any

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        BOTPRESS_URL = 'https://cdn.botpress.cloud'
        QDRANT_PORT  = "${10000 + env.BUILD_NUMBER.toInteger()}"
        N8N_PORT     = "${20000 + env.BUILD_NUMBER.toInteger()}"
        VENV         = "${WORKSPACE}/venv"
        PYTHON       = "${WORKSPACE}/venv/bin/python"
        PIP          = "${WORKSPACE}/venv/bin/pip"
    }

    stages {

        stage('1. Préparation de l\'Environnement') {
            steps {
                script {
                    def rawBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: "feature_iso"
                    def cleanBranch = rawBranch.split('/')[-1]
                    env.BRANCH_SLUG = cleanBranch.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase()

                    env.QDRANT_URL = "http://qdrant_${env.BRANCH_SLUG}:6333"
                    env.N8N_URL    = "http://n8n_${env.BRANCH_SLUG}:5678"

                    if (env.BRANCH_SLUG == 'main' || env.BRANCH_SLUG == 'master') {
                        error "Pipeline de branche feature détecté sur le main. Arrêt par sécurité."
                    }

                    checkout scm
                }
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

        stage('3. Déploiement des Services Isolés') {
            steps {
                script {
                    def slug = env.BRANCH_SLUG
                    echo "--- Déploiement des services pour : ${slug} ---"

                    sh "docker stop qdrant_${slug} n8n_${slug} || true"
                    sh "docker rm   qdrant_${slug} n8n_${slug} || true"

                    sh "docker network create fstm_network || true"
                    sh "docker network connect fstm_network fstm_jenkins || true"
                    sh "docker run -d --name qdrant_${slug} --network fstm_network -p ${env.QDRANT_PORT}:6333 qdrant/qdrant"
                    sh "docker run -d --name n8n_${slug} --network fstm_network -p ${env.N8N_PORT}:5678 n8nio/n8n"

                    sleep 25
                }
            }
        }

        stage('4. Vérification de Santé') {
            parallel {

                stage('Qdrant Health') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def qdrantOK = false

                            for (int i = 1; i <= 3; i++) {
                                qdrantOK = (sh(script: "curl -sf --max-time 10 ${env.QDRANT_URL}", returnStatus: true) == 0)
                                if (qdrantOK) break
                                echo "Qdrant KO (tentative ${i}/3)"
                                sh "docker restart qdrant_${slug} || true"
                                sleep 10
                            }
                            if (!qdrantOK) error "Qdrant injoignable apres 3 tentatives"
                            echo "Qdrant : OK"
                        }
                    }
                }

                stage('n8n Health') {
                    steps {
                        script {
                            def slug = env.BRANCH_SLUG
                            def n8nOK = false

                            for (int i = 1; i <= 3; i++) {
                                n8nOK = (sh(script: "curl -sf --max-time 10 ${env.N8N_URL}", returnStatus: true) == 0)
                                if (n8nOK) break
                                echo "n8n KO (tentative ${i}/3)"
                                sh "docker restart n8n_${slug} || true"
                                sleep 10
                            }
                            if (!n8nOK) error "n8n injoignable apres 3 tentatives"
                            echo "n8n : OK"
                        }
                    }
                }

                stage('Botpress Cloud Health') {
                    steps {
                        script {
                            def botpressOK = false

                            for (int i = 1; i <= 3; i++) {
                                botpressOK = (sh(script: "curl -sf --max-time 10 ${env.BOTPRESS_URL}", returnStatus: true) == 0)
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

        stage('5. Indexation IA & RAG') {
            steps {
                sh '''
                [ ! -d "$VENV" ] && python3 -m venv "$VENV"
                "$PIP" install -r requirements.txt --quiet
                '''
                withCredentials([string(credentialsId: 'MISTRAL_KEY', variable: 'MISTRAL_KEY')]) {
                    sh """
                    export MISTRAL_KEY=\$MISTRAL_KEY
                    export QDRANT_URL=${env.QDRANT_URL}
                    "\$PYTHON" load.py
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Isolation réussie pour la branche ${env.BRANCH_SLUG}."
        }
        failure {
            script {
                echo "Nettoyage après échec de la branche ${env.BRANCH_SLUG}..."
                sh "docker stop qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
                sh "docker rm   qdrant_${env.BRANCH_SLUG} n8n_${env.BRANCH_SLUG} || true"
            }
        }
        cleanup {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}

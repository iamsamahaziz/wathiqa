pipeline {
    agent any

    environment {
        VENV_DIR = '.venv'
        PYTHON = "${VENV_DIR}/bin/python"
        PIP = "${VENV_DIR}/bin/pip"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Environment Setup') {
            steps {
                sh '''
                    set -e
                    python3 -m venv "$VENV_DIR"
                    "$PIP" install --upgrade pip
                    "$PIP" install -r requirements.txt
                '''
            }
        }

        stage('Python Lint') {
            steps {
                sh '''
                    set -e
                    PY_FILES="$(find . -maxdepth 1 -name '*.py' -print)"
                    if [ -z "$PY_FILES" ]; then
                        echo "No Python files to lint."
                        exit 0
                    fi
                    "$VENV_DIR/bin/flake8" --select=E9,F63,F7,F82 --show-source --statistics $PY_FILES
                    "$VENV_DIR/bin/pylint" --disable=all --enable=unused-import,unused-variable,undefined-variable,import-error $PY_FILES
                '''
            }
        }

        stage('Validate Project Files') {
            steps {
                sh '''
                    set -e
                    "$PYTHON" -m json.tool Wathiqa.json > /dev/null
                    "$PYTHON" -m py_compile load.py
                    "$PYTHON" - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

parser = HTMLParser()
parser.feed(Path("Page_chatbot.html").read_text(encoding="utf-8"))
print("HTML syntax validation passed")
PY
                '''
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    set -e
                    ! grep -RInE "(MISTRAL_API_KEY\\s*=\\s*['\\\"][^'\\\"]+['\\\"]|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,48})" \
                        --exclude-dir=.git --exclude=Jenkinsfile .
                '''
            }
        }

        stage('Build Artifacts') {
            steps {
                sh '''
                    set -e
                    mkdir -p artifacts
                    cp Jenkinsfile load.py requirements.txt Wathiqa.json Page_chatbot.html artifacts/
                '''
                archiveArtifacts artifacts: 'artifacts/**', fingerprint: true
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline Wathiqa terminé avec succès.'
        }
        failure {
            echo '❌ Pipeline Wathiqa en échec. Vérifiez les logs des stages.'
        }
    }
}

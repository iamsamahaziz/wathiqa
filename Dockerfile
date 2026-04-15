# 1. Image de base : Python 3.10 léger
FROM python:3.10-slim

# 2. Dossier de travail dans le conteneur
WORKDIR /app

# 3. Installation des dépendances (en premier pour profiter du cache Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copie du reste des fichiers du projet
COPY . .

# 5. Définition de la variable d'environnement (sera remplacée par Jenkins)
ENV MISTRAL_KEY=""

# 6. Commande de lancement (On lance votre script principal)
CMD ["python", "load.py"]

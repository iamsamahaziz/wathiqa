# 🇲🇦 Wathiqa (وثيقة) — Guide Complet & Masterclass Jenkins

> **L'assistant intelligent pour simplifier 57 démarches administratives marocaines.**

Wathiqa n'est pas qu'un simple chatbot. C'est un pipeline MLOps complet utilisant une architecture RAG (Retrieval-Augmented Generation) bilingue. Ce guide est conçu pour vous permettre de reproduire l'ensemble du projet chez vous, soit manuellement, soit via Jenkins.

---

## 🏗️ 1. Architecture du Système

Le projet repose sur 5 piliers :
1.  **Botpress Cloud** : L'interface utilisateur.
2.  **ngrok** : Le pont sécurisé entre le Cloud et votre machine locale.
3.  **n8n** : Le cerveau qui orchestre la recherche et la génération.
4.  **Qdrant** : La base de données vectorielle ultra-rapide.
5.  **Mistral AI** : Les modèles `mistral-embed` et `mistral-small` pour comprendre et répondre.

---

## 🚀 2. Installation Manuelle (Étape par Étape)

### 2.1. Prérequis sur votre PC
- **Python 3.10+** (Indispensable pour les scripts d'indexation).
- **Docker Desktop** (Pour faire tourner Qdrant en local).
- **Une clé API Mistral AI** (À obtenir sur [console.mistral.ai](https://console.mistral.ai)).

### 2.2. Lancement de la Base Vectorielle (Qdrant)
Ouvrez un terminal et tapez :
```bash
docker run -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```
*Vérifiez que ça fonctionne en ouvrant `http://localhost:6333/dashboard` dans votre navigateur.*

### 2.3. Indexation des 57 Documents (Python)
Les documents bruts sont dans le dossier `documents/`.
```bash
# Dans le dossier Projet_IA
python -m venv venv
source venv/bin/activate  # (Sur Windows: venv\Scripts\activate)

pip install -r requirements.txt

# Configurez votre clé API (IMPORTANT)
export MISTRAL_KEY="VOTRE_CLE_ICI"  # (Sur Windows: set MISTRAL_KEY=VOTRE_CLE_ICI)

# Lancez l'indexation
python load.py
```

### 2.4. Orchestration avec n8n
1.  Lancez n8n (soit via Docker, soit via npm).
2.  Dans n8n, cliquez sur **Import from File** et choisissez `Wathiqa.json`.
3.  Configurez les nœuds :
    *   **Mistral Node** : Collez votre clé API.
    *   **Qdrant Node** : L'URL est `http://localhost:6333` (ou l'IP Docker).
4.  Cliquez sur le bouton **Execute Workflow** pour qu'il soit à l'écoute.

### 2.5. Tunneling avec ngrok (Critique)
Pour que Botpress puisse envoyer des messages à votre n8n local :
```bash
ngrok http 5678
```
*Copiez l'URL `https://xxxx-xxxx.ngrok-free.app` qui s'affiche.*

### 2.6. Interface Botpress Cloud
1.  Créez un bot sur [Botpress Cloud](https://app.botpress.cloud).
2.  Allez dans **Studio** > **Import/Export** > **Import** et choisissez `Wathiqa.bpz`.
3.  Dans l'étape "Execution de code", remplacez l'URL cible par votre URL ngrok + `/webhook/wathiqa`.
4.  Cliquez sur **Publish**.

---

## 🚀 3. GUIDE DÉTAILLÉ JENKINS (Masterclass CI/CD)

Jenkins automatise tout : tests de syntaxe, réparation des services et ré-indexation automatique.

### 3.1. Configuration Initiale
1.  Installez Jenkins (URL par défaut : `http://localhost:8080`).
2.  **Plugins recommandés** : `Pipeline`, `Git`, `Credentials Binding`, `Docker Pipeline`.

### 3.2. Gestion des Clés Secrètes
Ne mettez jamais votre clé Mistral dans le code !
1.  Allez dans **Administrer Jenkins** > **Credentials**.
2.  Créez un nouveau secret de type **Secret Text**.
3.  ID : `MISTRAL_KEY`.
4.  Secret : Votre clé API réelle.

### 3.3. Création du Job de Pipeline
1.  Cliquez sur **Nouveau Item** > Nom : `Wathiqa-Pipeline` > **Pipeline**.
2.  Dans la section **Pipeline** :
    *   Definition : `Pipeline script from SCM`.
    *   SCM : `Git`.
    *   Repository URL : `https://github.com/iamsamahaziz/TP_IA.git`.
    *   Branch : `*/main`.
    *   Script Path : `Jenkinsfile`.
3.  Cliquez sur **Sauvegarder**, puis **Lancer le build**.

### 3.4. Le mécanisme de "Self-Healing"
Mon `Jenkinsfile` contient une logique intelligente :
- Si Qdrant tombe en panne, Jenkins le détecte via un `curl` et tente un `docker restart desktop-qdrant-1` automatiquement.
- Si le build prend plus de 15 minutes, il s'arrête proprement grâce au `timeout`.

---

## 🌍 Fonctionnalités Bilingues
Wathiqa répond toujours en deux temps :
- **Réponse Standard (Français)** : Précise et formelle.
- **Réponse Résumée (Daridja)** : Pour une meilleure accessibilité locale.

---
**Auteurs** : Samah AZIZ & Keltoum AGAZZARA
**Projet** : Master Intelligence Artificielle - 2026

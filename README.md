# 🇲🇦 Wathiqa (وثيقة) — Le Guide Technique (Masterclass RAG)

> **"L'accès à l'information administrative est un droit, Wathiqa en fait une conversation."**

---

### 🌟 Ce projet est-il fait pour vous ?
**OUI !** Même si vous n'êtes pas informaticien, ce guide a été conçu pour être **"Zero-Echec"**. En suivant les étapes ci-dessous, vous aurez exactement le même chatbot que nous sur votre ordinateur en moins de 15 minutes.

---

## 🧐 1. Petit Lexique (Pour comprendre sans être expert)

*   **Terminal / Invite de commande** : L'application noire sur votre ordi (tapez "cmd" dans votre barre de recherche Windows). C'est là qu'on donne les ordres à l'ordi.
*   **Docker** : Un programme qui fait tout le travail difficile de configuration pour vous.
*   **ngrok** : Un "pont" qui permet à votre bot de recevoir les messages d'Internet sur votre PC.
*   **API Key** : Un mot de passe long qui permet à l'IA (Mistral) de vous reconnaître.

---

## 🏗️ 2. Comment ça marche ? (La Logique)

| Outil | Son rôle | Analogie simple |
| :--- | :--- | :--- |
| **Botpress** | L'écran de discussion. | La vitrine du magasin |
| **ngrok** | Le tunnel de communication. | La ligne de téléphone |
| **n8n** | Dirige la question vers l'IA. | Le réceptionniste |
| **Qdrant** | Contient la mémoire (57 documents). | La bibliothèque |
| **Mistral AI** | Réfléchit et répond en bilingue. | L'expert intelligent |

---

## 🚀 3. Guide d'Installation (Pas à Pas 100% Garanti)

### 📋 Phase 0 : Préparation (Les comptes)
1. **Mistral AI** : Créez un compte gratuit sur [console.mistral.ai](https://console.mistral.ai/), copiez votre **API KEY**.
2. **ngrok** : Créez un compte sur [ngrok.com](https://ngrok.com/), récupérez votre **Authtoken**.
3. **Le Projet** : Cliquez sur le bouton vert **"Code"** en haut de cette page, puis sur **"Download ZIP"**. Décompressez le dossier sur votre Bureau.

---

### Etape 1 : Activer la Mémoire (Docker)
1. Installez [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Ouvrez Docker. Une fois qu'il est prêt (icône verte), ouvrez votre **Terminal**.
3. Copiez cette ligne et faites Entrée :
   ```bash
   docker run -d -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant
   ```
4. **✅ Test** : Tapez `http://localhost:6333/dashboard` dans votre navigateur. Si une page Qdrant s'affiche, vous avez réussi !

---

### Etape 2 : Préparer l'intelligence (Python)
1. Installez [Python](https://www.python.org/downloads/) (Cochez bien **"Add to PATH"**).
2. Dans votre terminal, entrez dans le dossier du projet (tapez `cd` puis faites glisser le dossier `Projet_IA` dans le terminal).
3. Tapez ces commandes une par une :
   - `python -m venv venv`
   - `.\venv\Scripts\activate` (sur Mac: `source venv/bin/activate`)
   - `pip install -r requirements.txt`
   - `set MISTRAL_KEY=votre_cle_ici` (sur Mac: `export MISTRAL_KEY=votre_cle_ici`)
   - `python load.py`
   **✅ Succès** : Vos 57 documents sont maintenant dans la mémoire de l'IA !

---

### Etape 3 : Créer le Pont (ngrok)
1. **Ouvrez UN NOUVEAU terminal** (ne fermez pas les autres !).
2. Tapez : `ngrok http 5678`.
3. **✅ Action** : Copiez le lien qui commence par `https://...` (ex: `https://a1b2.ngrok-free.app`).

---

### Etape 4 : L'Orchestrateur (n8n)
1. **Ouvrez ENCORE UN NOUVEAU terminal**.
2. Tapez : `npx n8n`. Patientez, puis allez sur `http://localhost:5678`.
3. Cliquez sur **Workflows** > **Import from File...** et choisissez le fichier `Wathiqa.json`.
4. Double-cliquez sur le nœud **Mistral AI**, collez votre clé. Cliquez sur **Execute Workflow**.

---

### Etape 5 : L'interface Chat (Botpress)
1. Sur [Botpress Cloud](https://app.botpress.cloud/), créez un bot.
2. Dans le Studio, cliquez sur le logo Botpress (en haut à gauche) > **Import/Export** > **Import** et choisissez le fichier `Wathiqa.bpz`.
3. Cherchez le nœud de code, remplacez l'URL par **VOTRE_LIEN_NGROK**/webhook/wathiqa.
   - *Exemple : `https://a1b2.ngrok-free.app/webhook/wathiqa`*
4. Cliquez sur **Publish**. **C'est fini ! Vous avez votre propre Wathiqa !**

---

## 👥 Équipe Projet
- **Samah AZIZ** (Architecture & Logique RAG)
- **Keltoum AGAZZARA** (Stratégie Documentaire & UI Design)

**Licence Ingénierie Informatique (LST 2I) — FST Mohammedia**
**Université Hassan II de Casablanca — 2026**

# 🇲🇦 Wathiqa (وثيقة) — Guide Technique (Masterclass RAG)

> **"L'accès à l'information administrative est un droit, Wathiqa en fait une conversation."**

**Note pour les non-informaticiens** : Ce projet utilise des outils "Low-Code". Cela signifie que même si vous ne savez pas programmer, vous pouvez le faire fonctionner en suivant ce guide à la lettre. Les étapes sont simples et aucun code n'est à écrire !

---

## 🧐 1. Petit Lexique (Pour comprendre sans être expert)

Si vous n'êtes pas du métier, voici à quoi servent les outils que vous allez installer :
*   **Conteneur (Docker)** : C'est comme une boîte qui contient tout le programme déjà installé. Vous n'avez qu'à ouvrir la boîte.
*   **Terminal / Console** : C'est l'application noire ou bleue sur votre ordi où l'on tape des commandes. Ne paniquez pas, il suffit de copier-coller ce qui est écrit ici.
*   **API (Clé)** : C'est comme un mot de passe qui permet à un outil de parler à un autre (comme Mistral).
*   **Tunnel (ngrok)** : C'est une ligne téléphonique sécurisée entre votre PC et l'IA sur internet.

---

## 🧠 2. Comprendre l'Architecture : Qui fait quoi ?

| Outil | Son rôle dans Wathiqa | Image parlante |
| :--- | :--- | :--- |
| **Botpress** | L'interface de discussion (le chat). | Le visage du bot |
| **ngrok** | Relie votre ordi à internet sécurisé. | Le pont invisible |
| **n8n** | Dirige les questions vers la bonne mémoire. | Le chef d'orchestre |
| **Qdrant** | Contient la mémoire des 57 procédures. | La bibliothèque |
| **Mistral AI** | Réfléchit et répond en Français/Darija. | Le cerveau |

---

## 🚀 3. Guide d'Installation (Pas à pas pour TOUS)

### 📋 Phase 0 : Préparation (Les comptes)
1. Créez un compte gratuit sur [Mistral AI](https://console.mistral.ai/) et copiez votre **API KEY**.
2. Créez un compte sur [ngrok.com](https://ngrok.com/) pour avoir votre jeton de sécurité.
3. Si vous ne savez pas utiliser `git`, cliquez sur le bouton vert **"Code"** en haut de cette page et choisissez **"Download ZIP"**. Décompressez le dossier sur votre bureau.

---

### Etape 1 : Le Conteneur Qdrant (Docker)
1. Téléchargez et installez [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Ouvrez Docker. Une fois lancé, ouvrez votre **Terminal** (tapez "Invite de commande" ou "Terminal" dans votre barre de recherche Windows).
3. Copiez-collez cette ligne et faites Entrée :
   ```bash
   docker run -d -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant
   ```
4. **✅ Test** : Ouvrez `http://localhost:6333/dashboard` dans votre navigateur. Si ça s'affiche, bravo !

---

### Etape 2 : Préparer les données (Python)
1. Installez [Python](https://www.python.org/downloads/) (cochez bien "Add to PATH" lors de l'installation).
2. Dans le terminal, allez dans votre dossier `Projet_IA` et tapez :
   - `python -m venv venv`
   - `.\venv\Scripts\activate` (ou `source venv/bin/activate` sur Mac)
   - `pip install -r requirements.txt`
3. Donnez votre clé Mistral à l'ordi :
   - `set MISTRAL_KEY=votre_cle_ici` (Windows)
   - `export MISTRAL_KEY=votre_cle_ici` (Mac)
4. Enfin, tapez : `python load.py`. Vos documents sont maintenant dans la mémoire de l'IA.

---

### Etape 3 : Activer le Tunnel (ngrok)
1. Dans un terminal vide, tapez : `ngrok http 5678`.
2. **✅ Important** : Copiez l'URL qui commence par `https://...` (elle ressemble à `https://a1b2-c3d4.ngrok-free.app`).

---

### Etape 4 : L'Orchestrateur (n8n)
1. Tapez `npx n8n` dans un terminal. Allez sur `http://localhost:5678`.
2. Cliquez sur **Workflows** > **Import from File** et choisissez `Wathiqa.json` qui est dans votre dossier.
3. Cliquez sur le nœud Mistral et collez votre clé. Cliquez sur **Execute Workflow**.

---

### Etape 5 : L'interface Chat (Botpress)
1. Sur [Botpress Cloud](https://app.botpress.cloud/), créez un bot.
2. Cliquez sur **Import** et donnez-lui le fichier `Wathiqa.bpz`.
3. Dans le code du bot, remplacez l'URL par **VOTRE_URL_NGROK**/webhook/wathiqa.
4. Cliquez sur **Publish**. **C'est fini !**

---

## 👥 Équipe Projet
- **Samah AZIZ** (Architecture & Logique RAG)
- **Keltoum AGAZZARA** (Stratégie Documentaire & UI Design)

**Licence Ingénierie Informatique (LST 2I) — FST Mohammedia**
**Université Hassan II de Casablanca — 2026**

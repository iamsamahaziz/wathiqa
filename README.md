# 🇲🇦 Wathiqa (وثيقة) — Le Guide Technique (Masterclass RAG)

> **"L'accès à l'information administrative est un droit, Wathiqa en fait une conversation."**

**Note pour les non-informaticiens** : Ce projet est une "Masterclass" pas-à-pas. Même sans savoir programmer, vous pouvez le réussir en 15 minutes en suivant les 5 étapes ci-dessous.

---

## 🧐 1. Petit Lexique (Pour comprendre sans être expert)

*   **Docker** : Une application qui fait tourner d'autres programmes (comme Qdrant) sans rien configurer.
*   **Terminal** : L'appli noire de votre ordi. On y tape des ordres.
*   **ngrok** : Le tunnel qui permet à l'IA sur internet de parler à votre PC.
*   **n8n** : Le chef d'orchestre qui relie tous les morceaux du projet.

---

## 🧠 2. Architecture : Qui fait quoi ?

| Outil | Utilité | Image |
| :--- | :--- | :--- |
| **Botpress** | L'écran de chat pour l'utilisateur. | Le Visage |
| **ngrok** | Le pont entre internet et votre PC. | Le Pont |
| **n8n** | Dirige les questions vers la mémoire. | Le Cœur |
| **Qdrant** | Stocke les 57 procédures administratives. | La Mémoire |
| **Mistral AI** | Réfléchit et répond en Français/Darija. | Le Cerveau |

---

## 🚀 3. Guide d'Installation (Pas à Pas Absolu)

### 📋 Phase 0 : Préparation (Les comptes)
1. Créez votre compte sur [Mistral AI](https://console.mistral.ai/) et copiez votre **API KEY**.
2. Créez votre compte sur [ngrok.com](https://ngrok.com/) et récupérez votre jeton de sécurité.
3. Téléchargez ce projet : Cliquez sur le bouton vert **"Code"** en haut de cette page, puis **"Download ZIP"**. Décompressez-le sur votre bureau.

---

### Etape 1 : Lancer la Mémoire (Docker)
1. Téléchargez et installez **Docker Desktop**.
2. Lancez Docker. Une fois qu'il est "vert" (actif), ouvrez votre **Terminal**.
3. Copiez-collez cette commande :
   ```bash
   docker run -d -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant
   ```
4. **✅ Vérification** : Ouvrez `http://localhost:6333/dashboard`. Si la page de Qdrant s'affiche, l'étape 1 est réussie !

---

### Etape 2 : Préparer les données (Python)
*Note : Utilisez le même terminal que l'étape 1.*
1. Installez [Python](https://www.python.org/downloads/) (Cochez "Add to PATH").
2. Dans le terminal, entrez dans le dossier `Projet_IA` (tapez `cd` suivi du chemin du dossier).
3. Tapez ces commandes l'une après l'autre :
   - `python -m venv venv`
   - `.\venv\Scripts\activate` (ou `source venv/bin/activate` sur Mac)
   - `pip install -r requirements.txt`
   - `set MISTRAL_KEY=votre_cle_api_ici` (Windows) ou `export MISTRAL_KEY=...` (Mac)
   - `python load.py`
4. **✅ Vérification** : Le terminal doit dire que les documents ont été chargés.

---

### Etape 3 : Ouvrir le Tunnel (ngrok)
1. **Ouvrez UN NOUVEAU terminal** (laissez les autres ouverts !).
2. Tapez : `ngrok http 5678`.
3. **✅ Action** : Copiez l'URL HTTPS qui s'affiche (ex: `https://abcd-123.ngrok-free.app`).

---

### Etape 4 : L'Orchestrateur (n8n)
1. **Ouvrez ENCORE UN NOUVEAU terminal**.
2. Tapez : `npx n8n`. Attendez que ça lance, puis allez sur `http://localhost:5678`.
3. Cliquez sur **Workflows** > **Import from File...** et choisissez le fichier `Wathiqa.json`.
4. Double-cliquez sur le nœud **Mistral AI** et collez votre clé. 
5. Cliquez sur le gros bouton **"Execute Workflow"** en haut.

---

### Etape 5 : L'interface Chat (Botpress)
1. Sur [Botpress Cloud](https://app.botpress.cloud/), créez un bot.
2. Dans le Studio, cliquez sur le logo Botpress (haut gauche) > **Import/Export** > **Import** et donnez-lui le fichier `Wathiqa.bpz`.
3. Cherchez le nœud de code et remplacez l'URL par votre lien ngrok + `/webhook/wathiqa`.
   - *Exemple* : Si ngrok vous a donné `https://abcd.ngrok-free.app`, votre URL finale sera `https://abcd.ngrok-free.app/webhook/wathiqa`.
4. Cliquez sur **Publish**. **Félicitations, votre projet est en ligne !**

---

## 👥 Équipe Projet
- **Samah AZIZ** (Architecture & Logique RAG)
- **Keltoum AGAZZARA** (Stratégie Documentaire & UI Design)

**Licence Ingénierie Informatique (LST 2I) — FST Mohammedia**
**Université Hassan II de Casablanca — 2026**

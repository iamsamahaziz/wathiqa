# 🇲🇦 Wathiqa (وثيقة) — Chatbot des Démarches Administratives Marocaines

## 📌 Problème Résolu

Les citoyens marocains font face à un problème récurrent : **trouver les bonnes informations sur les démarches administratives**. Chaque procédure (CNIE, passeport, carte grise, visa, etc.) nécessite des documents spécifiques, implique des frais différents, et se fait dans des lieux précis. Ces informations sont dispersées sur plusieurs sites web, souvent incomplètes ou obsolètes.

**Wathiqa** résout ce problème en centralisant **57 démarches administratives** dans un chatbot intelligent bilingue (français / darija) qui répond instantanément aux questions des citoyens avec des informations précises et structurées, accompagnées d'un résumé en darija marocaine.

### Ce que Wathiqa apporte :
- Réponses instantanées sur les documents nécessaires, lieux, délais et coûts
- Couverture de 10 domaines administratifs (état civil, identité, voyage, véhicule, emploi, CNSS/santé, famille, logement, finances, aide sociale)
- Interface bilingue français / darija marocaine
- Chaque réponse inclut un résumé en darija (🇲🇦 بالدارجة)
- Informations basées sur une base de données vérifiée (RAG)

---

## 🏗️ Architecture de la Solution

Le projet repose sur **5 composants principaux** qui travaillent ensemble :

### 1. Botpress Cloud (Le Frontend — L'interface de discussion)
**C'est quoi ?** Botpress est une plateforme cloud qui permet de créer des chatbots visuellement. C'est ce que l'utilisateur voit et avec quoi il interagit.

**Son rôle dans Wathiqa :**
- Afficher le menu de 10 catégories bilingues (FR/AR) et leurs sous-catégories
- Capturer la question de l'utilisateur (via menu ou question libre)
- Envoyer la question au backend (n8n) via un appel HTTP
- Afficher la réponse bilingue retournée par l'IA

### 2. n8n (Le Backend — Le chef d'orchestre)
**C'est quoi ?** n8n est un outil d'automatisation open-source qui permet de créer des "workflows" (chaînes d'actions) visuellement, sans écrire beaucoup de code.

**Son rôle dans Wathiqa :**
- Recevoir la question envoyée par Botpress via un webhook
- Orchestrer le pipeline RAG complet en 8 nœuds : extraction de la question → embedding → recherche vectorielle → construction du prompt → génération de la réponse
- Retourner la réponse finale à Botpress

### 3. ngrok (Le Tunnel — Le pont entre Cloud et Local)
**C'est quoi ?** ngrok est un outil qui crée un tunnel sécurisé (HTTPS) entre votre ordinateur local et internet.

**Son rôle dans Wathiqa :**
- Botpress Cloud est sur internet, mais n8n tourne sur votre PC (localhost:5678). Sans ngrok, Botpress ne peut pas atteindre votre PC.
- ngrok expose votre port local 5678 via une URL publique (ex: `https://abcd.ngrok-free.app`)
- Cette URL est utilisée par Botpress pour envoyer les questions à n8n

### 4. Qdrant (La Base Vectorielle — La mémoire intelligente)
**C'est quoi ?** Qdrant est une base de données spécialisée dans le stockage de "vecteurs" (des listes de nombres qui représentent le sens d'un texte).

**Son rôle dans Wathiqa :**
- Stocker les 57 documents administratifs sous forme de vecteurs (collection `AdminBot`)
- Quand une question arrive, Qdrant cherche les 3 documents les plus proches **par le sens** (pas par les mots exacts)
- Utilise la distance cosinus (Cosine Similarity) avec un seuil de score > 0.20

### 5. Mistral AI (L'Intelligence Artificielle)
**C'est quoi ?** Mistral AI est une entreprise française qui fournit des modèles d'IA. On utilise deux de leurs modèles via une API.

**Son rôle dans Wathiqa (stratégie à deux modèles) :**
- **`mistral-embed`** : Transforme les textes en vecteurs de dimension 1024. Utilisé pour indexer les documents ET pour convertir la question de l'utilisateur en vecteur
- **`mistral-small-latest`** : Lit les documents trouvés par Qdrant et rédige la réponse finale en français + darija (temperature 0.1 pour des réponses précises)

### 6. Docker (L'Infrastructure de Conteneurisation)
**C'est quoi ?** Docker est un logiciel qui permet de faire tourner des applications dans des "conteneurs" isolés, comme des mini-ordinateurs virtuels. Au lieu d'installer Qdrant manuellement (ce qui est complexe), Docker le fait en une seule commande.

**Son rôle dans Wathiqa :**
- Faire tourner Qdrant sans aucune configuration manuelle
- Garantir que le projet fonctionne de la même manière sur n'importe quel ordinateur (Windows, Mac, Linux)

---

## 🔄 Pipeline RAG — Le flux complet (de la question à la réponse)

Voici exactement ce qui se passe quand un citoyen pose une question :

```
1. L'utilisateur tape "Comment faire mon passeport ?" dans Botpress
        │
        ▼
2. Botpress envoie la question via HTTP POST à l'URL ngrok
        │
        ▼
3. ngrok transfère la requête vers n8n (localhost:5678)
        │
        ▼
4. n8n — Nœud "Webhook" : reçoit la question
        │
        ▼
5. n8n — Nœud "Code JavaScript" : extrait la question du body JSON
        │
        ▼
6. n8n — Nœud "Mistral Embed" : convertit la question en vecteur (1024 dimensions)
        │
        ▼
7. n8n — Nœud "Qdrant Body" : prépare la requête de recherche vectorielle
        │
        ▼
8. n8n — Nœud "Qdrant Search" : cherche les 3 documents les plus proches
        │
        ▼
9. n8n — Nœud "Build Prompt" : construit le prompt système + contexte + question
        │
        ▼
10. n8n — Nœud "Mistral Completion" : génère la réponse bilingue (FR + Darija)
        │
        ▼
11. n8n — Nœud "Réponse Finale" : extrait le texte de la réponse
        │
        ▼
12. n8n — Nœud "Respond to Webhook" : renvoie le JSON { answer: "..." } à Botpress
        │
        ▼
13. Botpress affiche la réponse bilingue à l'utilisateur
```

---

## 📁 Structure des Fichiers

```
Wathiqa/
├── load.py                  # Script Python de chargement des documents dans Qdrant
├── Wathiqa.json             # Workflow n8n complet (importable directement)
├── Wathiqa.bpz              # Bot Botpress complet (importable directement)
├── requirements.txt         # Dépendances Python
├── README.md                # Ce fichier
└── documents/               # 57 fichiers .txt des démarches administratives
    ├── CIN.txt
    ├── passeport.txt
    ├── Carte grise.txt
    ├── Mariage.txt
    ├── Divorce.txt
    ├── Visa Schengen.txt
    └── ... (57 fichiers au total)
```

---

## 🚀 Guide d'Installation Complet (Étape par Étape)

### Prérequis à installer sur votre PC

| Outil | Téléchargement | Pourquoi ? |
|-------|----------------|------------|
| **Docker Desktop** | [docker.com](https://www.docker.com/products/docker-desktop/) | Pour faire tourner Qdrant |
| **Python 3.8+** | [python.org](https://www.python.org/downloads/) | Pour le script d'indexation |
| **Node.js** | [nodejs.org](https://nodejs.org/) | Pour faire tourner n8n |
| **ngrok** | [ngrok.com](https://ngrok.com/) | Pour créer le tunnel |
| **Compte Botpress** | [app.botpress.cloud](https://app.botpress.cloud/) | Pour l'interface chat |
| **Clé API Mistral** | [console.mistral.ai](https://console.mistral.ai/) | Pour l'IA |

---

### Étape 1 : Récupérer le projet

**Option A (avec Git) :**
```bash
git clone https://github.com/iamsamahaziz/TP_IA.git
cd TP_IA
```

**Option B (sans Git) :**
Cliquez sur le bouton vert **"Code"** en haut de cette page GitHub, puis sur **"Download ZIP"**. Décompressez le dossier.

---

### Étape 2 : Lancer Qdrant (la base de données vectorielle)

1. Ouvrez **Docker Desktop** et attendez qu'il soit prêt.
2. Ouvrez un **terminal** (tapez "cmd" ou "PowerShell" dans la barre de recherche Windows).
3. Tapez cette commande :
```bash
docker run -d -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

**Ce que fait cette commande :**
- `docker run` : lance un conteneur
- `-d` : en arrière-plan (le terminal reste libre)
- `-p 6333:6333` : rend Qdrant accessible sur le port 6333
- `-v qdrant_storage:/qdrant/storage` : conserve les données même si vous redémarrez

**✅ Vérification :** Ouvrez `http://localhost:6333/dashboard` dans votre navigateur. Si vous voyez l'interface Qdrant, c'est réussi.

---

### Étape 3 : Indexer les 57 documents dans Qdrant (Python)

1. Ouvrez un terminal dans le dossier du projet.
2. Créez un environnement virtuel Python :

**Sur Windows :**
```bash
python -m venv venv
.\venv\Scripts\activate
```

**Sur Mac/Linux :**
```bash
python3 -m venv venv
source venv/bin/activate
```

3. Installez les dépendances :
```bash
pip install -r requirements.txt
```

4. Configurez votre clé API Mistral :

**Sur Windows :**
```bash
set MISTRAL_KEY=votre_cle_api_ici
```

**Sur Mac/Linux :**
```bash
export MISTRAL_KEY=votre_cle_api_ici
```

5. Lancez l'indexation :
```bash
python load.py
```

**Ce que fait ce script :**
- Il parcourt le dossier `documents/` et lit les 57 fichiers `.txt`
- Pour chaque fichier, il envoie le contenu à l'API Mistral pour le transformer en vecteur
- Il stocke chaque vecteur + le contenu texte dans la collection `AdminBot` de Qdrant
- Il attend 1.2 seconde entre chaque document pour respecter les limites de l'API

**✅ Vérification :** Le terminal affiche `✅` pour chaque document chargé, puis `🎉 Pipeline d'indexation terminé !`.

---

### Étape 4 : Lancer n8n (l'orchestrateur)

1. **Ouvrez un NOUVEAU terminal** (ne fermez pas les autres !).
2. Lancez n8n :
```bash
npx n8n
```
3. Ouvrez `http://localhost:5678` dans votre navigateur.
4. Cliquez sur **Workflows** > **Add Workflow** > **Import from File...** et sélectionnez le fichier `Wathiqa.json`.
5. **Configuration des nœuds :** Double-cliquez sur le nœud **"Mistral Embed"** et remplacez la clé API par la vôtre. Faites la même chose pour le nœud **"Mistral Completion"**.
6. **Configuration Qdrant :** Vérifiez que l'URL dans le nœud "Qdrant search" pointe vers `http://localhost:6333`.
7. Cliquez sur **Execute Workflow**. Le statut doit afficher "Waiting for Webhook".

---

### Étape 5 : Lancer ngrok (le tunnel)

1. **Ouvrez un NOUVEAU terminal**.
2. Tapez :
```bash
ngrok http 5678
```

3. ngrok affiche une URL publique, par exemple :
```
Forwarding  https://a1b2-c3d4.ngrok-free.app -> http://localhost:5678
```

4. **Copiez cette URL HTTPS**. Vous en avez besoin pour l'étape suivante.

Pour un domaine fixe gratuit (qui ne change pas à chaque redémarrage) :
```bash
ngrok http 5678 --domain=votre-domaine.ngrok-free.app
```

---

### Étape 6 : Configurer Botpress (l'interface chat)

1. Connectez-vous sur [Botpress Cloud](https://app.botpress.cloud/) et créez un nouveau Bot.
2. Cliquez sur **Edit in Studio**.
3. **Importation :** Cliquez sur le logo Botpress (en haut à gauche) > **Import/Export** > **Import** et sélectionnez le fichier `Wathiqa.bpz`.
4. **Lien Webhook :** Trouvez le nœud "Execute Code" dans le flow et remplacez l'URL par votre URL ngrok + `/webhook/adminbot`.
   - Exemple : si ngrok vous a donné `https://a1b2-c3d4.ngrok-free.app`, l'URL complète sera :
   ```
   https://a1b2-c3d4.ngrok-free.app/webhook/adminbot
   ```
5. Cliquez sur **Publish** (en haut à droite).

### Étape 7 : Tester

1. Ouvrez l'émulateur Botpress (Ctrl+E dans le Studio).
2. Choisissez une catégorie puis une démarche.
3. Vérifiez que la réponse s'affiche correctement avec le résumé en darija.

---

## 💻 Code du Projet

### Script d'indexation — `load.py`

Ce script lit les 57 fichiers `.txt`, les transforme en vecteurs via Mistral et les stocke dans Qdrant :

```python
import requests
import time
import os
from retry import retry

MISTRAL_KEY = os.getenv("MISTRAL_KEY") or os.getenv("MISTRAL_API_KEY")
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
DOCS_DIR = "documents"

def load_real_documents():
    documents_found = []
    files = [f for f in os.listdir(DOCS_DIR) if f.endswith(".txt")]
    for filename in files:
        filepath = os.path.join(DOCS_DIR, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read().strip()
            if content:
                documents_found.append({
                    "type": filename.replace(".txt", ""),
                    "content": content
                })
    return documents_found

docs = load_real_documents()

# Création automatique de la collection AdminBot
requests.put(f"{QDRANT_URL}/collections/AdminBot",
    json={"vectors": {"size": 1024, "distance": "Cosine"}})

for i, doc in enumerate(docs):
    # 1. Génération de l'embedding via Mistral
    resp = requests.post("https://api.mistral.ai/v1/embeddings",
        headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
        json={"model": "mistral-embed", "input": [doc["content"]]})
    emb = resp.json()["data"][0]["embedding"]

    # 2. Injection dans Qdrant
    requests.put(f"{QDRANT_URL}/collections/AdminBot/points",
        json={"points": [{"id": i+1, "vector": emb,
            "payload": {"content": doc["content"], "type": doc["type"]}}]})

    time.sleep(1.2)  # Respect du rate limit Mistral
```

### Code Botpress — Nœud Réponse (Execute Code)

Ce code JavaScript dans Botpress envoie la question de l'utilisateur à n8n via ngrok :

```javascript
const question = workflow.userQuestion || event.preview

try {
  const response = await axios.post(
    'https://VOTRE_URL_NGROK/webhook/adminbot',
    { question: question },
    {
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      },
      timeout: 30000
    }
  )
  workflow.answer = response.data.answer || '⚠️ Aucune réponse trouvée.'
} catch (err) {
  if (err.code === 'ECONNABORTED') {
    workflow.answer = '⏳ Le serveur met trop de temps. Réessayez.'
  } else if (err.response && err.response.status === 404) {
    workflow.answer = '🔍 Service indisponible. Réessayez dans quelques minutes.'
  } else {
    workflow.answer = '❌ Erreur. Contactez Allo Administration : 3737'
  }
}
```

### Workflow n8n — Pipeline RAG (8 nœuds)

```
Webhook (POST /webhook/adminbot)
    │
    ▼
Code in JavaScript (extraction de la question)
    │
    ▼
Mistral Embed (génération de l'embedding)
    │
    ▼
Qdrant Body (préparation de la requête vectorielle)
    │
    ▼
Qdrant Search (recherche des 3 documents les plus proches)
    │
    ▼
Build Prompt (construction du prompt + règle bilingue FR/darija)
    │
    ▼
Mistral Completion (génération de la réponse)
    │
    ▼
Réponse Finale + Respond to Webhook (retour JSON)
```

---

## 🧪 Prompt Engineering

### Prompt système (Build Prompt)

Ce prompt est envoyé comme message `system` à l'API Mistral :

```
Tu es Wathiqa, assistant expert des démarches administratives marocaines.
Sois précis et clair. Réponds d'abord en français, puis ajoute un résumé
en darija marocaine en dessous sous le titre "🇲🇦 بالدارجة :"

RÈGLES :
1. Si des documents sont fournis, base ta réponse UNIQUEMENT dessus.
2. Si aucun document n'est fourni ou s'ils ne contiennent pas la réponse,
   tu peux répondre avec tes connaissances générales MAIS ajoute à la fin :
   "⚠️ Cette information ne provient pas de ma base de données officielle.
   Je vous recommande de vérifier auprès de l'administration concernée
   ou d'appeler le 3737."
3. Ne fabrique jamais de faux documents ou procédures.

Format de réponse (utilise uniquement les sections pertinentes) :
📋 DOCUMENTS NÉCESSAIRES : ...
📍 OÙ ALLER : ...
⏱️ DÉLAI : ...
💰 COÛT : ...
💡 CONSEIL : ...
```

### Prompt de recherche Qdrant

```json
{
  "vector": "[embedding de la question]",
  "limit": 3,
  "with_payload": true,
  "score_threshold": 0.20
}
```

- `limit: 3` : retourne les 3 documents les plus pertinents
- `score_threshold: 0.20` : filtre les documents avec un score de similarité trop faible
- Le score utilise la distance cosinus (Cosine Similarity)

---

## ⚠️ Difficultés Rencontrées & Solutions

### 1. Connexion Botpress Cloud → n8n local
**Problème** : Botpress Cloud ne peut pas accéder à `localhost:5678` où tourne n8n.
**Solution** : Utilisation de ngrok pour créer un tunnel HTTPS public vers n8n local. Ajout du header `ngrok-skip-browser-warning: true` pour éviter la page d'avertissement de ngrok.

### 2. Erreur 404 sur le webhook
**Problème** : Chaque redémarrage de ngrok génère une nouvelle URL, rendant l'ancienne invalide.
**Solution** : Configuration d'un domaine ngrok fixe gratuit via `ngrok http 5678 --domain=mon-domaine.ngrok-free.app`.

### 3. Format .bpz non modifiable
**Problème** : Impossible de créer ou modifier un fichier `.bpz` manuellement — c'est un format propriétaire de Botpress.
**Solution** : Construction du flow directement dans Botpress Studio, puis export en `.bpz` pour le partage.

### 4. Gestion de la question libre
**Problème** : Le nœud passait directement au webhook sans attendre la saisie de l'utilisateur.
**Solution** : Utilisation du composant "Raw Input" de Botpress pour forcer l'attente de la saisie utilisateur avant l'envoi au webhook.

### 5. Hallucination du modèle
**Problème** : Quand aucun document pertinent n'est trouvé dans Qdrant, Mistral inventait des informations.
**Solution** : Modification du prompt système pour autoriser les réponses générales mais avec un avertissement explicite.

### 6. Support bilingue français / darija
**Problème** : Les réponses étaient uniquement en français.
**Solution** : Modification du prompt système pour demander à Mistral de répondre d'abord en français puis d'ajouter un résumé en darija marocaine sous le titre "🇲🇦 بالدارجة :".

---

## 🛠️ Technologies Utilisées

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| Frontend | Botpress Cloud | Interface conversationnelle bilingue |
| Backend | n8n | Orchestration du workflow RAG |
| Embedding | Mistral Embed | Vectorisation des documents et questions |
| Base vectorielle | Qdrant | Stockage et recherche sémantique |
| LLM | Mistral Small | Génération des réponses bilingues |
| Tunnel | ngrok | Exposition du serveur local |
| Conteneurisation | Docker | Infrastructure Qdrant |
| Langage | Python, JavaScript | Scripts de chargement et logique |

---

## 👥 Équipe Projet

Projet réalisé dans le cadre du module d'Intelligence Artificielle.

- **Samah AZIZ** (Architecture & Logique RAG)
- **Keltoum AGAZZARA** (Stratégie Documentaire & UI Design)

**Licence Ingénierie Informatique (LST 2I) — FST Mohammedia**
**Université Hassan II de Casablanca — 2026**

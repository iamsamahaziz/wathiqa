# 🇲🇦 Wathiqa (وثيقة) — Chatbot des Démarches Administratives Marocaines

## 📌 Problème Résolu

Les citoyens marocains font face à un problème récurrent : **trouver les bonnes informations sur les démarches administratives**. Chaque procédure (CNIE, passeport, carte grise, visa, etc.) nécessite des documents spécifiques, implique des frais différents, et se fait dans des lieux précis. Ces informations sont dispersées sur plusieurs sites web, souvent incomplètes ou obsolètes.

**Wathiqa** résout ce problème en centralisant **57 démarches administratives** dans un chatbot intelligent bilingue (français / darija) qui répond instantanément aux questions des citoyens avec des informations précises et structurées, accompagnées d'un résumé en darija marocaine.

### Ce que Wathiqa apporte :
- Réponses instantanées sur les documents nécessaires, lieux, délais et coûts
- Couverture de 10 domaines administratifs (état civil, identité, voyage, véhicule, emploi, CNSS/santé, famille, logement, finances, aide sociale)
- Interface bilingue français / darija marocaine
- Chaque réponse inclut un résumé en darija (🇲🇦 بالدارجة)
- Interface conversationnelle accessible à tous, sans connaissances techniques
- Informations basées sur une base de données vérifiée (RAG)

---

## 🏗️ Architecture de la Solution

Le projet repose sur **3 composants principaux** :

### 1. Frontend — Botpress Cloud
- Interface de chat déployée sur Botpress Cloud
- Flow conversationnel avec 10 catégories bilingues (FR/AR) et sous-catégories
- Option de question libre pour les demandes hors menu
- Gestion des erreurs et message de fin personnalisé bilingue

### 2. Backend — n8n (Workflow Automation)
- Workflow de 8 nœuds hébergé localement
- Exposé via ngrok pour la communication avec Botpress Cloud
- Orchestre le pipeline RAG complet

### 3. Pipeline RAG (Retrieval-Augmented Generation)
- **Embedding** : Mistral Embed (modèle `mistral-embed`)
- **Base vectorielle** : Qdrant (collection `AdminBot`, 57 documents)
- **Génération** : Mistral Small (`mistral-small-latest`, temperature 0.1)

### Schéma d'architecture

```
┌──────────────────────────────────────────────────────────┐
│                    UTILISATEUR                            │
│              (Web / Mobile / WhatsApp)                    │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│                  BOTPRESS CLOUD                           │
│                                                           │
│  ┌─────────┐   ┌──────────────┐   ┌─────────────────┐   │
│  │ Accueil  │──▸│ 10 Catégories│──▸│  Sous-catégories│   │
│  │ Wathiqa  │   │  (FR / AR)   │   │  (57 démarches) │   │
│  └─────────┘   └──────────────┘   └────────┬────────┘   │
│                                             │             │
│                    ┌────────────────────────┐│             │
│                    │  Question libre        ││             │
│                    │  (Raw Input)           │┘             │
│                    └────────┬───────────────┘              │
│                             │                              │
│                   POST /webhook/adminbot                   │
└─────────────────────────────┬────────────────────────────┘
                              │ (via ngrok)
                              ▼
┌──────────────────────────────────────────────────────────┐
│                    N8N WORKFLOW                            │
│                                                           │
│  Webhook ──▸ Extract Question ──▸ Mistral Embed           │
│                                       │                   │
│                                       ▼                   │
│                                 Qdrant Search             │
│                                 (top 3, score > 0.20)     │
│                                       │                   │
│                                       ▼                   │
│                                 Build Prompt              │
│                                 (système + contexte)      │
│                                       │                   │
│                                       ▼                   │
│                                 Mistral Completion        │
│                                 (mistral-small-latest)    │
│                                       │                   │
│                                       ▼                   │
│                                 Réponse JSON              │
│                                 { answer: "..." }         │
└──────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────┐
│                      QDRANT                               │
│           Base vectorielle (57 documents)                  │
│                                                           │
│  État civil (7) │ Identité (4) │ Voyage (5)               │
│  Véhicule (6)   │ Emploi (6)   │ CNSS/Santé (7)          │
│  Famille (6)    │ Logement (7) │ Finances (6)             │
│  Aide sociale/MRE (3)                                     │
└──────────────────────────────────────────────────────────┘
```

---

## 📖 Guide d'Utilisation

### Prérequis

- **Docker** (pour Qdrant et n8n)
- **Python 3.8+** (pour le chargement des documents)
- **Node.js** (pour n8n si utilisé sans Docker)
- **ngrok** (pour exposer n8n à Botpress Cloud)
- **Compte Botpress Cloud** (gratuit)
- **Clé API Mistral AI**

### Installation étape par étape

#### 1. Lancer Qdrant

```bash
docker run -p 6333:6333 qdrant/qdrant
```

Créer la collection :

```bash
curl -X PUT http://localhost:6333/collections/AdminBot \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 1024,
      "distance": "Cosine"
    }
  }'
```

#### 2. Charger les documents dans Qdrant

Placez tous les fichiers `.txt` des démarches dans le même dossier que `load.py`, puis :

```bash
pip install requests
python load.py
```

Ce script charge les 57 documents en les transformant en embeddings via Mistral et en les stockant dans Qdrant.

#### 3. Lancer n8n

```bash
# Avec Docker
docker run -p 5678:5678 n8nio/n8n

# Ou avec npm
npx n8n
```

Importer le workflow `Wathiqa.json` dans n8n via le menu Import.

#### 4. Exposer n8n avec ngrok

```bash
ngrok http 5678
```

Copier l'URL publique (ex: `https://xxxx.ngrok-free.app`).

Pour un domaine fixe gratuit :

```bash
ngrok http 5678 --domain=votre-domaine.ngrok-free.app
```

#### 5. Configurer Botpress

- Importer le fichier `Wathiqa.bpz` dans Botpress Studio (Import/Export)
- Mettre à jour l'URL ngrok dans le nœud "Réponse" (Execute Code)
- Publier le bot

#### 6. Tester

- Ouvrir l'émulateur Botpress (Ctrl+E)
- Choisir une catégorie puis une démarche
- Vérifier que la réponse s'affiche correctement avec le résumé en darija

---

## 💻 Code du Projet

### Structure des fichiers

```
Wathiqa/
├── load.py                  # Script de chargement des documents dans Qdrant
├── Wathiqa.json             # Workflow n8n (importable)
├── Wathiqa.bpz              # Bot Botpress (importable)
├── README.md                # Ce fichier
└── documents/               # 57 fichiers .txt des démarches
    ├── CIN.txt
    ├── passeport.txt
    ├── Carte grise.txt
    ├── Mariage.txt
    └── ... (57 fichiers)
```

### Code principal — load.py (Chargement RAG)

```python
import requests
import os
import time

MISTRAL_KEY = "VOTRE_CLE_MISTRAL"

docs = [
    # === État Civil ===
    {"file": "Acte de naissance.txt",              "type": "Acte de naissance"},
    {"file": "acte_deces.txt",                     "type": "Acte de décès"},
    {"file": "Livret de famille.txt",              "type": "Livret de famille"},
    {"file": "Mariage.txt",                        "type": "Mariage"},
    {"file": "Casier judiciaire.txt",              "type": "Casier judiciaire"},
    {"file": "Certificat de résidence .txt",       "type": "Certificat de résidence"},
    {"file": "attestation_vie.txt",                "type": "Attestation de vie"},

    # === Identité ===
    {"file": "CIN.txt",                            "type": "CNIE"},
    {"file": "Legalisation de signature.txt",      "type": "Légalisation de signature"},
    {"file": "procuration.txt",                    "type": "Procuration"},
    {"file": "Apostille.txt",                      "type": "Apostille"},

    # === Voyage ===
    {"file": "passeport.txt",                      "type": "Passeport"},
    {"file": "Renouvellement passeport.txt",       "type": "Renouvellement passeport"},
    {"file": "Visa Schengen.txt",                  "type": "Visa Schengen"},
    {"file": "Visa americain.txt",                 "type": "Visa américain"},
    {"file": "Visa France.txt",                    "type": "Visa France"},

    # === Véhicule ===
    {"file": "Carte grise.txt",                    "type": "Carte grise"},
    {"file": "permis.txt",                         "type": "Permis de conduire"},
    {"file": "Permis de conduire international.txt","type": "Permis international"},
    {"file": "Vignette automobile.txt",            "type": "Vignette automobile"},
    {"file": "assurance_voiture.txt",              "type": "Assurance automobile"},
    {"file": "Echange permis etranger.txt",        "type": "Échange permis étranger"},

    # === Emploi ===
    {"file": "Auto-entrepreneur.txt",              "type": "Auto-entrepreneur"},
    {"file": "contrat_travail.txt",                "type": "Contrat de travail"},
    {"file": "inscription_anapec.txt",             "type": "Inscription ANAPEC"},
    {"file": "Conge maternite.txt",                "type": "Congé maternité"},
    {"file": "Accident du travail.txt",            "type": "Accident du travail"},
    {"file": "attestation_hebergement.txt",        "type": "Attestation d'hébergement"},

    # === CNSS / Santé ===
    {"file": "amo_cnss.txt",                       "type": "AMO CNSS"},
    {"file": "cnops.txt",                          "type": "CNOPS"},
    {"file": "Allocations familiales CNSS.txt",    "type": "Allocations familiales CNSS"},
    {"file": "Pension invalidite CNSS.txt",        "type": "Pension invalidité CNSS"},
    {"file": "Allocation au deces.txt",            "type": "Allocation au décès"},
    {"file": "Retraite.txt",                       "type": "Retraite"},
    {"file": "Indemnite perte emploi IPE.txt",     "type": "Indemnité perte d'emploi"},

    # === Famille ===
    {"file": "Divorce.txt",                        "type": "Divorce"},
    {"file": "Succession et heritage.txt",         "type": "Succession et héritage"},
    {"file": "Kafala (adoption).txt",              "type": "Kafala (adoption)"},
    {"file": "Regroupement familial.txt",          "type": "Regroupement familial"},
    {"file": "Nationalite marocaine.txt",          "type": "Nationalité marocaine"},
    {"file": "Double nationalite.txt",             "type": "Double nationalité"},

    # === Logement ===
    {"file": "logement_social.txt",                "type": "Logement social"},
    {"file": "Aide au logement Daam Sakane.txt",   "type": "Aide Daam Sakane"},
    {"file": "permis_construire.txt",              "type": "Permis de construire"},
    {"file": "Permis d_habiter.txt",               "type": "Permis d'habiter"},
    {"file": "certificat_propriete.txt",           "type": "Certificat de propriété"},
    {"file": "raccordement_eau_electricite.txt",   "type": "Raccordement eau/électricité"},
    {"file": "Titre de sejour.txt",                "type": "Titre de séjour"},

    # === Finances ===
    {"file": "Compte bancaire.txt",                "type": "Compte bancaire"},
    {"file": "Taxe profit immobilier.txt",         "type": "Taxe profit immobilier"},
    {"file": "Impots locatifs.txt",                "type": "Impôts locatifs"},
    {"file": "Impots Maroc.txt",                   "type": "Impôts (IR, IS, TVA)"},
    {"file": "Attestation non-imposition.txt",     "type": "Attestation non-imposition"},
    {"file": "Registre de Commerce.txt",           "type": "Registre de Commerce"},

    # === Aide Sociale / Études / MRE ===
    {"file": "RSU et RNP.txt",                     "type": "RSU et RNP"},
    {"file": "Bourse Minhaty.txt",                 "type": "Bourse Minhaty"},
    {"file": "Demarches MRE.txt",                  "type": "Démarches MRE"},
]

for i, doc in enumerate(docs):
    if not os.path.exists(doc["file"]):
        print(f"⚠️ Fichier manquant : {doc['file']}")
        continue

    content = open(doc["file"], encoding="utf-8").read()
    print(f"📄 Chargement : {doc['type']}...")

    resp = requests.post(
        "https://api.mistral.ai/v1/embeddings",
        headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
        json={"model": "mistral-embed", "input": [content]}
    )

    if resp.status_code != 200:
        print(f"❌ Erreur Mistral : {resp.text}")
        continue

    emb = resp.json()["data"][0]["embedding"]

    requests.put(
        "http://localhost:6333/collections/AdminBot/points",
        json={"points": [{
            "id": i + 1,
            "vector": emb,
            "payload": {"content": content, "type": doc["type"]}
        }]}
    )
    print(f"✅ {doc['type']} chargé !")
    time.sleep(0.5)

print("🎉 Tous les documents sont dans Qdrant !")
```

### Code Botpress — Nœud Réponse (Execute Code)

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
    workflow.answer = '🔧 Service indisponible. Réessayez dans quelques minutes.'
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

### Prompt système (Build Prompt)

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

---

## 🧩 Prompts Utilisés

### Prompt système pour Mistral (dans n8n)

Le prompt ci-dessus est utilisé dans le nœud "Build Prompt" du workflow n8n. Il est envoyé comme message `system` à l'API Mistral avec les documents RAG en contexte et la question de l'utilisateur. Il demande à Mistral de répondre en français puis d'ajouter un résumé en darija marocaine.

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

### Prompt d'embedding

```json
{
  "model": "mistral-embed",
  "input": ["question de l'utilisateur"]
}
```

---

## 🌍 Interface Bilingue (Français / Darija)

### Message d'accueil

```
🇲🇦 Bonjour ! Merhba ! Je suis Wathiqa
مرحبا! أنا وثيقة، مساعدك في الإجراءات الإدارية بالمغرب

Choisissez une catégorie / ختار واحد القسم :
```

### Catégories bilingues

| Français | العربية / الدارجة |
|----------|-------------------|
| 📋 État civil | الحالة المدنية |
| 🪪 Identité | الهوية |
| ✈️ Voyage et visa | السفر والفيزا |
| 🚗 Véhicule | السيارة |
| 💼 Emploi | الخدمة |
| 🏥 CNSS et santé | الصندوق والصحة |
| 👨‍👩‍👧 Famille | العائلة |
| 🏠 Logement | السكن |
| 💰 Finances et impôts | المالية والضرائب |
| 🎓 Aide sociale et études | المساعدة والدراسة |
| ❓ Question libre | سؤال حر |

### Sous-catégories bilingues (exemples)

**✈️ Voyage / السفر :**
- Passeport / جواز السفر
- Renouvellement passeport / تجديد جواز السفر
- Visa Schengen / فيزا شنغن
- Visa américain / فيزا أمريكا
- Visa France / فيزا فرنسا

**🚗 Véhicule / السيارة :**
- Carte grise / لاكارط گريز
- Permis de conduire / رخصة السياقة
- Permis international / رخصة السياقة الدولية
- Vignette automobile / لافينييت
- Assurance automobile / التأمين ديال الطوموبيل
- Échange permis étranger / تبديل البيرمي الأجنبي

### Message de fin bilingue

```
✅ Merci d'avoir utilisé Wathiqa ! 🇲🇦
شكرا على استعمال وثيقة !

Nous espérons avoir pu vous aider dans vos démarches.
كنتمناو نكونو عاونّاكم في الإجراءات ديالكم.

📞 Contacts utiles / أرقام مهمة :
• Allo Administration : 3737
• 🌐 www.idarati.ma (بوابة الإجراءات الإدارية)
• CNIE / Passeport : www.cnie.ma
• CNSS : www.cnss.ma
• Impôts / الضرائب : www.tax.gov.ma
• MRE / مغاربة العالم : www.consulat.ma

💡 N'hésitez pas à revenir / مرحبا بيكم أي وقت !

Bonne journée / نهاركم مبروك 👋
```

---

## ⚠️ Difficultés Rencontrées

### 1. Connexion Botpress Cloud ↔ n8n local
**Problème** : Botpress Cloud ne peut pas accéder à `localhost:5678` où tourne n8n.
**Solution** : Utilisation de ngrok pour créer un tunnel HTTPS public vers n8n local. Ajout du header `ngrok-skip-browser-warning: true` pour éviter la page d'avertissement de ngrok.

### 2. Erreur 404 sur le webhook
**Problème** : Chaque redémarrage de ngrok génère une nouvelle URL, rendant l'ancienne invalide (erreur 404).
**Solution** : Configuration d'un domaine ngrok fixe gratuit via `ngrok http 5678 --domain=mon-domaine.ngrok-free.app`. Mise en place de messages d'erreur explicites dans Botpress au lieu d'afficher l'erreur technique brute.

### 3. Format .bpz non modifiable
**Problème** : Impossible de créer ou modifier un fichier `.bpz` manuellement — c'est un format propriétaire de Botpress Cloud.
**Solution** : Construction du flow directement dans Botpress Studio, puis export en `.bpz` pour le partage.

### 4. Gestion de la question libre
**Problème** : Le nœud passait directement au webhook sans attendre la saisie de l'utilisateur, envoyant le texte du message précédent au lieu de la question.
**Solution** : Utilisation du composant "Raw Input" de Botpress pour forcer l'attente de la saisie utilisateur avant l'envoi au webhook.

### 5. Hallucination du modèle
**Problème** : Quand aucun document pertinent n'est trouvé dans Qdrant, Mistral inventait des informations.
**Solution** : Modification du prompt système pour autoriser les réponses générales mais avec un avertissement explicite indiquant que l'information ne provient pas de la base de données officielle.

### 6. Intelligence de routage Botpress
**Découverte** : Botpress Cloud intègre une IA qui analyse automatiquement les messages des utilisateurs et les redirige vers la bonne catégorie, même si l'utilisateur tape une question libre au lieu de choisir dans le menu. Cette fonctionnalité a rendu inutile l'implémentation manuelle d'un système de détection de questions.

### 7. Support bilingue français / darija
**Problème** : Les réponses étaient uniquement en français, ce qui limitait l'accessibilité pour les utilisateurs darija-phones.
**Solution** : Modification du prompt système pour demander à Mistral de répondre d'abord en français puis d'ajouter un résumé en darija marocaine sous le titre "🇲🇦 بالدارجة :". L'interface Botpress a également été rendue bilingue (catégories, sous-catégories, messages d'accueil et de fin).

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
| Langage | Python, JavaScript | Scripts de chargement et logique |

---

## 📞 Contacts Utiles (intégrés dans le bot)

- Allo Administration : **3737**
- Portail Idarati / بوابة إداراتي : **www.idarati.ma**
- CNIE / Passeport : **www.cnie.ma**
- CNSS : **www.cnss.ma**
- Impôts / الضرائب : **www.tax.gov.ma**
- MRE / مغاربة العالم : **www.consulat.ma**

---

## 👩‍💻 Auteur

Projet réalisé dans le cadre du module d'Intelligence Artificielle.

**Réalisé par** : Samah AZIZ & Keltoum AGAZZARA
**Date** : Avril 2026

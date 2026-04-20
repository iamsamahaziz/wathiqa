# 🇲🇦 Wathiqa (وثيقة) — Le Guide Technique Ultime (Masterclass RAG)

> **"L'accès à l'information administrative est un droit, Wathiqa en fait une conversation."**

Wathiqa est un écosystème conçu pour centraliser et simplifier **57 démarches administratives marocaines**. Ce projet n'est pas une simple interface de chat, mais une architecture complexe de **Retrieval-Augmented Generation (RAG)** bilingue, orchestrée localement pour garantir souveraineté et flexibilité.

---

## 🏛️ 1. La Mission : Résoudre la Complexité Administrative
Au Maroc, trouver des informations fiables sur une CNIE, un passeport ou un permis de construire nécessite souvent de naviguer sur de multiples sites web ou de se déplacer. **Wathiqa** résout ce problème en offrant :
- **Centralisation** : 10 domaines administratifs couverts.
- **Accessibilité** : Réponses en Français et résumé en **Darija** marocaine.
- **Précision** : Informations basées sur une base de données vectorielle vérifiée.

---

## 🏗️ 2. Architecture Technique : Les 5 Piliers
Le projet repose sur 5 briques technologiques qui communiquent en temps réel :

### 2.1. Botpress Cloud (L'Interface conversationnelle)
Le "Front-end" du projet. Il gère le flux de conversation (menus, catégories) et l'IA native qui redirige l'utilisateur.
- **Rôle** : Capturer la question et l'envoyer au backend via un webhook.
- **Scripting** : Utilise des nœuds "Execute Code" en JavaScript pour communiquer avec n8n.

### 2.2. n8n (L'Orchestrateur Vital)
C'est le "Cœur" du système. Au lieu de coder un serveur complexe, nous utilisons n8n pour orchestrer le pipeline RAG.
- **Complexité** : Un workflow de 8 nœuds gérant l'extraction, la vectorisation, la recherche et la génération.
- **Avantage** : Permet une modification rapide des prompts et une surveillance visuelle des erreurs en temps réel.

### 2.3. ngrok (Le Pont de Communication)
Une pièce critique du puzzle. Botpress Cloud ne peut pas "voir" votre serveur n8n local.
- **Pourquoi ngrok ?** : Il crée un tunnel sécurisé (HTTPS) qui expose votre port local `5678` sur le web.
- **Fonctionnalité** : Sans lui, les messages resteraient bloqués dans le Cloud sans jamais atteindre votre machine.

### 2.4. Qdrant (La Mémoire Sémantique)
Base de données vectorielle ultra-rapide.
- **Concept** : Contrairement à une base SQL classique, Qdrant stocke des "vecteurs" (nombres) qui représentent le sens des mots.
- **Collection** : `AdminBot` (contient les 57 documents indexés).

### 2.5. Mistral AI (L'Intelligence Artificielle)
Nous utilisons une stratégie à deux modèles :
- **mistral-embed** : Pour transformer les textes en vecteurs de dimension 1024.
- **mistral-small-latest** : Pour lire les documents trouvés et rédiger la réponse bilingue finale.

---

## 🚀 3. Installation Manuelle (Étape par Étape)

### Étape 1 : Infrastructure Docker
Qdrant doit tourner en permanence pour servir les données :
```bash
docker run -d -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

### Étape 2 : Environnement Python & Indexation
Préparez le script qui va lire vos 57 fichiers `.txt` :
```bash
python -m venv venv
source venv/bin/activate  # venv\Scripts\activate sur Windows
pip install -r requirements.txt
set MISTRAL_KEY=votre_cle_api  # Configurez votre secret
python load.py  # Lance l'indexation dans Qdrant
```

### Étape 3 : Tunneling avec ngrok
Indispensable pour la communication Cloud-Local :
```bash
ngrok http 5678 --domain=votre-domaine.ngrok-free.app (optionnel)
```
> [!IMPORTANT]
> Notez bien l'URL générée, elle devra être copiée dans Botpress.

### Étape 4 : Configuration n8n
1. Lancez n8n : `npx n8n`.
2. Importez `Wathiqa.json`.
3. Configurez les **Credentials** pour Mistral AI et l'URL de Qdrant (`http://localhost:6333`).

---

## 🇲🇦 4. La Méthode Bilingue : Prompt Engineering
Le secret de la réponse bilingue réside dans le **System Prompt** injecté dans Mistral via n8n :

```text
Tu es Wathiqa, assistant expert des démarches administratives marocaines.
RÈGLE D'OR : Réponds d'abord en Français (précis et formel).
Ensuite, fournis un résumé en DARIJA marocaine sous le titre "🇲🇦 بالدارجة :".
Si tu ne trouves pas la réponse dans les documents, précise-le clairement.
```

---

## ⚠️ 5. Difficultés Rencontrées & Solutions (Log Technique)

Durant le développement, plusieurs défis majeurs ont été surmontés :

1. **Connexion Cloud-Local** : Botpress ne pouvait pas accéder à `localhost`.
   - *Solution* : Intégration de ngrok avec le header `ngrok-skip-browser-warning: true`.
2. **Hallucinations du Modèle** : Mistral inventait parfois des procédures inexistantes.
   - *Solution* : Verrouillage du prompt pour forcer l'utilisation stricte du contexte RAG.
3. **Timeouts Webhook** : Qdrant ou Mistral mettaient parfois trop de temps à répondre (> 30s).
   - *Solution* : Optimisation de la recherche (top 3 documents max) et augmentation du timeout dans les scripts Botpress.
4. **Format Propriétaire** : Le fichier `.bpz` de Botpress ne pouvait pas être édité manuellement.
   - *Solution* : Workflow strict d'Import/Export via Botpress Studio.

---

## 📄 6. Structure des Fichiers Clés
- `load.py` : Script d'indexation (Lit `documents/` -> Mistral Embed -> Qdrant).
- `Wathiqa.json` : Workflow n8n (Le pipeline RAG complet).
- `Wathiqa.bpz` : Export du bot (Intelligence conversationnelle + UI).
- `documents/` : Knowledge base (57 fichiers texte officiels).

---

## 👥 Équipe Projet
- **Samah AZIZ** (Concept Architecture & MLOps)
- **Keltoum AGAZZARA** (Data Strategy & UI)

**Master IA - 2026**

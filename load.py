import requests
import time
import os
from retry import retry

# 🔐 clé depuis variable d'environnement (MISTRAL_KEY ou MISTRAL_API_KEY)
MISTRAL_KEY = os.getenv("MISTRAL_KEY") or os.getenv("MISTRAL_API_KEY")

# ✅ IMPORTANT : accessible depuis Jenkins Docker
QDRANT_URL = os.getenv("QDRANT_URL", "http://host.docker.internal:6333")

DOCS_DIR = "documents"

def load_real_documents():
    """
    📂 Parcourt le dossier documents/ et lit tous les fichiers .txt
    """
    documents_found = []
    if not os.path.exists(DOCS_DIR):
        print(f"❌ Erreur : Le dossier {DOCS_DIR} n'existe pas.")
        return []
    
    files = [f for f in os.listdir(DOCS_DIR) if f.endswith(".txt")]
    
    for filename in files:
        filepath = os.path.join(DOCS_DIR, filename)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content:
                    documents_found.append({
                        "type": filename.replace(".txt", ""),
                        "content": content
                    })
        except Exception as e:
            print(f"⚠️ Impossible de lire {filename}: {e}")
            
    return documents_found

# 1. Charger les vrais fichiers
docs = load_real_documents()
print(f"📚 {len(docs)} documents chargés depuis le dossier {DOCS_DIR}")

# 2. Boucle de traitement et d'indexation
for i, doc in enumerate(docs):

    print(f"📄 Traitement ({i+1}/{len(docs)}) : {doc['type']}...")

    @retry(tries=3, delay=2, backoff=2)
    def call_mistral(text):
        # 🤖 Embeddings Mistral
        resp = requests.post(
            "https://api.mistral.ai/v1/embeddings",
            headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
            json={"model": "mistral-embed", "input": [text]}
        )
        if resp.status_code == 429:
            raise Exception("Rate limit exceeded")
        return resp

    try:
        resp = call_mistral(doc["content"])
    except Exception as e:
        print(f"❌ Erreur Mistral sur {doc['type']} après plusieurs essais : {e}")
        continue

    if resp.status_code != 200:
        print(f"❌ Erreur Mistral sur {doc['type']} : {resp.text}")
        continue

    emb = resp.json()["data"][0]["embedding"]

    # 📦 Envoi vers Qdrant
    try:
        qdrant_resp = requests.put(
            f"{QDRANT_URL}/collections/AdminBot/points",
            json={
                "points": [{
                    "id": i + 1,
                    "vector": emb,
                    "payload": {
                        "content": doc["content"],
                        "type": doc["type"]
                    }
                }]
            }
        )

        if qdrant_resp.status_code not in [200, 201]:
            print(f"❌ Qdrant error: {qdrant_resp.text}")
            continue

        print(f"✅ {doc['type']} indexé dans Qdrant !")

    except Exception as e:
        print(f"❌ Erreur connexion Qdrant: {e}")

    # Pause pour éviter de saturer l'API (Rate Limit)
    time.sleep(1.2)

print("🎉 Pipeline d'indexation réelle terminé avec succès !")

import requests
import time
import os
from retry import retry

# 🔐 clé depuis variable d'environnement
MISTRAL_KEY = os.getenv("MISTRAL_KEY") or os.getenv("MISTRAL_API_KEY")

# 🌐 Qdrant (accessible depuis Jenkins Docker)
QDRANT_URL = os.getenv("QDRANT_URL", "http://host.docker.internal:6333")

DOCS_DIR = "documents"


# =========================
# 🔐 HEALTH CHECK MISTRAL
# =========================
def check_mistral_key():
    if not MISTRAL_KEY:
        raise ValueError("❌ MISTRAL_KEY est manquante dans les variables d'environnement")

    print("🔐 Vérification de la clé Mistral...")

    resp = requests.get(
        "https://api.mistral.ai/v1/models",
        headers={"Authorization": f"Bearer {MISTRAL_KEY}"}
    )

    if resp.status_code == 401:
        raise ValueError("❌ Clé Mistral invalide (401 Unauthorized)")

    if resp.status_code != 200:
        raise ValueError(f"❌ Erreur API Mistral: {resp.text}")

    print("✅ Clé Mistral valide")


# =========================
# 📂 LOAD DOCUMENTS
# =========================
def load_real_documents():
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


# =========================
# 🧠 QDRANT COLLECTION
# =========================
def ensure_collection():
    print(f"📡 Vérification de la collection 'AdminBot' sur {QDRANT_URL}...")

    try:
        check_resp = requests.get(f"{QDRANT_URL}/collections/AdminBot")

        if check_resp.status_code == 404:
            print("📦 Création de la collection 'AdminBot'...")

            create_resp = requests.put(
                f"{QDRANT_URL}/collections/AdminBot",
                json={
                    "vectors": {
                        "size": 1024,
                        "distance": "Cosine"
                    }
                }
            )

            if create_resp.status_code in [200, 201]:
                print("✅ Collection créée")
            else:
                print(f"❌ Erreur création: {create_resp.text}")

        else:
            print("✅ Collection déjà existante")

    except Exception as e:
        print(f"⚠️ Erreur Qdrant: {e}")


# =========================
# 🚀 START PIPELINE
# =========================

# 🔐 IMPORTANT : health check AVANT tout
check_mistral_key()

# 📂 load docs
docs = load_real_documents()
print(f"📚 {len(docs)} documents chargés")

# 🧠 Qdrant setup
ensure_collection()


# =========================
# 🔁 EMBEDDING LOOP
# =========================
for i, doc in enumerate(docs):

    print(f"📄 Traitement ({i+1}/{len(docs)}) : {doc['type']}")

    @retry(tries=3, delay=2, backoff=2)
    def call_mistral(text):
        resp = requests.post(
            "https://api.mistral.ai/v1/embeddings",
            headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
            json={
                "model": "mistral-embed",
                "input": [text]
            }
        )

        if resp.status_code == 429:
            raise Exception("Rate limit exceeded")

        return resp

    try:
        resp = call_mistral(doc["content"])
    except Exception as e:
        print(f"❌ Erreur Mistral sur {doc['type']} : {e}")
        continue

    if resp.status_code != 200:
        print(f"❌ Erreur Mistral API: {resp.text}")
        continue

    emb = resp.json()["data"][0]["embedding"]

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

        print(f"✅ {doc['type']} indexé")

    except Exception as e:
        print(f"❌ Erreur Qdrant: {e}")

    time.sleep(1.2)

print("🎉 Pipeline terminé avec succès !")

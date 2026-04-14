import requests
import time
import os
from retry import retry

# 🔐 clé depuis variable d'environnement (MISTRAL_KEY ou MISTRAL_API_KEY)
MISTRAL_KEY = os.getenv("MISTRAL_KEY") or os.getenv("MISTRAL_API_KEY")

# ✅ IMPORTANT : accessible depuis Jenkins Docker (configurable via variable d'environnement)
QDRANT_URL = os.getenv("QDRANT_URL", "http://host.docker.internal:6333")

docs = [
    {"type": "Acte de naissance"},
    {"type": "Acte de décès"},
    {"type": "Livret de famille"},
    {"type": "Mariage"},
    {"type": "Casier judiciaire"},
    {"type": "Certificat de résidence"},
    {"type": "Attestation de vie"},
    {"type": "CNIE"},
    {"type": "Légalisation de signature"},
    {"type": "Procuration"},
    {"type": "Apostille"},
    {"type": "Passeport"},
    {"type": "Visa Schengen"},
    {"type": "Visa américain"},
    {"type": "Carte grise"},
    {"type": "Permis de conduire"},
    {"type": "Assurance automobile"},
    {"type": "Contrat de travail"},
    {"type": "CNSS"},
    {"type": "Divorce"},
    {"type": "Succession"},
    {"type": "Nationalité marocaine"},
    {"type": "Registre de commerce"},
]

def get_document_content(doc_type):
    """
    🔥 Simulation (remplace par scraping/API si besoin)
    """
    return f"Contenu simulé pour {doc_type}"

for i, doc in enumerate(docs):

    print(f"📄 Traitement : {doc['type']}...")

    content = get_document_content(doc["type"])

    if not content:
        print(f"⚠️ Aucun contenu pour {doc['type']}")
        continue

    @retry(tries=3, delay=2, backoff=2)
    def call_mistral():
        # 🤖 Embeddings Mistral
        resp = requests.post(
            "https://api.mistral.ai/v1/embeddings",
            headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
            json={"model": "mistral-embed", "input": [content]}
        )
        if resp.status_code == 429:
            raise Exception("Rate limit exceeded")
        return resp

    try:
        resp = call_mistral()
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
                        "content": content,
                        "type": doc["type"]
                    }
                }]
            }
        )

        if qdrant_resp.status_code not in [200, 201]:
            print(f"❌ Qdrant error: {qdrant_resp.text}")
            continue

        print(f"✅ {doc['type']} chargé !")

    except Exception as e:
        print(f"❌ Erreur connexion Qdrant: {e}")

    time.sleep(1.5)

print("🎉 Pipeline terminé avec succès !")
import requests
import time
import os

# 🔐 clé depuis variable d'environnement (best practice)
MISTRAL_KEY = os.getenv("MISTRAL_KEY")

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
    🔥 ICI tu mets ton scraping réel
    (API, web scraping, DB, etc.)
    """
    return f"Contenu simulé pour {doc_type}"

for i, doc in enumerate(docs):

    print(f"📄 Traitement : {doc['type']}...")

    content = get_document_content(doc["type"])

    if not content:
        print(f"⚠️ Aucun contenu pour {doc['type']}")
        continue

    resp = requests.post(
        "https://api.mistral.ai/v1/embeddings",
        headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
        json={"model": "mistral-embed", "input": [content]}
    )

    if resp.status_code != 200:
        print(f"❌ Erreur Mistral sur {doc['type']} : {resp.text}")
        continue

    emb = resp.json()["data"][0]["embedding"]

    requests.put(
        "http://localhost:6333/collections/AdminBot/points",
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

    print(f"✅ {doc['type']} chargé !")
    time.sleep(0.5)

print("🎉 Pipeline terminé avec succès !")

import os
import time
import requests
from dotenv import load_dotenv

load_dotenv()

MISTRAL_KEY = os.getenv("MISTRAL_API_KEY")
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")

if not MISTRAL_KEY:
    raise ValueError("MISTRAL_API_KEY is missing. Add it to your environment or .env file.")

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
    {"file": "Apostille.txt",                      "type": "Apostille (Légalisation internationale)"},

    # === Voyage ===
    {"file": "passeport.txt",                      "type": "Passeport"},
    {"file": "Renouvellement passeport.txt",       "type": "Renouvellement passeport"},
    {"file": "Visa Schengen.txt",                  "type": "Visa Schengen"},
    {"file": "Visa americain.txt",                 "type": "Visa américain"},
    {"file": "Visa France.txt",                    "type": "Visa France"},

    # === Véhicule ===
    {"file": "Carte grise.txt",                    "type": "Carte grise"},
    {"file": "permis.txt",                         "type": "Permis de conduire"},
    {"file": "Permis de conduire international.txt","type": "Permis de conduire international"},
    {"file": "Vignette automobile.txt",            "type": "Vignette automobile"},
    {"file": "assurance_voiture.txt",              "type": "Assurance automobile"},
    {"file": "Echange permis etranger.txt",       "type": "Échange de permis étranger"},

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
    {"file": "Retraite.txt",                       "type": "Retraite (CNSS, CMR, RCAR)"},
    {"file": "Indemnite perte emploi IPE.txt",     "type": "Indemnité perte d'emploi IPE"},

    # === Famille ===
    {"file": "Divorce.txt",                        "type": "Divorce"},
    {"file": "Succession et heritage.txt",         "type": "Succession et héritage"},
    {"file": "Kafala (adoption).txt",              "type": "Kafala (adoption)"},
    {"file": "Regroupement familial.txt",          "type": "Regroupement familial"},

    # === Nationalité ===
    {"file": "Nationalite marocaine.txt",          "type": "Nationalité marocaine"},
    {"file": "Double nationalite.txt",             "type": "Double nationalité"},

    # === Résidence / Immobilier ===
    {"file": "logement_social.txt",                "type": "Logement social"},
    {"file": "Aide au logement Daam Sakane.txt",   "type": "Aide au logement Daam Sakane"},
    {"file": "permis_construire.txt",              "type": "Permis de construire"},
    {"file": "Permis d_habiter.txt",               "type": "Permis d'habiter"},
    {"file": "certificat_propriete.txt",           "type": "Certificat de propriété"},
    {"file": "raccordement_eau_electricite.txt",   "type": "Raccordement eau et électricité"},
    {"file": "Titre de sejour.txt",                "type": "Titre de séjour"},

    # === Finances ===
    {"file": "Compte bancaire.txt",                "type": "Compte bancaire"},
    {"file": "Taxe profit immobilier.txt",         "type": "Taxe sur profit immobilier"},
    {"file": "Impots locatifs.txt",                "type": "Impôts locatifs"},
    {"file": "Impots Maroc.txt",                   "type": "Impôts (IR, IS, TVA)"},
    {"file": "Attestation non-imposition.txt",      "type": "Attestation de non-imposition"},
    {"file": "Registre de Commerce.txt",           "type": "Registre de Commerce (Modèle 7)"},

    # === Aide Sociale / Études ===
    {"file": "RSU et RNP.txt",                     "type": "RSU et RNP"},
    {"file": "Bourse Minhaty.txt",                 "type": "Bourse Minhaty"},

    # === MRE ===
    {"file": "Demarches MRE.txt",                  "type": "Démarches MRE"},
]

for i, doc in enumerate(docs):
    if not os.path.exists(doc["file"]):
        print(f"⚠️ Fichier manquant : {doc['file']}")
        continue

    content = open(doc["file"], encoding="utf-8").read()
    print(f"📄 Chargement : {doc['type']}...")

    try:
        resp = requests.post(
            "https://api.mistral.ai/v1/embeddings",
            headers={"Authorization": f"Bearer {MISTRAL_KEY}"},
            json={"model": "mistral-embed", "input": [content]},
            timeout=30
        )
    except requests.RequestException as err:
        print(f"❌ Erreur réseau Mistral sur {doc['type']} : {err}")
        continue

    if resp.status_code != 200:
        print(f"❌ Erreur Mistral sur {doc['type']} : {resp.text}")
        continue

    try:
        emb = resp.json()["data"][0]["embedding"]
    except (KeyError, IndexError, TypeError, ValueError) as err:
        print(f"❌ Réponse Mistral invalide pour {doc['type']} : {err}")
        continue

    try:
        qdrant_resp = requests.put(
            f"{QDRANT_URL}/collections/AdminBot/points",
            json={"points": [{
                "id": i + 1,
                "vector": emb,
                "payload": {"content": content, "type": doc["type"]}
            }]},
            timeout=30
        )
        qdrant_resp.raise_for_status()
    except requests.RequestException as err:
        print(f"❌ Erreur Qdrant sur {doc['type']} : {err}")
        continue

    print(f"✅ {doc['type']} chargé !")
    time.sleep(0.5)


print("🎉 Tous les documents sont dans Qdrant !")

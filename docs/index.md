# hash-tool

Outil CLI de vérification d'intégrité de fichiers par hachage **BLAKE3**.
Calcule des empreintes cryptographiques sur un dossier, détecte toute modification
ultérieure, et compare deux états pour identifier précisément ce qui a changé.

---

## Cas d'usage

- **Audit avant archivage** — photographier l'état d'un dossier avant de l'archiver,
  pour pouvoir prouver plus tard qu'il n'a pas été altéré

- **Contrôle après migration** — vérifier qu'une copie ou migration de données est
  parfaite, sans perte ni corruption
  
- **Surveillance périodique** — détecter toute modification non autorisée sur un
  volume chiffré (VeraCrypt, LUKS) ou un NAS

- **Automatisation CI/CD** — intégrer un contrôle d'intégrité dans un pipeline
  via un fichier JSON

---

## Commandes disponibles

| Commande | Description | Cas d'usage principal |
|---|---|---|
| `compute` | Calcule les empreintes BLAKE3 d'un dossier | Créer une base de référence |
| `verify` | Vérifie l'intégrité d'un dossier contre une base | Contrôle périodique |
| `compare` | Compare deux bases d'empreintes | Audit après migration |
| `list` | Liste les bases disponibles dans un dossier | Inventaire rapide |
| `diff` | Détecte les fichiers ajoutés ou supprimés (sans recalcul) | Diagnostic rapide |
| `stats` | Affiche des statistiques sur une base | Vérification avant verify |
| `runner` | Exécute un pipeline JSON (compute + verify + compare) | Automatisation |

---

## Modes d'exécution

hash-tool fonctionne dans deux modes — la détection est **automatique** :

**Mode natif** (recommandé) : `b3sum` et `jq` sont installés sur la machine.
hash-tool appelle directement `src/integrity.sh`. Plus rapide, pas de dépendance Docker.

**Mode Docker** (fallback) : `b3sum` ou `jq` sont absents, mais l'image `hash-tool`
est disponible. hash-tool construit les volumes et lance `docker run` automatiquement.
L'interface CLI reste identique dans les deux modes.

```bash
# Vérifier le mode actif
bash hash-tool check-env
```

---

## Installation en 3 commandes

```bash
git clone https://github.com/Alan45678/hash-tool
cd hash-tool
chmod +x hash-tool runner.sh src/integrity.sh
```

Voir [Prérequis](getting-started/prerequisites.md) et
[Installation](getting-started/installation.md) pour les détails.

---

## Exemple rapide

```bash
# 1. Calculer les empreintes d'un dossier
bash hash-tool compute -data ./mes-documents -save ./bases -meta "Avant archivage"

# 2. Plus tard, vérifier que rien n'a changé
bash hash-tool verify -base ./bases/hashes_mes-documents.b3 -data ./mes-documents

# 3. Après une migration, comparer deux états
bash hash-tool compare -old ./bases/hashes_avant.b3 -new ./bases/hashes_apres.b3

# 4. Automatiser avec un pipeline JSON : pipeline = compute + compute + compare 
bash hash-tool runner -pipeline ./pipelines/pipeline.json
```

---

## Navigation

| Je veux... | Par ici |
|---|---|
| Installer et lancer ma première commande | [Démarrage rapide](getting-started/quickstart.md) |
| Apprendre par la pratique | [Tutoriels](tutorials/index.md) |
| Consulter la référence d'une commande | [Utilisation](usage/cli.md) |
| Utiliser Docker ou Docker Compose | [Docker](docker/setup.md) |
| Résoudre un problème | [Troubleshooting](troubleshooting/index.md) |
| Contribuer ou comprendre le code | [Développement](development/architecture.md) |
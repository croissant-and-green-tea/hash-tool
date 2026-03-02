# Interface CLI

`hash-tool` est le point d'entrée unique. Il détecte automatiquement le mode
d'exécution (natif ou Docker) et dispatch vers `integrity.sh` ou `runner.sh`.

---

## Syntaxe générale

```
bash hash-tool <commande> [options]
```

---

## Commandes disponibles

| Commande | Description |
|---|---|
| `compute` | Calcule les empreintes BLAKE3 d'un dossier → fichier `.b3` |
| `verify` | Vérifie l'intégrité d'un dossier contre une base `.b3` |
| `compare` | Compare deux bases `.b3` et produit un rapport de différences |
| `runner` | Exécute un pipeline JSON (enchaîne compute/verify/compare) |
| `list` | Liste les bases `.b3` disponibles dans un dossier |
| `diff` | Détecte les fichiers ajoutés/supprimés sans recalcul des hashes |
| `stats` | Affiche les statistiques d'une base `.b3` |
| `check-env` | Analyse l'environnement et affiche le mode d'exécution actif |
| `version` | Affiche la version |
| `help` | Affiche l'aide générale ou l'aide d'une commande spécifique |

---

## Options communes

Ces options sont reconnues par toutes les commandes qui les supportent :

| Option | Description |
|---|---|
| `-save <dossier>` | Dossier de sortie pour les résultats. Surcharge `RESULTATS_DIR`. |
| `-meta <texte>` | Commentaire libre stocké dans le sidecar `.meta.json` (compute uniquement) |
| `-quiet` | Supprime toute sortie terminal. Exit code propagé sans modification. |
| `-verbose` | Mode verbeux — affiche les détails d'exécution |
| `-readonly` | Indique dans le sidecar que la base est en lecture seule (flag informatif) |
| `-fast` | Mode batch : un seul appel b3sum, pas de progression ETA. Plus rapide sur les grands volumes. Applicable à `compute` uniquement. |

---

## Aide contextuelle

```bash
# Aide générale
bash hash-tool help

# Aide d'une commande spécifique
bash hash-tool help compute
bash hash-tool help verify
bash hash-tool help compare
```

---

## Détection du mode d'exécution

`hash-tool` sélectionne automatiquement le mode au démarrage :

1. **Natif** — si `b3sum`, `jq` et `src/integrity.sh` sont disponibles
2. **Docker** — si l'image `hash_tool` est présente (`docker image inspect hash_tool`)
3. **Erreur** — aucun mode disponible → message d'erreur explicite et exit 1

```bash
# Vérifier le mode actif et l'état de l'environnement
bash hash-tool check-env
```

---

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `RESULTATS_DIR` | `~/integrity_resultats/` | Dossier de sortie pour `verify` et `compare` |
| `HASH_TOOL_DOCKER_IMAGE` | `hash_tool` | Nom de l'image Docker à utiliser |

**Priorité** : argument CLI (`-save`) > variable d'environnement (`RESULTATS_DIR`) > valeur par défaut.

```bash
# Exemple : changer le dossier de résultats par défaut
export RESULTATS_DIR=/srv/resultats
bash hash-tool verify -base ./bases/hashes.b3 -data ./donnees

# Exemple : utiliser une image Docker personnalisée
export HASH_TOOL_DOCKER_IMAGE=mon-hash-tool:v2
bash hash-tool compute -data ./donnees -save ./bases
```
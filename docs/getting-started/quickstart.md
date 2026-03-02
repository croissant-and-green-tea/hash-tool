# Démarrage rapide

Ce guide couvre les trois opérations fondamentales de hash_tool en moins de 10 minutes :
calculer des empreintes, vérifier l'intégrité, comparer deux états.

---

## Prérequis

bash >= 4, `b3sum`, `jq` installés, et `src/integrity.sh` exécutable.
Voir [Prérequis](prerequisites.md) et [Installation](installation.md) si ce n'est pas le cas.

---

## 1. Premier compute

Le `compute` calcule les empreintes BLAKE3 de tous les fichiers d'un dossier et les enregistre
dans un fichier `.b3`.

```bash
bash src/integrity.sh compute ./mes-documents hashes.b3
```

Sortie attendue :

```
Base enregistrée : hashes.b3 (147 fichiers)
Sidecar : hashes.b3.meta.json
```

Deux fichiers sont produits :

- **`hashes.b3`** - une ligne par fichier, au format `<hash_blake3>  <chemin_relatif>` :
  ```
  3b2e4f... ./rapport-2024.pdf
  a91c7d... ./données/export.csv
  ```
- **`hashes.b3.meta.json`** - métadonnées de contexte (date, dossier, nombre de fichiers) :
  ```json
  {
    "created_by": "2.0.0",
    "date": "2026-02-28T14:00:00Z",
    "comment": "",
    "parameters": {
      "directory": "./mes-documents",
      "hash_algo": "blake3",
      "nb_files": 147
    }
  }
  ```

!!! note "Répertoire de travail"
    Les chemins dans `hashes.b3` sont relatifs au répertoire courant au moment du `compute`.
    Le `verify` doit être lancé depuis le même répertoire. C'est la source d'erreur la plus
    fréquente - voir [Troubleshooting](../troubleshooting/execution.md).

!!! tip "Ajouter un commentaire"
    Un commentaire libre peut être stocké dans le sidecar pour documenter le contexte :
    ```bash
    bash src/integrity.sh compute ./mes-documents hashes.b3 "Snapshot avant archivage"
    ```

---

## 2. Premier verify

Le `verify` relit le fichier `.b3` et recalcule les empreintes pour détecter toute modification.

```bash
bash src/integrity.sh verify hashes.b3
```

Sortie nominale (tout OK) :

```
--- Métadonnées (sidecar) ---
{
  "created_by": "2.0.0",
  "date": "2026-02-28T14:00:00Z",
  ...
}
-----------------------------
Vérification OK - 147 fichiers intègres.
Résultats dans : ~/integrity_resultats/resultats_hashes
  recap.txt
```

Le code de sortie `0` confirme l'intégrité. Exploitable en script :

```bash
bash src/integrity.sh verify hashes.b3
if [ $? -eq 0 ]; then
    echo "Intégrité confirmée"
else
    echo "ANOMALIE DÉTECTÉE" >&2
fi
```

Sortie en cas d'anomalie :

```
████████████████████████████████████████
  ECHEC : 2 fichier(s) corrompu(s) ou manquant(s)
████████████████████████████████████████

./données/export.csv: FAILED
./rapport-2024.pdf: FAILED (No such file or directory)

Résultats dans : ~/integrity_resultats/resultats_hashes
  recap.txt
  failed.txt
```

Le code de sortie est `1`. Le détail est dans `failed.txt`.

---

## 3. Premier compare

Le `compare` confronte deux bases `.b3` pour identifier ce qui a changé entre deux états.

Cas d'usage typique : vérifier qu'une migration n'a rien altéré.

```bash
# Étape 1 : compute avant migration
bash src/integrity.sh compute ./source hashes_avant.b3

# Étape 2 : exécuter la migration
# ...

# Étape 3 : compute après migration
bash src/integrity.sh compute ./destination hashes_apres.b3

# Étape 4 : compare
bash src/integrity.sh compare hashes_avant.b3 hashes_apres.b3
```

Sortie nominale (migration parfaite) :

```
Résultats enregistrés dans : ~/integrity_resultats/resultats_hashes_avant
  recap.txt     - modifiés: 0, disparus: 0, nouveaux: 0
  modifies.b3   - 0 fichiers
  disparus.txt  - 0 fichiers
  nouveaux.txt  - 0 fichiers
  report.html   - rapport visuel
```

Cinq fichiers sont produits dans le dossier de résultats :

| Fichier | Contenu |
|---|---|
| `recap.txt` | Synthèse chiffrée : modifiés, disparus, nouveaux |
| `modifies.b3` | Fichiers présents dans les deux bases avec un hash différent |
| `disparus.txt` | Fichiers présents dans la base de référence, absents dans la nouvelle |
| `nouveaux.txt` | Fichiers absents de la base de référence, présents dans la nouvelle |
| `report.html` | Rapport visuel complet, ouvrir dans un navigateur |

Ouvrir le rapport HTML :

```bash
xdg-open ~/integrity_resultats/resultats_hashes_avant/report.html   # Linux
open ~/integrity_resultats/resultats_hashes_avant/report.html        # macOS
```

---

## Récapitulatif des commandes

```bash
# Calculer les empreintes d'un dossier
bash src/integrity.sh compute <dossier> <base.b3> [commentaire]

# Vérifier l'intégrité d'un dossier contre une base
bash src/integrity.sh verify <base.b3> [dossier]

# Comparer deux bases
bash src/integrity.sh compare <ancienne.b3> <nouvelle.b3>
```

---

## Étapes suivantes

- [Tutoriel : Premier audit complet](../tutorials/01-premier-audit.md)
- [Tutoriel : Vérification d'une migration](../tutorials/02-migration.md)
- [Référence des commandes](../usage/cli.md)
- [Automatisation et cron](../guides/automation.md)
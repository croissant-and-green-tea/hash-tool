# Guide — Volumes VeraCrypt

Vérification d'intégrité sur des volumes chiffrés VeraCrypt montés sous Windows/WSL2.
hash_tool fonctionne sur les volumes montés exactement comme sur n'importe quel dossier.

---

## Contexte

Sous Windows avec WSL2, les volumes VeraCrypt montés apparaissent comme des lecteurs
accessibles depuis WSL2 via `/mnt/<lettre>/` :

| Lettre lecteur Windows | Chemin WSL2 |
|---|---|
| `A:` | `/mnt/a/` |
| `H:` | `/mnt/h/` |
| `I:` | `/mnt/i/` |

Les bases `.b3` doivent être stockées **hors des volumes chiffrés** — par exemple
sur le bureau Windows (`/mnt/c/Users/TonNom/Desktop/bases/`) — pour rester accessibles
sans avoir à monter les volumes à chaque lecture.

---

## Prérequis

1. VeraCrypt installé et configuré sous Windows
2. WSL2 installé (Ubuntu recommandé)
3. hash_tool installé dans WSL2 (voir [Installation](../getting-started/installation.md))
4. Volumes VeraCrypt montés **avant** de lancer hash_tool

Vérifier que les volumes sont accessibles :

```bash
ls /mnt/a/dossier_disque_1
ls /mnt/i/dossier_disque_2
```

---

## Workflow

### 1. Monter les volumes VeraCrypt

Via l'interface VeraCrypt sous Windows — monter chaque volume sur une lettre de lecteur.

### 2. Calculer les empreintes de chaque volume

```bash
bash hash-tool compute \
  -data /mnt/a/dossier_disque_1 \
  -save /mnt/c/Users/TonNom/Desktop/bases \
  -meta "Volume VeraCrypt disque 1 - $(date +%Y-%m-%d)"

bash hash-tool compute \
  -data /mnt/i/dossier_disque_2 \
  -save /mnt/c/Users/TonNom/Desktop/bases \
  -meta "Volume VeraCrypt disque 2 - $(date +%Y-%m-%d)"
```

### 3. Vérifier l'intégrité immédiatement après compute

```bash
bash hash-tool verify \
  -base /mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_disque_1.b3 \
  -data /mnt/a/dossier_disque_1
```

### 4. Comparer deux volumes (audit croisé)

```bash
bash hash-tool compare \
  -old /mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_disque_1.b3 \
  -new /mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_disque_2.b3 \
  -save /mnt/c/Users/TonNom/Desktop/resultats/veracrypt
```

### 5. Démonter les volumes

Via l'interface VeraCrypt sous Windows.

---

## Pipeline VeraCrypt

Le fichier `examples/pipelines/pipeline-veracrypt.json` enchaîne les 4 étapes
en une seule commande. Adapter les chemins avant usage :

```json
{
  "pipeline": [
    {
      "type": "compute",
      "params": {
        "input":      "/mnt/a/dossier_disque_1",
        "output_dir": "/mnt/c/Users/TonNom/Desktop/bases",
        "filename":   "hashes_disque_1.b3"
      },
      "options": { "readonly": true },
      "meta":    { "comment": "Volume VeraCrypt disque 1 - snapshot initial" }
    },
    {
      "type": "compute",
      "params": {
        "input":      "/mnt/i/dossier_disque_2",
        "output_dir": "/mnt/c/Users/TonNom/Desktop/bases",
        "filename":   "hashes_disque_2.b3"
      },
      "options": { "readonly": true },
      "meta":    { "comment": "Volume VeraCrypt disque 2 - snapshot initial" }
    },
    {
      "type": "verify",
      "params": {
        "input": "/mnt/a/dossier_disque_1",
        "base":  "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_1.b3"
      }
    },
    {
      "type": "compare",
      "params": {
        "base_a":    "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_1.b3",
        "base_b":    "/mnt/c/Users/TonNom/Desktop/bases/hashes_disque_2.b3",
        "resultats": "/mnt/c/Users/TonNom/Desktop/resultats/veracrypt"
      }
    }
  ]
}
```

Lancer :

```bash
bash hash-tool runner -pipeline ./examples/pipelines/pipeline-veracrypt.json
```

---

## Adapter à votre configuration

Variables à remplacer dans le pipeline :

| Valeur exemple | À remplacer par |
|---|---|
| `/mnt/a/dossier_disque_1` | Chemin WSL2 de votre volume 1 |
| `/mnt/i/dossier_disque_2` | Chemin WSL2 de votre volume 2 |
| `TonNom` | Votre nom d'utilisateur Windows |
| `Desktop/bases` | Dossier de stockage des bases |
| `Desktop/resultats/veracrypt` | Dossier de stockage des résultats |

---

## Notes spécifiques WSL2

!!! warning "Performances sur /mnt/c/"
    L'accès aux fichiers dans `/mnt/c/` (filesystem Windows) depuis WSL2 est plus
    lent que sur le filesystem Linux natif. Pour de grands volumes, envisager de
    stocker les bases dans `/home/...` et de les copier sur le bureau Windows
    en fin d'opération.

!!! warning "Mode Docker non recommandé pour VeraCrypt"
    Les chemins `/mnt/a/`, `/mnt/i/` ne sont pas montables comme volumes Docker
    depuis WSL2. Utiliser le **mode natif** (`b3sum` + `jq` installés dans WSL2).
# T3 — Automatiser avec un pipeline JSON

Objectif : définir un workflow complet dans un fichier JSON et le lancer en une
seule commande. Durée estimée : 25 minutes.

Prérequis : avoir suivi T1 et T2, ou connaître le cycle `compute` / `verify` / `compare`.

---

## Étape 1 — Anatomie d'un pipeline JSON

Un pipeline est un tableau d'opérations exécutées séquentiellement par `runner.sh`.
Chaque opération a la structure suivante :

```json
{
  "type":        "compute",          // opération : compute | verify | compare
  "description": "Texte libre",      // affiché dans les logs (optionnel)
  "params":      { ... },            // chemins d'entrée/sortie
  "options":     { "quiet": false }, // options de comportement (optionnel)
  "meta":        { "comment": "" }  // commentaire sidecar (compute uniquement)
}
```

**Champs `params` par opération :**

| Opération | Champs requis | Champs optionnels |
|---|---|---|
| `compute` | `input`, `output_dir`, `filename` | — |
| `verify` | `base`, `input` | `resultats` |
| `compare` | `base_a`, `base_b` | `resultats` |

---

## Étape 2 — Écrire votre premier pipeline

Créez le fichier `./mon-pipeline.json` :

```json
{
  "pipeline": [
    {
      "type": "compute",
      "description": "Calculer les empreintes de la source",
      "params": {
        "input":      "./examples/workspace/_data-source",
        "output_dir": "./examples/workspace/bases",
        "filename":   "hashes_source.b3"
      },
      "options": { "quiet": false },
      "meta":    { "comment": "Pipeline T3 - source" }
    },
    {
      "type": "compute",
      "description": "Calculer les empreintes de la destination",
      "params": {
        "input":      "./examples/workspace/_data-destination",
        "output_dir": "./examples/workspace/bases",
        "filename":   "hashes_destination.b3"
      },
      "options": { "quiet": false },
      "meta":    { "comment": "Pipeline T3 - destination" }
    },
    {
      "type": "compare",
      "description": "Comparer source et destination",
      "params": {
        "base_a":    "./examples/workspace/bases/hashes_source.b3",
        "base_b":    "./examples/workspace/bases/hashes_destination.b3",
        "resultats": "./examples/workspace/resultats-pipeline"
      }
    }
  ]
}
```

Validez la syntaxe JSON avant de lancer :

```bash
jq . mon-pipeline.json
```

---

## Étape 3 — Lancer le pipeline

```bash
bash hash-tool runner -pipeline ./mon-pipeline.json
```

Sortie attendue :

```
[1/3] Calculer les empreintes de la source
  Base enregistrée : hashes_source.b3 (4 fichiers)

[2/3] Calculer les empreintes de la destination
  Base enregistrée : hashes_destination.b3 (4 fichiers)

[3/3] Comparer source et destination
  Résultats dans : ./examples/workspace/resultats-pipeline/
    recap.txt     - modifiés: 1, disparus: 0, nouveaux: 0
```

`hash-tool` gère automatiquement le mode d'exécution (natif ou Docker) — la commande
est identique dans les deux cas.

---

## Étape 4 — Pipelines fournis en exemple

Le dépôt inclut des pipelines dans `examples/pipelines/` :

| Fichier | Usage |
|---|---|
| `pipeline-migration.json` | compute × 2 + verify + compare — workflow migration complet |
| `pipeline-veracrypt.json` | compute sur volumes VeraCrypt montés sous WSL2 |

---

## Aller plus loin — Planifier l'exécution

**Linux / WSL2 — cron :**

```bash
crontab -e

# Exécution chaque nuit à 03h00
0 3 * * * cd /chemin/vers/hash-tool && bash hash-tool runner -pipeline ./pipelines/pipeline.json >> /var/log/hash-tool.log 2>&1
```

Voir [Automatisation](../guides/automation.md) pour le setup complet avec alertes
et rotation des logs.

---

## Ce que vous savez maintenant faire

À l'issue des 3 tutoriels, vous maîtrisez le workflow complet :

- **T1** : `compute` → `stats` → `verify` — audit unitaire d'un dossier
- **T2** : `compute` × 2 → `compare` — validation d'une migration
- **T3** : `runner` — automatisation du workflow complet via pipeline JSON

Pour la référence complète de chaque commande, consultez la section [Utilisation](../usage/cli.md).
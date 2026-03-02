# Pipelines JSON

Un pipeline JSON définit une séquence d'opérations (`compute`, `verify`, `compare`)
exécutées automatiquement par `runner.sh`. Une seule commande remplace plusieurs
appels manuels successifs.

---

## Format du fichier

Le fichier doit contenir un objet JSON avec une clé `pipeline` contenant un tableau
d'opérations :

```json
{
  "pipeline": [
    { ... },
    { ... }
  ]
}
```

Deux formats coexistent. Le **format étendu** est recommandé pour les nouveaux pipelines.
Le **format legacy** est conservé pour la rétrocompatibilité — ne pas mélanger les deux
formats dans un même fichier.

---

## Format étendu (recommandé)

Chaque opération a la structure suivante :

```json
{
  "type":        "compute",
  "description": "Texte libre affiché dans les logs",
  "params":      { ... },
  "options":     { "quiet": false, "verbose": false, "readonly": false },
  "meta":        { "comment": "Commentaire sidecar" }
}
```

### Opération `compute`

```json
{
  "type": "compute",
  "description": "Calculer les empreintes de la source",
  "params": {
    "input":      "/chemin/vers/dossier",
    "output_dir": "/chemin/vers/bases",
    "filename":   "hashes_source.b3"
  },
  "options": { "quiet": false },
  "meta":    { "comment": "Snapshot initial" }
}
```

| Champ | Obligatoire | Description |
|---|---|---|
| `params.input` | Oui | Dossier à hacher |
| `params.output_dir` | Oui | Dossier de sortie pour le `.b3` |
| `params.filename` | Oui | Nom du fichier `.b3` à produire |
| `options.quiet` | Non | Supprime la sortie terminal |
| `meta.comment` | Non | Commentaire stocké dans le sidecar |

### Opération `verify`

```json
{
  "type": "verify",
  "description": "Vérifier l'intégrité de la source",
  "params": {
    "input": "/chemin/vers/dossier",
    "base":  "/chemin/vers/bases/hashes_source.b3"
  }
}
```

| Champ | Obligatoire | Description |
|---|---|---|
| `params.input` | Oui | Dossier à vérifier |
| `params.base` | Oui | Fichier `.b3` de référence |
| `params.resultats` | Non | Dossier de sortie des résultats |

### Opération `compare`

```json
{
  "type": "compare",
  "description": "Comparer source et destination",
  "params": {
    "base_a":    "/chemin/vers/bases/hashes_source.b3",
    "base_b":    "/chemin/vers/bases/hashes_destination.b3",
    "resultats": "/chemin/vers/resultats"
  }
}
```

| Champ | Obligatoire | Description |
|---|---|---|
| `params.base_a` | Oui | Base de référence (ancien état) |
| `params.base_b` | Oui | Base à comparer (nouvel état) |
| `params.resultats` | Non | Dossier de sortie des résultats |

---

## Format legacy (rétrocompatible)

```json
{
  "pipeline": [
    {
      "op":     "compute",
      "source": "/chemin/vers/dossier",
      "bases":  "/chemin/vers/bases",
      "nom":    "hashes_source.b3"
    },
    {
      "op":     "verify",
      "source": "/chemin/vers/dossier",
      "base":   "/chemin/vers/bases/hashes_source.b3"
    },
    {
      "op":     "compare",
      "base_a": "/chemin/vers/bases/hashes_source.b3",
      "base_b": "/chemin/vers/bases/hashes_dest.b3"
    }
  ]
}
```

---

## Exécution

```bash
# Pipeline par défaut (pipelines/pipeline.json)
bash hash-tool runner

# Pipeline explicite
bash hash-tool runner -pipeline ./mon-pipeline.json

# Avec dossier de résultats personnalisé
bash hash-tool runner -pipeline ./mon-pipeline.json -save ./resultats
```

**Comportement** : les opérations s'exécutent séquentiellement dans l'ordre du tableau.
En cas d'échec d'une étape, le pipeline s'arrête immédiatement (`set -euo pipefail`).

---

## Chemins dans le pipeline

!!! warning "Chemins relatifs"
    Les chemins relatifs dans le pipeline sont résolus depuis le répertoire de
    `runner.sh`, pas depuis le répertoire courant de l'utilisateur.
    En production, toujours utiliser des **chemins absolus** pour éviter les
    surprises selon l'endroit depuis lequel vous lancez la commande.

```bash
# Vérifier les chemins résolus
jq '.pipeline[].params' mon-pipeline.json
```

---

## Validation avant exécution

```bash
# Vérifier la syntaxe JSON
jq . mon-pipeline.json

# Vérifier que les chemins existent
jq -r '.pipeline[].params.input // empty' mon-pipeline.json | while read -r p; do
  [ -d "$p" ] && echo "OK : $p" || echo "MANQUANT : $p"
done
```

---

## Pipelines fournis en exemple

| Fichier | Description |
|---|---|
| `pipelines/pipeline.json` | Template de base — chemins à adapter avant usage |

Copier et adapter `pipeline.json` pour créer vos propres pipelines :

```bash
cp pipelines/pipeline.json pipelines/mon-audit.json
# Éditer les chemins dans mon-audit.json
bash hash-tool runner -pipeline ./pipelines/mon-audit.json
```
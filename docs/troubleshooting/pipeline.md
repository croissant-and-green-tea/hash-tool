# Troubleshooting — Pipeline

---

## Erreur JSON au lancement du runner

**Symptôme** : `ERREUR : JSON invalide` ou `jq: error (at pipeline.json:N): ...`

**Cause** : syntaxe JSON invalide dans le fichier pipeline.

**Diagnostic** :

```bash
jq . mon-pipeline.json
```

`jq` affiche l'erreur avec le numéro de ligne exact.

**Erreurs fréquentes :**

```json
// Virgule après le dernier élément d'un tableau — invalide en JSON
{
  "pipeline": [
    { "type": "compute", ... },   ← virgule en trop
  ]
}

// Clé sans guillemets — invalide en JSON
{
  "pipeline": [
    { type: "compute" }           ← clé non quotée
  ]
}

// Accolade ou crochet non fermé
{
  "pipeline": [
    { "type": "compute", "params": { ... }
  ]
  // } manquant
```

---

## Champ `op` non reconnu / opération inconnue

**Symptôme** : `ERREUR : opération inconnue : compute` ou similaire.

**Cause** : deux formats de pipeline coexistent.
- Format legacy (`pipeline.json`) : champ `op`
- Format étendu (recommandé) : champ `type`

`runner.sh` détecte automatiquement le format, mais les deux **ne doivent pas être
mélangés** dans un même fichier.

**Diagnostic** :

```bash
# Vérifier quel champ est utilisé
jq '.[].op // empty, .[].type // empty' mon-pipeline.json
```

**Solution** : utiliser exclusivement `type` (format étendu) dans les nouveaux pipelines.
Voir [Pipelines JSON](../usage/pipeline.md) pour le schéma complet.

---

## Champ obligatoire manquant

**Symptôme** : `ERREUR : Bloc #N : params.input manquant ou vide`

**Cause** : un champ requis est absent ou vide dans le JSON.

**Champs requis par opération :**

| Opération | Champs obligatoires |
|---|---|
| `compute` | `params.input`, `params.output_dir`, `params.filename` |
| `verify` | `params.input`, `params.base` |
| `compare` | `params.base_a`, `params.base_b` |

**Diagnostic** :

```bash
# Lister tous les params du pipeline
jq '.pipeline[] | {type, params}' mon-pipeline.json
```

---

## Pipeline s'arrête à mi-exécution

**Comportement attendu** : `runner.sh` fonctionne sous `set -euo pipefail`.
Toute commande retournant exit non-zéro arrête immédiatement le pipeline.
Ce n'est pas un bug — c'est une protection contre la propagation d'erreurs silencieuses.

**Identifier l'étape qui échoue** :

```bash
# Lancer avec bash -x pour tracer chaque commande
bash -x runner.sh mon-pipeline.json 2>&1 | head -50
```

La dernière commande affichée avant l'arrêt est la cause.

**Causes fréquentes :**

- Dossier source introuvable (chemin relatif mal résolu)
- Base `.b3` absente pour `verify` ou `compare`
- `b3sum` absent en mode natif
- Permissions insuffisantes sur le dossier de sortie

Il n'existe pas de mode `--continue-on-error` natif. Corriger l'erreur sous-jacente.

---

## Chemins relatifs non résolus

**Symptôme** : `ERREUR : Bloc #N compute : dossier source introuvable : ./donnees`
malgré un chemin qui semble correct.

**Cause** : les chemins relatifs dans le JSON sont résolus depuis le **répertoire
du script `runner.sh`**, pas depuis le répertoire courant de l'utilisateur.

Exemple : si vous lancez depuis `/home/moi/projet` mais que `runner.sh` est dans
`/home/moi/hash-tool`, `./donnees` est résolu comme `/home/moi/hash-tool/donnees`.

**Diagnostic** :

```bash
# Afficher depuis quel répertoire runner.sh résout les chemins
grep "SCRIPT_DIR" runner.sh
```

**Solution** : toujours utiliser des **chemins absolus** dans les pipelines de production :

```json
{
  "params": {
    "input":      "/srv/donnees",
    "output_dir": "/srv/bases",
    "filename":   "hashes.b3"
  }
}
```

---

## Pipeline vide ou tableau absent

**Symptôme** : `ERREUR : tableau .pipeline vide ou absent`

**Cause** : le fichier JSON ne contient pas la clé `pipeline`, ou le tableau est vide.

**Vérification** :

```bash
jq '.pipeline | length' mon-pipeline.json
# Doit retourner un nombre > 0
```

Structure minimale valide :

```json
{
  "pipeline": [
    {
      "type": "compute",
      "params": {
        "input":      "/chemin/source",
        "output_dir": "/chemin/bases",
        "filename":   "hashes.b3"
      }
    }
  ]
}
```
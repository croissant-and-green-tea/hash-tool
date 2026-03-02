# Fichier sidecar `.meta.json`

---

## Rôle

Le sidecar est un fichier JSON accolé à chaque base `.b3` :

```
hashes_archives.b3
hashes_archives.b3.meta.json   ← sidecar
```

Il stocke le contexte au moment du `compute` : version de l'outil, date,
commentaire libre, dossier haché, algorithme, nombre de fichiers.

Affiché automatiquement par `verify`, `compare`, `stats` et `list` avant
ou après l'opération — pas besoin de l'ouvrir manuellement.

---

## Schéma complet

```json
{
  "created_by": "hash-tool v2.0.0",
  "date": "2026-02-28T14:30:00Z",
  "comment": "Snapshot initial - avant archivage",
  "parameters": {
    "directory": "/chemin/absolu/vers/dossier",
    "hash_algo": "blake3",
    "readonly": false,
    "nb_files": 1247
  }
}
```

### Description des champs

| Champ | Type | Description |
|---|---|---|
| `created_by` | string | Version de hash-tool ayant produit la base |
| `date` | string ISO 8601 UTC | Horodatage du `compute` |
| `comment` | string | Commentaire saisi via `-meta` (vide si non fourni) |
| `parameters.directory` | string | Chemin absolu du dossier haché au moment du `compute` |
| `parameters.hash_algo` | string | Algorithme utilisé — toujours `"blake3"` |
| `parameters.readonly` | boolean | Flag `-readonly` (informatif, n'affecte pas le calcul) |
| `parameters.nb_files` | integer | Nombre de fichiers indexés dans la base |

---

## Lecture automatique

**`verify`** — affiche le sidecar en tête d'exécution :

```
--- Métadonnées (sidecar) ---
{
  "created_by": "hash-tool v2.0.0",
  "date": "2026-02-28T14:30:00Z",
  "comment": "Snapshot initial",
  ...
}
-----------------------------
Vérification OK - 4 fichiers intègres.
```

**`compare`** — affiche les sidecars des deux bases en tête.

**`stats`** — affiche le sidecar en fin de sortie.

**`list`** — affiche le commentaire et la date sur une ligne dédiée :

```
  hashes_archives.b3    1247 fichiers   82K [+meta]
     -> Snapshot initial (2026-02-28T14:30:00Z)
```

---

## Ajouter un commentaire

Via `-meta` lors du `compute` :

```bash
bash hash-tool compute \
  -data ./archives \
  -save ./bases \
  -meta "Avant archivage froid - disque A - 2026-03-01"
```

Bonnes pratiques pour le commentaire :
- Inclure la date si non évidente depuis le nom de fichier
- Identifier le contexte (avant/après migration, snapshot mensuel, etc.)
- Mentionner le support physique si pertinent (disque A, NAS, serveur X)

---

## Absence de sidecar

Si le sidecar est absent, toutes les commandes fonctionnent normalement.
Le sidecar est simplement ignoré — pas d'erreur, pas d'avertissement.

Les bases créées avec la v1.x (sans sidecar) restent pleinement utilisables.

---

## Sidecar en mode Docker

En mode Docker, le sidecar est écrit par `integrity.sh` à l'intérieur du conteneur
dans le volume `/bases` monté. Il est directement visible sur l'hôte après l'exécution.

Le champ `parameters.directory` contient le chemin **dans le conteneur** (`/data`),
pas le chemin hôte — c'est attendu et n'affecte pas le fonctionnement de `verify`.
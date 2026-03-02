# compute

Calcule les empreintes BLAKE3 de tous les fichiers d'un dossier et les enregistre dans un
fichier `.b3`. Produit également un fichier sidecar `.meta.json` si `jq` est disponible.

---

## Syntaxe

```bash
bash src/integrity.sh compute <dossier> <base.b3> [commentaire]
```

| Argument | Obligatoire | Description |
|---|---|---|
| `<dossier>` | Oui | Dossier cible à hacher (relatif ou absolu) |
| `<base.b3>` | Oui | Fichier de sortie contenant les empreintes |
| `[commentaire]` | Non | Texte libre stocké dans le sidecar `.meta.json` |
| `-fast` | Non | Mode batch sans progression. Incompatible avec les callbacks ETA. |

Option globale applicable :

| Option | Description |
|---|---|
| `--quiet` | Supprime toute sortie terminal. Exit code propagé sans modification. |

---

## Comportement

1. **Validation** : vérifie que `<dossier>` existe, est bien un dossier, et contient au moins
   un fichier régulier. Erreur immédiate sinon.
2. **Découverte** : `find <dossier> -type f` récursif, trié par chemin de manière déterministe.
   Les fichiers cachés et les sous-dossiers sont inclus.
3. **Hachage** : chaque fichier est passé à `b3sum` individuellement. Les résultats sont
   accumulés dans `<base.b3>`.
4. **Format de sortie** : une ligne par fichier, format natif `b3sum` :
   ```
   <hash_blake3_64_chars>  <chemin_relatif>
   ```
   Les chemins sont **relatifs au répertoire de travail au moment du `compute`**, pas au dossier
   cible. Ce point est critique pour la cohérence avec `verify`.
5. **Progression** : une ligne ETA s'affiche sur le terminal en temps réel (effacée à la fin).
   Désactivée en mode `--quiet`.
6. **Sidecar** : si `jq` est disponible, un fichier `<base.b3>.meta.json` est créé à côté
   de la base.

---

## Fichiers produits

### `<base.b3>`

Fichier texte, une ligne par fichier indexé. Compatible avec la sortie native de `b3sum` —
il peut être relu directement par `b3sum --check`.

```
3b2e4f8a1c...  ./rapport-2024.pdf
a91c7d22f0...  ./données/export.csv
f047b3e19d...  ./données/archive.zip
```

### `<base.b3>.meta.json` (sidecar)

Fichier JSON créé automatiquement si `jq` est disponible. Stocke le contexte de création
pour affichage lors des opérations `verify`, `compare`, `stats` et `list`.

```json
{
  "created_by": "2.0.0",
  "date": "2026-02-28T14:00:00Z",
  "comment": "Snapshot avant archivage Q1 2026",
  "parameters": {
    "directory": "./mes-documents",
    "hash_algo": "blake3",
    "nb_files": 147
  }
}
```

| Champ | Description |
|---|---|
| `created_by` | Version de l'outil |
| `date` | Date ISO 8601 UTC au moment du compute |
| `comment` | Valeur du troisième argument, vide si absent |
| `parameters.directory` | Dossier tel que passé en argument |
| `parameters.hash_algo` | Toujours `blake3` |
| `parameters.nb_files` | Nombre de fichiers indexés |

Si `jq` est absent, le sidecar n'est pas créé. La base `.b3` est produite normalement.
Les bases sans sidecar sont pleinement utilisables par toutes les commandes.

---

## Codes de sortie

| Code | Signification |
|---|---|
| `0` | Succès — base créée et sidecar généré |
| `1` | Erreur — dossier introuvable, dossier vide, `<base.b3>` est un dossier, erreur `b3sum` |

---

## Répertoire de travail

!!! warning "Point critique"
    Les chemins dans le `.b3` sont relatifs au **répertoire de travail courant** au moment
    du `compute`, pas au dossier cible.

    Exemple : si tu lances `compute ./data hashes.b3` depuis `/home/user/projet`, les chemins
    dans `hashes.b3` seront `./data/fichier.txt`.

    Le `verify` doit donc être lancé depuis `/home/user/projet` pour que les chemins
    correspondent. C'est la source d'erreur la plus fréquente.
    Voir [Troubleshooting — chemins relatifs](../../troubleshooting/execution.md).

---

## Exemples

### Cas nominal

```bash
cd /home/user/projet
bash src/integrity.sh compute ./data hashes.b3
```

```
Base enregistrée : hashes.b3 (312 fichiers)
Sidecar : hashes.b3.meta.json
```

### Avec commentaire dans le sidecar

```bash
bash src/integrity.sh compute ./data hashes.b3 "Snapshot avant migration serveur"
```

Le commentaire est stocké dans `hashes.b3.meta.json` et affiché automatiquement
lors des `verify` et `compare` ultérieurs.

### Chemin absolu pour la base

Utile quand la base doit être stockée dans un dossier dédié, séparé des données :

```bash
bash src/integrity.sh compute ./data /srv/bases/hashes_data.b3
```

### Mode silencieux (usage en script ou cron)

```bash
bash src/integrity.sh --quiet compute ./data hashes.b3
echo "exit: $?"
```

Aucune sortie terminal. Le code de retour indique le succès ou l'échec.

### Mode rapide (sans progression ETA)
```bash
bash hash-tool compute -data ./donnees -save ./bases -fast
```

Appelle `b3sum` en batch sur tous les fichiers en un seul process.
Recommandé pour les grands volumes (> 1000 fichiers) quand la progression
n'est pas nécessaire.

---

## Erreurs fréquentes

**`Dossier cible introuvable`**
Le chemin passé en premier argument n'existe pas. Vérifier le chemin et le répertoire
de travail courant.

**`Le dossier ne contient aucun fichier régulier`**
Le dossier est vide ou ne contient que des sous-dossiers vides. `compute` refuse de
créer une base vide.

**`<base.b3> est un dossier`**
Le deuxième argument pointe vers un dossier existant. Le fichier `.b3` de sortie doit
être un chemin de fichier, pas un dossier.

---

## Voir aussi

- [verify](verify.md) — vérifier l'intégrité contre une base existante
- [compare](compare.md) — comparer deux bases
- [Formats de fichiers](../../reference/file-formats.md) — structure détaillée du `.b3`
- [Fichier sidecar](../../reference/sidecar.md) — schéma complet du `.meta.json`
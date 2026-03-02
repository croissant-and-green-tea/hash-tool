# stats

Affiche les statistiques d'une base d'empreintes `.b3` : nombre de fichiers,
distribution des extensions, contenu du sidecar.

---

## Syntaxe

```bash
bash hash-tool stats -base <fichier.b3>
```

| Option | Obligatoire | Description |
|---|---|---|
| `-base <fichier.b3>` | Oui | Fichier `.b3` à analyser |

---

## Affichage

```
=== Statistiques : hashes__data-source.b3 ===

  Fichier base     : /chemin/absolu/hashes__data-source.b3
  Taille fichier   : 4.0K
  Fichiers indexés : 4

  Extensions :
    .txt              4 fichiers

--- Métadonnées (sidecar) ---
{
  "created_by": "hash-tool v2.0.0",
  "date": "2026-02-28T14:30:00Z",
  "comment": "Audit initial T1",
  "parameters": {
    "directory": "/chemin/vers/_data-source",
    "hash_algo": "blake3",
    "readonly": false,
    "nb_files": 4
  }
}
-----------------------------
```

Les extensions sont triées par fréquence décroissante, top 10.
Si aucun sidecar n'est présent, la section métadonnées est omise.

---

## Usage typique

Vérification avant `verify` ou `compare` :

- S'assurer que la base contient le bon nombre de fichiers
- Confirmer qu'elle correspond au bon dossier (via `parameters.directory` dans le sidecar)
- Détecter une base vide ou tronquée (0 fichiers indexés)
- Lire le commentaire saisi lors du `compute`

---

## Exemples

**Inspecter une base avec sidecar :**

```bash
bash hash-tool stats -base ./bases/hashes__data-source.b3
```

**Inspecter une base sans sidecar :**

```bash
bash hash-tool stats -base ./bases/hashes_archives.b3
```

Sortie :

```
=== Statistiques : hashes_archives.b3 ===

  Fichier base     : /srv/bases/hashes_archives.b3
  Taille fichier   : 82K
  Fichiers indexés : 1247

  Extensions :
    .pdf             843 fichiers
    .docx            201 fichiers
    .xlsx             98 fichiers
    .txt              65 fichiers
    .jpg              40 fichiers
```
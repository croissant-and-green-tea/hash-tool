# Fichiers de résultats

Produits dans `RESULTATS_DIR` (défaut : `~/integrity_resultats/`) par les commandes
`verify` et `compare`. Chaque exécution crée un sous-dossier horodaté :
`resultats_<nom_base>_<date>/`.

---

## `recap.txt`

Toujours produit, même si tout est OK. Synthèse lisible par un script.

**Produit par `verify` :**

```
STATUT    : OK
OK        : 4
Base      : hashes__data-source.b3
Dossier   : /chemin/vers/_data-source
Date      : 2026-02-28T14:30:00Z
```

```
STATUT    : ECHEC
OK        : 3
FAILED    : 1  ← voir failed.txt
Base      : hashes__data-source.b3
Dossier   : /chemin/vers/_data-source
Date      : 2026-02-28T14:30:00Z
```

**Produit par `compare` :**

```
Modifiés  : 1
Disparus  : 0
Nouveaux  : 0
Base old  : hashes_source.b3
Base new  : hashes_destination.b3
Date      : 2026-02-28T15:00:00Z
```

---

## `failed.txt`

Produit par `verify` uniquement, et seulement si des anomalies sont détectées.

Liste des fichiers en erreur :

```
FAILED : ./lorem-ipsum-02.txt
FAILED : ./sous-dossier/document.pdf
```

- `FAILED` : hash différent de la base de référence (fichier modifié ou corrompu)
- `ERROR` : fichier inaccessible ou disparu (erreur de lecture `b3sum`)

---

## `modifies.b3`

Produit par `compare`. Fichiers dont le hash a changé entre `-old` et `-new`.
Format `.b3` standard — deux lignes par fichier modifié :

```
<hash_ancien>  ./fichier.txt  [OLD]
<hash_nouveau> ./fichier.txt  [NEW]
```

Absent ou vide si aucun fichier modifié. Peut être relu par `b3sum --check`
(en filtrant les lignes `[OLD]`).

---

## `disparus.txt`

Produit par `compare`. Fichiers présents dans `-old` mais absents de `-new`.
Un chemin par ligne :

```
./rapport-2024-01.pdf
./sous-dossier/archive.zip
```

Absent ou vide si aucun fichier disparu.

---

## `nouveaux.txt`

Produit par `compare`. Fichiers présents dans `-new` mais absents de `-old`.
Un chemin par ligne :

```
./rapport-2026-01.pdf
./nouveau-dossier/notes.txt
```

Absent ou vide si aucun nouveau fichier.

---

## `report.html`

Rapport visuel interactif généré depuis `reports/template.html`.
Ouvrir dans un navigateur.

**Produit par `compare` :** toujours.
**Produit par `verify` :** uniquement si des anomalies sont détectées.

Sections du rapport :

- Résumé statistique (compteurs modifiés/disparus/nouveaux)
- Liste des fichiers modifiés avec les deux hashes (ancien et nouveau)
- Liste des fichiers disparus
- Liste des fichiers nouveaux

---

## Dossier de résultats par défaut

```
~/integrity_resultats/
  resultats_hashes_source_2026-02-28_143000/
    recap.txt
    failed.txt          (si anomalie)
    report.html         (si anomalie ou compare)
  resultats_hashes_source_2026-03-01_030000/
    recap.txt
    ...
```

Surcharger avec `-save` ou `RESULTATS_DIR` :

```bash
# Via argument
bash hash-tool verify -base hashes.b3 -data ./donnees -save ./mes-resultats

# Via variable d'environnement
export RESULTATS_DIR=/srv/resultats
bash hash-tool verify -base hashes.b3 -data ./donnees
```
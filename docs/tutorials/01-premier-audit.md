# T1 — Premier audit d'intégrité

Objectif : calculer les empreintes d'un dossier, vérifier qu'il n'a pas été modifié,
détecter une corruption. Durée estimée : 15 minutes.

Les données de test sont dans `examples/workspace/_data-source/` — 4 fichiers
lorem-ipsum dans leur état d'origine. Aucune modification manuelle requise.

---

## Étape 1 — Calculer les empreintes

```bash
bash hash-tool compute \
  -data ./examples/workspace/_data-source \
  -save ./examples/workspace/bases \
  -meta "Audit initial T1"
```

Sortie attendue :

```
Base enregistrée : hashes__data-source.b3 (4 fichiers)
Sidecar : hashes__data-source.b3.meta.json
```

Deux fichiers sont produits dans `./examples/workspace/bases/` :

- `hashes__data-source.b3` — la base d'empreintes, une ligne par fichier :
  ```
  <hash_blake3>  ./lorem-ipsum-01-modif.txt
  <hash_blake3>  ./lorem-ipsum-02.txt
  <hash_blake3>  ./lorem-ipsum-03.txt
  <hash_blake3>  ./lorem-ipsum-04.txt
  ```
- `hashes__data-source.b3.meta.json` — les métadonnées (sidecar) :
  ```json
  {
    "created_by": "hash-tool v2.0.0",
    "date": "2026-02-28T...",
    "comment": "Audit initial T1",
    "parameters": {
      "directory": "/chemin/absolu/_data-source",
      "hash_algo": "blake3",
      "nb_files": 4
    }
  }
  ```

!!! tip "Chemin relatif dans la base"
    Les chemins dans le `.b3` sont relatifs au dossier haché, pas au répertoire
    courant. C'est ce qui permet à `verify` de retrouver les fichiers quel que
    soit l'endroit où vous lancez la commande, tant que vous précisez `-data`.

---

## Étape 2 — Inspecter la base produite

```bash
bash hash-tool stats -base ./examples/workspace/bases/hashes__data-source.b3
```

Sortie attendue :

```
Base : hashes__data-source.b3
Fichiers : 4
Créée le : 2026-02-28T...
Commentaire : Audit initial T1
Algorithme : blake3
```

---

## Étape 3 — Vérifier l'intégrité (cas nominal)

```bash
bash hash-tool verify \
  -base ./examples/workspace/bases/hashes__data-source.b3 \
  -data ./examples/workspace/_data-source
```

Sortie attendue :

```
Vérification OK - 4 fichiers intègres.
Résultats dans : ~/integrity_resultats/resultats_hashes__data-source_<date>/
  recap.txt
```

Exit code `0` — aucune anomalie détectée.

---

## Étape 4 — Simuler une altération

Modifiez un fichier du dossier source :

```bash
echo "alteration" >> ./examples/workspace/_data-source/lorem-ipsum-02.txt
```

Relancez la vérification :

```bash
bash hash-tool verify \
  -base ./examples/workspace/bases/hashes__data-source.b3 \
  -data ./examples/workspace/_data-source
```

Sortie attendue :

```
████████████████████████████████████████
  ECHEC : 1 fichier(s) corrompu(s) ou manquant(s)
████████████████████████████████████████

  FAILED : ./lorem-ipsum-02.txt

Résultats dans : ~/integrity_resultats/resultats_hashes__data-source_<date>/
  recap.txt
  failed.txt
```

Exit code `1`.

Remettez le fichier dans son état d'origine :

```bash
git checkout examples/workspace/_data-source/lorem-ipsum-02.txt
```

---

## Étape 5 — Lire les fichiers de résultats

Les résultats sont écrits dans `~/integrity_resultats/resultats_hashes__data-source_<date>/`.

**`recap.txt`** — synthèse de la vérification :

```
STATUT    : ECHEC
OK        : 3
FAILED    : 1  ← voir failed.txt
Base      : hashes__data-source.b3
Dossier   : /chemin/vers/_data-source
Date      : 2026-02-28T...
```

**`failed.txt`** — liste des fichiers en anomalie (présent uniquement si ECHEC) :

```
FAILED : ./lorem-ipsum-02.txt
```

!!! note "ECHEC vs ERREUR"
    `STATUT : ECHEC` = au moins un fichier a un hash différent (corruption, modification).
    `STATUT : ERREUR` = erreur technique (base invalide, `b3sum` en échec, fichier disparu).
    Les deux produisent exit code `1` mais sont distinguables via `recap.txt`.

---

## Ce que vous savez maintenant faire

- Calculer une base d'empreintes avec `compute`
- Inspecter une base avec `stats`
- Vérifier l'intégrité avec `verify`
- Lire `recap.txt` et `failed.txt`
- Distinguer les cas OK / ECHEC / ERREUR

**Étape suivante** : [T2 — Vérifier une migration](02-migration.md) pour comparer
deux dossiers et valider qu'une copie est parfaite.
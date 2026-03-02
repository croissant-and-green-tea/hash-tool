# T2 — Vérifier une migration de données

Objectif : calculer les empreintes d'une source et d'une destination, les comparer,
identifier les fichiers modifiés/disparus/nouveaux, valider la migration. Durée : 20 min.

Les données de test simulent une migration imparfaite :
`examples/workspace/_data-source/` et `examples/workspace/_data-destination/`
contiennent 4 fichiers chacun, dont `lorem-ipsum-01-modif.txt` qui diffère
intentionnellement entre les deux dossiers. Aucune modification manuelle requise.

---

## Étape 1 — Calculer les empreintes de la source

```bash
bash hash-tool compute \
  -data ./examples/workspace/_data-source \
  -save ./examples/workspace/bases \
  -meta "Source - avant migration"
```

Sortie attendue :

```
Base enregistrée : hashes__data-source.b3 (4 fichiers)
Sidecar : hashes__data-source.b3.meta.json
```

---

## Étape 2 — Calculer les empreintes de la destination

```bash
bash hash-tool compute \
  -data ./examples/workspace/_data-destination \
  -save ./examples/workspace/bases \
  -meta "Destination - après migration"
```

Sortie attendue :

```
Base enregistrée : hashes__data-destination.b3 (4 fichiers)
Sidecar : hashes__data-destination.b3.meta.json
```

!!! tip "Sauvegarder les deux bases au même endroit"
    En plaçant les deux bases dans le même dossier `bases/`, la commande `compare`
    peut les referencer facilement. C'est aussi plus simple pour archiver les audits.

---

## Étape 3 — Comparer les deux bases

```bash
bash hash-tool compare \
  -old ./examples/workspace/bases/hashes__data-source.b3 \
  -new ./examples/workspace/bases/hashes__data-destination.b3 \
  -save ./examples/workspace/bases/resultats-migration
```

Sortie attendue :

```
Résultats enregistrés dans : ./examples/workspace/bases/resultats-migration/
  recap.txt     - modifiés: 1, disparus: 0, nouveaux: 0
  modifies.b3   - 1 fichiers
  disparus.txt  - 0 fichiers
  nouveaux.txt  - 0 fichiers
  report.html   - rapport visuel
```

Exit code `0` — `compare` retourne toujours 0, même s'il y a des différences.
Les différences sont à lire dans les fichiers de résultats.

---

## Étape 4 — Lire les résultats

**`recap.txt`** — synthèse chiffrée :

```
Modifiés  : 1
Disparus  : 0
Nouveaux  : 0
Base old  : hashes__data-source.b3
Base new  : hashes__data-destination.b3
Date      : 2026-02-28T...
```

**`modifies.b3`** — fichiers dont le hash a changé entre source et destination :

```
<hash_source>   ./lorem-ipsum-01-modif.txt  [OLD]
<hash_dest>     ./lorem-ipsum-01-modif.txt  [NEW]
```

Les deux hashes sont présents — vous voyez exactement quel fichier a changé
et pouvez calculer son nouveau hash pour vérification manuelle si besoin.

**`disparus.txt`** — fichiers présents dans la source mais absents de la destination.
Vide ici — tous les fichiers ont été transférés.

**`nouveaux.txt`** — fichiers présents dans la destination mais absents de la source.
Vide ici — aucun fichier parasite n'a été ajouté.

**`report.html`** — rapport visuel interactif. Ouvrez-le dans un navigateur pour
une lecture plus confortable sur de grands volumes de fichiers.

---

## Étape 5 — Interpréter et décider

| Résultat | Signification | Action |
|---|---|---|
| Modifiés > 0 | Fichiers altérés pendant le transfert | Identifier et recopier les fichiers concernés |
| Disparus > 0 | Fichiers non transférés | Relancer le transfert pour les fichiers manquants |
| Nouveaux > 0 | Fichiers parasites ajoutés à la destination | Identifier leur origine et les supprimer si non voulus |
| Tout à 0 | Migration parfaite | Valider et archiver les deux bases |

**Critère de validation d'une migration réussie : 0 modifié, 0 disparu, 0 nouveau.**

---

## Variante — Source et destination sur des montages différents

Si source et destination sont sur des disques, machines ou montages différents,
utiliser des chemins absolus :

```bash
bash hash-tool compute \
  -data /mnt/disque-source/donnees \
  -save /mnt/disque-source/bases \
  -meta "Source disque A"

bash hash-tool compute \
  -data /mnt/disque-destination/donnees \
  -save /mnt/disque-source/bases \
  -meta "Destination disque B"

bash hash-tool compare \
  -old /mnt/disque-source/bases/hashes_donnees.b3 \
  -new /mnt/disque-source/bases/hashes_donnees1.b3 \
  -save /mnt/disque-source/resultats
```

!!! warning "Répertoire de travail"
    Les chemins dans les `.b3` sont relatifs au dossier haché au moment du `compute`.
    Si vous comparez deux bases calculées depuis des répertoires de travail différents,
    les chemins ne correspondront pas et `compare` signalera de faux positifs.
    Toujours utiliser des chemins absolus ou lancer `compute` depuis le même
    répertoire parent pour les deux dossiers.

---

## Ce que vous savez maintenant faire

- Calculer deux bases et les comparer avec `compare`
- Lire `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`, `report.html`
- Valider ou invalider une migration sur la base des résultats
- Gérer les cas multi-disques avec des chemins absolus

**Étape suivante** : [T3 — Automatiser avec un pipeline](03-automatisation.md)
pour enchaîner compute + compare en une seule commande reproductible.
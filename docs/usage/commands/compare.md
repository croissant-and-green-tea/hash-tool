# compare

Compare deux bases d'empreintes `.b3` et produit un rapport détaillé des
différences : fichiers modifiés, disparus, nouveaux.

---

## Syntaxe

```bash
bash hash-tool compare -old <ancienne.b3> -new <nouvelle.b3> [-save <dossier>] [-quiet]
```

| Option | Obligatoire | Description |
|---|---|---|
| `-old <ancienne.b3>` | Oui | Base de référence (état de départ) |
| `-new <nouvelle.b3>` | Oui | Base à comparer (état d'arrivée) |
| `-save <dossier>` | Non | Dossier de sortie des résultats. Surcharge `RESULTATS_DIR`. |
| `-quiet` | Non | Supprime toute sortie terminal |

---

## Comportement

1. Lecture et affichage des sidecars des deux bases si présents
2. Diff des ensembles de hashes :
   - **Modifiés** : chemin présent dans les deux bases, hash différent
   - **Disparus** : chemin présent dans `-old`, absent de `-new`
   - **Nouveaux** : chemin absent de `-old`, présent dans `-new`
3. Production des 5 fichiers de résultats dans `RESULTATS_DIR`
4. Affichage du résumé avec les compteurs

---

## Fichiers produits

Les résultats sont écrits dans `RESULTATS_DIR/resultats_<nom_base>_<date>/` :

| Fichier | Description |
|---|---|
| `recap.txt` | Synthèse : compteurs modifiés/disparus/nouveaux, noms des deux bases, date |
| `modifies.b3` | Fichiers dont le hash a changé — format `.b3` avec les deux hashes (OLD et NEW) |
| `disparus.txt` | Fichiers présents dans `-old` mais absents de `-new` |
| `nouveaux.txt` | Fichiers présents dans `-new` mais absents de `-old` |
| `report.html` | Rapport visuel interactif — ouvrir dans un navigateur |

`modifies.b3` contient deux lignes par fichier modifié :

```
<hash_ancien>  ./fichier.txt  [OLD]
<hash_nouveau> ./fichier.txt  [NEW]
```

---

## Codes de sortie

| Code | Signification |
|---|---|
| `0` | Exécution réussie (même s'il y a des différences) |
| `1` | Erreur technique (base introuvable, JSON invalide, etc.) |

!!! note "compare retourne toujours 0 si les bases sont valides"
    Contrairement à `verify`, `compare` ne retourne pas `1` en cas de différences.
    Les différences sont à lire dans `recap.txt`. Pour détecter automatiquement
    des différences en script, lire le compteur dans `recap.txt` :
    ```bash
    bash hash-tool compare -old old.b3 -new new.b3 -save /tmp/res
    modifies=$(grep "Modifiés" /tmp/res/*/recap.txt | awk '{print $NF}')
    [ "$modifies" -gt 0 ] && echo "ALERTE : $modifies fichiers modifiés"
    ```

---

## Exemples

**Comparaison après migration :**

```bash
bash hash-tool compare \
  -old ./bases/hashes_source.b3 \
  -new ./bases/hashes_destination.b3 \
  -save ./resultats/migration-2026-03-01
```

**Vérification d'une migration réussie (0 différences) :**

```bash
bash hash-tool compare \
  -old ./bases/hashes_avant.b3 \
  -new ./bases/hashes_apres.b3
# recap.txt : modifiés: 0, disparus: 0, nouveaux: 0
```

**Mode silencieux pour script :**

```bash
bash hash-tool compare -old old.b3 -new new.b3 -save /tmp/res -quiet
```

---

## Erreurs fréquentes

| Erreur | Cause | Solution |
|---|---|---|
| `compare : -old requis` | Option `-old` manquante | Vérifier la syntaxe |
| `base introuvable : ...` | Chemin incorrect vers le `.b3` | Utiliser `hash-tool list` pour localiser les bases |
| Faux positifs (tout modifié) | Deux bases calculées depuis des CWD différents | Recalculer depuis le même répertoire parent |
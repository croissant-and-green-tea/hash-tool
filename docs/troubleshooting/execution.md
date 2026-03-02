# Troubleshooting - Exécution

Problèmes rencontrés lors de l'exécution de `compute`, `verify` et `compare`.
Pour chaque problème : **Symptôme** -> **Cause** -> **Diagnostic** -> **Solution**.

---

## `verify` échoue sur tous les fichiers alors que rien n'a changé

**Symptôme** : 100% des fichiers en `FAILED`, `failed.txt` liste tous les fichiers
avec `No such file or directory`, pourtant les données sont intactes sur le disque.

**Cause** : la base a été calculée depuis un répertoire de travail différent de celui
utilisé pour `verify`. Les chemins relatifs dans le `.b3` ne correspondent plus au
répertoire courant.

**Diagnostic** :

```bash
# Inspecter les 3 premières lignes de la base
head -3 hashes.b3
```

Si les chemins commencent par `./data/fichier.txt` mais que tu es dans `/home/user/data`,
`b3sum` cherche `./data/fichier.txt` depuis `/home/user/data/` - soit
`/home/user/data/data/fichier.txt`, qui n'existe pas.

```bash
# Afficher le répertoire de travail courant
pwd

# Comparer avec le dossier enregistré dans le sidecar
cat hashes.b3.meta.json | grep directory
```

**Solution** :

```bash
# Option 1 : se positionner dans le bon répertoire avant verify
cd /home/user/projet   # répertoire depuis lequel compute a été lancé
bash src/integrity.sh verify hashes.b3

# Option 2 : passer le dossier explicitement en second argument
bash src/integrity.sh verify /bases/hashes.b3 /home/user/projet
```

**Règle à retenir** : le répertoire de travail au moment du `verify` doit être identique
à celui du `compute`. En cas de doute, le sidecar `.meta.json` indique le dossier source
enregistré lors du compute.

---

## `compute` produit un `.b3` vide ou avec moins de fichiers qu'attendu

**Symptôme** : le fichier `.b3` est créé mais contient 0 ligne, ou un nombre
anormalement bas de fichiers.

**Cause 1 - dossier vide** : le dossier cible ne contient aucun fichier régulier
(uniquement des sous-dossiers vides, ou aucun fichier).

**Cause 2 - permissions insuffisantes** : certains fichiers ne sont pas lisibles
par l'utilisateur courant. `b3sum` les ignore silencieusement.

**Cause 3 - fichiers cachés** : `find` inclut les fichiers cachés (`.git/`, `.DS_Store`).
Si le dossier est un dépôt git, les objets dans `.git/` sont indexés.

**Diagnostic** :

```bash
# Compter les fichiers trouvés par find (même algorithme que compute)
find ./mon-dossier -type f | wc -l

# Vérifier les permissions des fichiers
find ./mon-dossier -type f ! -readable

# Voir quels fichiers sont inclus
find ./mon-dossier -type f | head -20
```

**Solution** :

```bash
# Si le dossier est vide : vérifier le chemin passé à compute
ls -la ./mon-dossier

# Si permissions : corriger ou lancer avec sudo (déconseillé)
chmod -R u+r ./mon-dossier

# Si .git/ indésirable : exclure explicitement via un wrapper
find ./mon-dossier -type f -not -path '*/.git/*' | ...
# Note : integrity.sh n'expose pas d'option d'exclusion native
```

---

## `compare` retourne des milliers de "modifiés" inattendus

**Symptôme** : `modifies.b3` liste des centaines ou milliers de fichiers comme modifiés,
alors que les données n'ont pas changé. `nb_disparus` et `nb_nouveaux` sont aussi
anormalement élevés.

**Cause** : les deux bases ont été calculées depuis des répertoires de travail différents.
Les préfixes de chemins diffèrent, donc `compare` ne peut pas faire correspondre les entrées.

Exemple :
- `hashes_source.b3` : chemins du type `./data/fichier.txt` (compute depuis `/srv`)
- `hashes_dest.b3` : chemins du type `./fichier.txt` (compute depuis `/srv/data`)

Aucun chemin ne correspond - tous les fichiers apparaissent comme "disparus" dans l'une
et "nouveaux" dans l'autre, et donc "modifiés" si les hashes matchent par accident.

**Diagnostic** :

```bash
# Comparer les préfixes des deux bases
head -1 hashes_source.b3
head -1 hashes_dest.b3
```

Si les préfixes diffèrent, c'est la cause.

**Solution** :

```bash
# Recalculer les deux bases depuis le même répertoire parent
# avec le même dossier cible relatif

cd /srv
bash src/integrity.sh compute ./data hashes_source.b3
# ... migration ...
bash src/integrity.sh compute ./data hashes_dest.b3
bash src/integrity.sh compare hashes_source.b3 hashes_dest.b3
```

---

## `verify` retourne exit 1 alors que la vérification est OK

**Symptôme** : la sortie affiche `Vérification OK - N fichiers intègres` mais le code
de sortie est `1`.

**Cause** : bug connu dans les versions antérieures à `2.0.1` - l'expression arithmétique
`(( nb_fail > 0 ))` dans `ui.sh` retourne exit code 1 quand `nb_fail=0` sous `set -e`,
ce qui tue le processus après l'affichage.

**Diagnostic** :

```bash
bash src/integrity.sh verify hashes.b3
echo "exit: $?"
grep "version\|VERSION" src/integrity.sh
```

**Solution** : mettre à jour vers la version corrigée. Le fix est dans `src/lib/ui.sh`,
fonction `ui_show_verify_result` - remplacer :

```bash
# Avant (bugué)
(( nb_fail > 0 )) || [ -n "$lines_err" ] && say "  failed.txt"

# Après (correct)
if [ "$nb_fail" -gt 0 ] || [ -n "$lines_err" ]; then say "  failed.txt"; fi
```

---

## Codes de sortie

| Code | Commande | Signification |
|---|---|---|
| `0` | `compute` | Base créée avec succès |
| `0` | `verify` | Tous les fichiers intègres |
| `0` | `compare` | Comparaison effectuée (même si des différences existent) |
| `1` | `compute` | Erreur - dossier introuvable, vide, ou b3sum en échec |
| `1` | `verify` | Anomalie détectée **ou** erreur technique |
| `1` | `compare` | Erreur technique uniquement (différences = exit 0) |

!!! note "Code 1 sur verify : anomalie ou erreur ?"
    Le code `1` de `verify` couvre deux cas distincts. Pour distinguer :

    ```bash
    bash src/integrity.sh verify hashes.b3
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        statut=$(grep "STATUT" ~/integrity_resultats/resultats_hashes/recap.txt)
        echo "Exit $exit_code - $statut"
        # STATUT : ECHEC  -> corruption détectée (comportement attendu)
        # STATUT : ERREUR -> erreur technique (base invalide, b3sum absent...)
    fi
    ```

---

## Espaces et caractères spéciaux dans les chemins

`b3sum` et `find` gèrent les espaces dans les noms de fichiers via `-print0` et `sort -z`
(séparateur null). Les noms de fichiers avec espaces, apostrophes ou caractères Unicode
sont supportés sans configuration particulière.

En revanche, les arguments passés au shell doivent être quotés :

```bash
# Correct
bash src/integrity.sh compute "./mon dossier" "ma base.b3"

# Incorrect - le shell splitte sur les espaces
bash src/integrity.sh compute ./mon dossier ma base.b3
```

Pour les chemins contenant `$`, `!` ou des backticks, utiliser des guillemets simples :

```bash
bash src/integrity.sh compute './données$2026' hashes.b3
```

---

## `b3sum` lent sur un grand nombre de fichiers

**Comportement normal** : `compute` appelle `b3sum` une fois par fichier. Sur 100 000
fichiers de petite taille, le temps est dominé par le coût de lancement de `b3sum`,
pas par le hachage lui-même.

**Indicateur** : la barre de progression ETA affiche un ETA qui croît au lieu de décroître.

**Solution** : pas de workaround natif dans la version actuelle. Pour les volumes très
importants (> 100 000 fichiers), privilégier Docker sur une machine avec un SSD NVMe.

---

## Voir aussi

- [Troubleshooting - Installation](installation.md)
- [Troubleshooting - Docker](docker.md)
- [Troubleshooting - Pipeline](pipeline.md)
- [Troubleshooting - Résultats](results.md)
- [Formats de fichiers](../reference/file-formats.md) - structure du `.b3` et impact sur les chemins
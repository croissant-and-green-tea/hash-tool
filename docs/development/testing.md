# Tests

---

## Structure

```
tests/
  run_tests.sh           -> tests fonctionnels integrity.sh       (T00-T20)
  run_tests_core.sh      -> tests unitaires src/lib/core.sh       (CU01-CU53)
  run_tests_pipeline.sh  -> tests d'intégration runner.sh         (TP00-TP12)
```

---

## Exécution

### Tous les tests (recommandé)

```bash
make test
```

Équivalent à :

```bash
cd tests && bash run_tests.sh
cd tests && bash run_tests_core.sh
cd tests && bash run_tests_pipeline.sh
```

### Suite individuelle

```bash
cd tests && bash run_tests.sh
cd tests && bash run_tests_core.sh
cd tests && bash run_tests_pipeline.sh
```

### Lint ShellCheck

```bash
make lint
```

Lance ShellCheck sur tous les scripts. Aucun avertissement toléré - tout warning
est traité comme une erreur bloquante.

---

## Suites de tests

### `run_tests.sh` - Tests fonctionnels (T00-T20)

Tests de `integrity.sh` en exécution directe. Couvre :


- `T00` - Permissions : `integrity.sh` est exécutable

- `T01` - `compute` : base créée, chemins relatifs corrects, nb fichiers correct

- `T02` - `compute` : dossier cible inexistant -> erreur

- `T03` - `compute` : dossier vide -> erreur

- `T04` - `verify` : vérification OK, exit 0

- `T05` - `verify` : corruption détectée, exit 1

- `T06` - `verify` : base absente -> erreur

- `T07` - `compare` : fichiers de résultats produits

- `T08` - `compare` : bases identiques -> 0 différences

- `T09` - `compare` : base absente -> erreur

- `T10` - `verify` : argument `[dossier]` explicite

- `T11` - Sidecar : écrit lors du compute, relu lors du verify

- `T12` - Mode `--quiet` : aucune sortie terminal

### `run_tests_core.sh` - Tests unitaires (CU01-CU53)

Tests des fonctions de `src/lib/core.sh` en isolation. Couvre :


- `CU01-CU10` - `core_compute` : hachage correct, ordre déterministe, chemins relatifs

- `CU11-CU20` - `core_verify` : variables `CORE_VERIFY_*` positionnées correctement

- `CU21-CU30` - `core_verify` : compteurs OK/FAIL, statuts OK/ECHEC/ERREUR

- `CU31-CU40` - `core_compare` : détection modifiés/disparus/nouveaux

- `CU41-CU50` - `core_sidecar_write` / `core_sidecar_read` : JSON correct

- `CU51-CU53` - `core_make_result_dir` : horodatage si conflit de nom

### `run_tests_pipeline.sh` - Tests d'intégration (TP00-TP12)

Tests de `runner.sh` avec des pipelines JSON construits à la volée. Couvre :


- `TP00` - Permissions : `integrity.sh` est exécutable

- `TP01` - JSON invalide -> erreur propre sans stacktrace jq

- `TP02` - Fichier `.pipeline` absent -> erreur

- `TP03` - Champ `nom` manquant dans compute -> erreur avec mention du champ

- `TP04` - Opération inconnue -> erreur avec nom de l'opération

- `TP05` - `compute` : répertoire de travail correct, chemins relatifs dans la base

- `TP06` - `compute` : source absente -> erreur, pas de base créée

- `TP07` - `verify` : répertoire de travail correct, vérification OK

- `TP08` - `verify` : corruption détectée

- `TP09` - `verify` : base `.b3` absente -> erreur

- `TP10` - `compare` : fichiers de résultats produits (sans champ `resultats`)

- `TP10b` - `compare` : champ `resultats` personnalisé dans `pipeline.json`

- `TP11` - `compare` : `base_a` absente -> erreur

- `TP12` - Pipeline complet : `compute × 2` + `verify` + `compare`

---

## Données de test

```
examples/workspace/
  _data-source/           -> 4 fichiers lorem-ipsum (source de référence)
  _data-destination/      -> 4 fichiers (1 modifié : lorem-ipsum-01-modif.txt)
  bases/                  -> bases .b3 pré-calculées
  result/                 -> résultats de compare de référence
```

!!! warning "Ne pas modifier ces fichiers"
    Les assertions des suites dépendent de l'état exact de ces fichiers.
    En particulier : `_data-destination/lorem-ipsum-01-modif.txt` doit être
    différent de `_data-source/lorem-ipsum-01.txt` pour que les tests de
    détection de corruption passent.

    Pour réinitialiser après une modification accidentelle :
    ```bash
    git checkout examples/
    ```

---

## Ajouter un test

### Dans `run_tests.sh` ou `run_tests_pipeline.sh`

Les tests utilisent les fonctions `assert_*` définies en tête de chaque script :

```bash
# Exemple d'assertion
assert_file_exists "base créée" "$outdir/hashes.b3"
assert_contains "ERREUR signalée" "$output" "ERREUR"
assert_not_contains "pas de stacktrace" "$output" "parse error"
assert_exit_zero "exit 0" "$exit_code"
assert_exit_nonzero "exit non-zéro" "$exit_code"
```

Ajouter la fonction de test dans le fichier concerné, puis l'appeler dans la
section d'orchestration en bas du script.

### Dans `run_tests_core.sh`

```bash
# Exemple de test unitaire
_cu99_dir=$(mktemp -d)
echo "test" > "$_cu99_dir/f.txt"
core_compute "$_cu99_dir" "$_cu99_dir/out.b3"
if [ -f "$_cu99_dir/out.b3" ]; then
  pass "CU99 base créée"
else
  fail "CU99 base absente"
fi
```

### Bonnes pratiques


- Chaque test crée ses données dans un dossier temporaire (`mktemp -d`) - pas dans `examples/`

- Nettoyer avec `trap "rm -rf $tmpdir" EXIT`

- Tester le code de sortie ET le contenu des fichiers produits

- Préfixer le nom du test avec son identifiant (`TP13`, `CU54`, etc.)

---

## Pièges connus

**`(( ))` sous `set -e`**

Les expressions arithmétiques `(( expr ))` retournent exit 1 quand elles valent zéro.
Dans les tests lancés avec `set -euo pipefail`, cela peut tuer le script de test.
Utiliser `[ "$var" -gt 0 ]` à la place.

**`bash "$RUNNER" "$cfg"` sans `|| true`**

Si `runner.sh` retourne exit 1 (même attendu), le script de test s'arrête.
Toujours capturer le code de sortie explicitement :

```bash
bash "$RUNNER" "$cfg" > "$output_file" 2>&1 || true
exit_code=$?
```

**Permissions**

`integrity.sh` doit être exécutable. Si un commit a perdu le bit exécutable :

```bash
git add --chmod=+x src/integrity.sh
git commit -m "fix: restaurer bit exécutable integrity.sh"
```
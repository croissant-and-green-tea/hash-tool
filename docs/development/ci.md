# CI/CD

Le pipeline CI est défini dans `.github/workflows/ci.yml`. Il se déclenche sur chaque
push et pull request, toutes branches confondues.

---

## Vue d'ensemble

```
push / pull_request
        │
        ├── tests (ubuntu-22.04)  ─┐
        ├── tests (ubuntu-24.04)  ─┼── en parallèle
        ├── docker                ─┘
        │
        └── docs (master uniquement, après tests + docker)
```

---

## Job : `tests`

Tourne en parallèle sur **ubuntu-22.04** et **ubuntu-24.04** (`fail-fast: false` - les deux
contextes vont jusqu'au bout indépendamment).

### Steps

**1. Installer les dépendances**
```bash
sudo apt-get install -y b3sum jq shellcheck
```

**2. Vérifier les prérequis**
```bash
b3sum --version && jq --version && shellcheck --version && bash --version
```

**3. Debug T01** - smoke test minimal hors suite de tests :
```bash
cd /tmp && mkdir -p integrity-debug/data
echo "test" > integrity-debug/data/f.txt
cd integrity-debug
bash .../src/integrity.sh compute ./data base.b3
```
Permet d'identifier les erreurs d'environnement avant de lancer les suites complètes.

**4. T00-T20 - `run_tests.sh`**

Tests fonctionnels de `integrity.sh` : compute, verify, compare, options CLI,
gestion d'erreurs. Lancé avec `bash -x` et `head -200` pour limiter la sortie.

**5. TP01-TP12 - `run_tests_pipeline.sh`**

Tests du pipeline JSON via `runner.sh` : JSON invalide, champs manquants, opérations
inconnues, compute/verify/compare en pipeline, champ `resultats` personnalisé.

**6. CU01-CU53 - `run_tests_core.sh`**

Tests unitaires de `src/lib/core.sh` : `core_compute`, `core_verify`, `core_compare`,
gestion des variables `CORE_VERIFY_*`, cas limites.

**7. ShellCheck**

```bash
shellcheck src/integrity.sh runner.sh src/lib/core.sh src/lib/ui.sh \
           src/lib/report.sh src/lib/results.sh docker/entrypoint.sh \
           tests/run_tests.sh tests/run_tests_pipeline.sh tests/run_tests_core.sh
```
Tout warning ShellCheck est traité comme une erreur bloquante.

**8. Upload artefacts** (`if: always()`)

Les résultats dans `/tmp/integrity-test*/` sont uploadés même en cas d'échec,
avec une rétention de 7 jours. Permet d'inspecter les fichiers produits par les tests.

---

## Job : `docker`

Tourne sur `ubuntu-latest`. Valide que l'image se construit et que les commandes
fondamentales fonctionnent en mode conteneur.

### Steps

**Build**

```bash
docker build -t hash_tool .
```

**Smoke test - version**

```bash
docker run --rm hash_tool version
```

**Smoke test - help**

```bash
docker run --rm hash_tool help
```

**Smoke test - compute via volume**

```bash
mkdir -p /tmp/testdata /tmp/testbases
echo "contenu alpha" > /tmp/testdata/alpha.txt
echo "contenu beta"  > /tmp/testdata/beta.txt
docker run --rm \
  -v /tmp/testdata:/data:ro \
  -v /tmp/testbases:/bases \
  hash_tool compute /data /bases/test.b3
[ -s /tmp/testbases/test.b3 ] || exit 1
```

Vérifie que le fichier `.b3` est produit et non vide sur l'hôte.

**Smoke test - verify via volume**

```bash
docker run --rm \
  -v /tmp/testdata:/data:ro \
  -v /tmp/testbases:/bases:ro \
  -v /tmp/testresultats:/resultats \
  -e RESULTATS_DIR=/resultats \
  hash_tool verify /bases/test.b3 /data
```

**Commande inconnue -> exit non-zéro**

```bash
docker run --rm hash_tool commande_inexistante && exit 1 || true
```

Vérifie que l'entrypoint rejette les commandes non reconnues.

---

## Job : `docs`

Se déclenche uniquement sur **push sur `master`**, après que `tests` et `docker`
aient tous les deux réussi (`needs: [tests, docker]`).

```bash
pip install mkdocs mkdocs-material
mkdocs gh-deploy --force
```

Déploie la documentation sur la branche `gh-pages` -> GitHub Pages.
Ne se déclenche pas sur les branches de feature ni les pull requests.

---

## Reproduire la CI en local

Les jobs CI reproduisent exactement `make test` et `make lint` :

```bash
make lint    # reproduit le job ShellCheck
make test    # reproduit les trois suites de tests
```

Pour reproduire le job Docker :

```bash
docker build -t hash_tool .
docker run --rm hash_tool version
docker run --rm hash_tool help
```

---

## Causes fréquentes d'échec CI

| Symptôme | Cause | Solution |
|---|---|---|
| `integrity.sh non exécutable` (exit 126) | Bit exécutable perdu lors d'un commit | `git add --chmod=+x src/integrity.sh` |
| `(( )) : retourne exit 1` | Expression arithmétique sous `set -e` | Remplacer `(( expr ))` par `[ -gt ]` |
| `/dev/tty: No such device` | Test `/dev/tty` sans TTY en CI | Tester via subshell `( exec >/dev/tty )` |
| `template.html introuvable` | Fichier exclu par `.gitignore` | Vérifier les règles glob (`*temp*`) |
| ShellCheck SC2034 | Variable inter-module non vue par ShellCheck | Ajouter `# shellcheck disable=SC2034` |

---

## Ajouter un test

1. Ajouter le cas dans la suite concernée (`run_tests.sh`, `run_tests_pipeline.sh` ou `run_tests_core.sh`)
2. Vérifier localement avec `make test`
3. Pusher - la CI valide sur les deux OS

Pour un nouveau script de test indépendant, ajouter un step dans `ci.yml` en suivant
la convention existante (`chmod +x` -> `cd tests && ./mon_script.sh`).
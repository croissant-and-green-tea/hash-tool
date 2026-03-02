# Architecture

---

## Structure du code

```
hash-tool                  -> wrapper CLI (point d'entrée utilisateur)
runner.sh                  -> exécuteur de pipelines JSON
src/
  integrity.sh             -> moteur principal (compute, verify, compare)
  lib/
    core.sh                -> fonctions de calcul et vérification BLAKE3
    results.sh             -> écriture des fichiers de résultats
    report.sh              -> génération du rapport HTML
    ui.sh                  -> affichage terminal (couleurs, formatage, quiet mode)
docker/
  entrypoint.sh            -> point d'entrée du conteneur Docker
reports/
  template.html            -> template HTML pour les rapports compare
pipelines/
  pipeline.json            -> exemple de pipeline JSON
examples/
  workspace/               -> données de test et bases de référence
```

---

## Rôle de chaque module

### `hash-tool`

Point d'entrée utilisateur. Responsabilités :


- Détection automatique du mode d'exécution (natif ou Docker)

- Parsing des arguments CLI (`-data`, `-base`, `-old`, `-new`, `-save`, `-meta`, `-quiet`)

- Construction des volumes Docker et dispatch vers `_run_docker_integrity()`

- Écriture du sidecar `.meta.json` en mode natif

- Dispatch vers `integrity.sh` ou `runner.sh`

### `src/integrity.sh`

Orchestrateur principal. Responsabilités :


- Parsing des arguments positionnels (syntaxe directe sans tirets)

- Validation des entrées (`core_assert_b3_valid`, `core_assert_target_valid`)

- Orchestration du flux : appel des fonctions `core.*`, `results.*`, `ui.*`

- Gestion du répertoire de travail (résolution des chemins absolus avant `cd`)

### `src/lib/core.sh`

Couche de calcul pur. Responsabilités :


- `core_compute` : appel `b3sum` fichier par fichier, callback de progression

- `core_verify` : appel `b3sum --check`, parsing des résultats OK/FAILED/ERREUR

- `core_compare` : diff entre deux bases `.b3` (modifiés, disparus, nouveaux)

- `core_sidecar_write` / `core_sidecar_read` : gestion des métadonnées JSON

- `core_make_result_dir` : création du dossier de résultats horodaté

### `src/lib/results.sh`

Écriture des fichiers de résultats. Responsabilités :


- `results_write_verify` : `recap.txt` et `failed.txt`

- `results_write_compare` : `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`

### `src/lib/report.sh`

Génération du rapport HTML. Responsabilités :


- `generate_compare_html` : injection des données dans `reports/template.html` via `awk`

- `_render_html_file_list` : rendu des listes de fichiers en HTML

### `src/lib/ui.sh`

Affichage terminal. Responsabilités :


- `say` : affichage conditionnel (respecte `QUIET`)

- `ui_progress_callback` : barre de progression avec ETA

- `ui_show_verify_result` : affichage du résultat de vérification

- `ui_show_compare_result` : affichage du résumé de comparaison

- Détection `/dev/tty` pour la progression (compatible CI sans TTY)

### `docker/entrypoint.sh`

Point d'entrée du conteneur. Responsabilités :


- Dispatch des commandes (`compute`, `verify`, `compare`, `runner`, `shell`, `help`)

- Vérification des dépendances (`b3sum`, `jq`, `integrity.sh`, `runner.sh`)

- Mode debug interactif (`shell`)

---

## Flux d'exécution natif

```
hash-tool compute -data ./data -save ./bases
  └── cmd_compute()
        ├── _parse_args()
        ├── mkdir -p "$save_dir"
        ├── (sous-shell) cd "$OPT_DATA"
        │     └── _run_integrity compute "$data_abs" "$b3_file"
        │           └── bash integrity.sh compute "$data_abs" "$b3_file"
        │                 └── core_compute()
        │                       └── b3sum fichier par fichier -> hashes.b3
        └── _sidecar_write() -> hashes.b3.meta.json
```

---

## Flux d'exécution Docker

```
hash-tool compute -data ./data -save ./bases
  └── cmd_compute()
        ├── _parse_args()
        ├── mkdir -p "$save_dir"
        ├── (sous-shell) cd "$data_abs"
        │     └── _run_integrity compute "$data_abs" "$b3_file"
        │           └── _run_docker_integrity compute "$data_abs" "$b3_file"
        │                 ├── volumes+=(-v "$data_abs":/data:ro)
        │                 ├── volumes+=(-v "$(dirname $b3_file)":/bases)
        │                 └── docker run --rm "${volumes[@]}" hash_tool compute /data /bases/hashes.b3
        │                       └── entrypoint.sh -> integrity.sh compute /data /bases/hashes.b3
        │                             └── core_compute() -> b3sum -> /bases/hashes.b3
        └── (mode Docker : sidecar déjà écrit par integrity.sh dans le conteneur)
```

---

## Conventions de code

**Bash strict mode** - tous les scripts commencent par `set -euo pipefail`.

!!! warning "Arithmétique sous set -e"

    `(( expression ))` retourne exit code 1 quand l'expression vaut zéro.
    Sous `set -e`, cela tue le script. Toujours utiliser `[ "$var" -gt 0 ]`
    pour les comparaisons entières en dehors d'un `if` explicite.

**Nommage** :


- Fonctions internes : préfixe `_` (ex. `_run_integrity`, `_sidecar_write`)

- Commandes CLI : préfixe `cmd_` (ex. `cmd_compute`, `cmd_verify`)

- Fonctions de bibliothèque : préfixe du module (ex. `core_compute`, `ui_say`)

- Variables globales exportées : `MAJUSCULES` (ex. `CORE_VERIFY_STATUS`, `QUIET`)

**Contrats de fonction** - chaque fonction dans `src/lib/` documente en tête :


- Contrat d'entrée (arguments, préconditions)

- Contrat de sortie (exit code, stdout, variables positionnées)

- Effets de bord (fichiers écrits, variables modifiées dans le scope appelant)

**Répertoire de travail** - les chemins dans les `.b3` sont relatifs au répertoire

de travail au moment du `compute`. `integrity.sh` résout les chemins en absolu
avant tout `cd` pour éviter les invalidations.

---

## Dépendances externes

| Outil | Usage | Requis |
|---|---|---|
| `bash` >= 4 | Interpréteur | Oui |
| `b3sum` | Calcul BLAKE3 | Oui (mode natif) |
| `jq` | Sidecars JSON | Oui (mode natif) |
| `find` | Découverte des fichiers | Oui (fourni par coreutils) |
| `awk` | Injection template HTML | Oui (fourni par système) |
| `docker` | Mode conteneur | Oui (mode Docker uniquement) |
| `shellcheck` | Lint (développement) | Non (CI uniquement) |
| `mkdocs` | Documentation (développement) | Non (CI uniquement) |
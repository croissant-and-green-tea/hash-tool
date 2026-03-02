# Changelog - hash_tool

## [1.8] - 2026-03-01 

### Ajouté

- Option `-fast` sur `compute` : mode batch sans progression ETA.
  Un seul appel `b3sum` pour tous les fichiers au lieu de N appels séquentiels.
  Gain significatif sur les grands volumes (facteur 10x à 100x selon le nombre de fichiers).
  Disponible via CLI (`-fast`), pipeline JSON (`"fast": true` dans `options{}`).

## [1.7] - 2026-02-28

### Corrections de bugs CI

- `src/lib/ui.sh` : test `/dev/tty` via subshell pour éviter ENXIO sous `set -e` sans TTY
- `src/lib/ui.sh` : remplacement de `(( nb_fail > 0 )) || ...` par `if [ -gt ]` dans `ui_show_verify_result`
- `src/lib/core.sh` : remplacement de `elif (( CORE_VERIFY_NB_FAIL > 0 ))` par `[ -gt ]` dans `core_verify`
- `tests/run_tests_pipeline.sh` : ajout de `|| true` sur les appels `runner.sh compare` sous `set -e`
- `reports/template.html` : fichier ajouté au dépôt (exclu à tort par le pattern `*temp*`)
- `.gitignore` : ajout de `!reports/template.html` pour annuler le faux positif du pattern `*temp*`
- `src/lib/core.sh` : restauration du `# shellcheck disable=SC2034` sur `CORE_VERIFY_STATUS`

Racine commune : usage de `(( ))` pour des comparaisons entières sous `set -euo pipefail`.
`(( expr ))` retourne exit code 1 quand l'expression vaut zéro, ce qui déclenche `set -e`.
Remplacé systématiquement par `[ -gt ]` / `[ -eq ]` dans tous les contextes à risque.

## [1.6] - 2026-02-27

Ajout d'un makefile pour simplifier les test, la création du volume docker et la doc. 

### [1.5] - 2026-02-27 

Ajout d'une toute nouvelle doc.

### [1.4] - 2026-02-27 

Modificaton de la doc et du nom des fichiers. 






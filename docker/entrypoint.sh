#!/usr/bin/env bash
# /entrypoint.sh - Point d'entrée Docker pour hash_tool
#
# Dispatche les commandes vers integrity.sh ou runner.sh.
# Toutes les commandes de integrity.sh sont supportées directement.
#
# Exemples :
#   docker run hash_tool help
#   docker run hash_tool compute /data /bases/hashes.b3
#   docker run hash_tool verify  /bases/hashes.b3
#   docker run hash_tool compare /bases/old.b3 /bases/new.b3
#   docker run hash_tool runner  /pipelines/pipeline.json
#   docker run hash_tool runner                              # lit /pipelines/pipeline.json
#   docker run -it hash_tool shell                           # bash interactif (debug)

set -euo pipefail

APP="/app"
INTEGRITY="$APP/src/integrity.sh"
RUNNER="$APP/runner.sh"

# == Aide =====================================================================

print_help() {
  cat <<'EOF'
hash_tool - Vérification d'intégrité BLAKE3

Usage :
  docker run [--rm] [-v ...] hash_tool <commande> [arguments...]

Commandes :
  compute <dossier> <base.b3>       Calcule les hashes d'un dossier
  verify  <base.b3> [dossier]       Vérifie l'intégrité
  compare <ancienne.b3> <nouvelle.b3>  Compare deux bases
  runner  [pipeline.json]           Exécute un pipeline (défaut : /pipelines/pipeline.json)
  shell                             Lance un shell bash interactif (debug)
  help                              Affiche cette aide

Options globales (à placer avant la commande) :
  --quiet                           Supprime la sortie terminal

Volumes conventionnels :
  /data        -> données à hacher        (-v /mes/donnees:/data)
  /bases       -> fichiers .b3            (-v /mes/bases:/bases)
  /pipelines   -> fichiers pipeline.json  (-v /chemin/pipeline.json:/pipelines/pipeline.json)
  /resultats   -> résultats               (-v /mes/resultats:/resultats)

Variable d'environnement :
  RESULTATS_DIR  Dossier de résultats (défaut dans le conteneur : /resultats)

Exemples :
  # Calculer les hashes de /data, stocker dans /bases
  docker run --rm \
    -v /mes/donnees:/data:ro \
    -v /mes/bases:/bases \
    hash_tool compute /data /bases/hashes_$(date +%Y-%m-%d).b3

  # Vérifier depuis le dossier d'origine
  docker run --rm \
    -v /mes/donnees:/data:ro \
    -v /mes/bases:/bases:ro \
    -v /mes/resultats:/resultats \
    hash_tool verify /bases/hashes_2024-01-15.b3 /data

  # Comparer deux snapshots
  docker run --rm \
    -v /mes/bases:/bases:ro \
    -v /mes/resultats:/resultats \
    hash_tool compare /bases/hashes_2024-01-15.b3 /bases/hashes_2024-02-01.b3

  # Pipeline complet depuis un fichier JSON
  docker run --rm \
    -v /mes/donnees:/data:ro \
    -v /mes/bases:/bases \
    -v /mes/resultats:/resultats \
    -v /chemin/vers/pipeline.json:/pipelines/pipeline.json:ro \
    hash_tool runner

  # Mode silencieux (CI/cron)
  docker run --rm \
    -v /mes/donnees:/data:ro \
    -v /mes/bases:/bases:ro \
    -v /mes/resultats:/resultats \
    hash_tool --quiet verify /bases/hashes.b3 /data

EOF
}

# == Vérification des outils ===================================================

check_deps() {
  local ok=1
  command -v b3sum &>/dev/null || { echo "ERREUR : b3sum introuvable" >&2; ok=0; }
  command -v jq    &>/dev/null || { echo "ERREUR : jq introuvable"    >&2; ok=0; }
  [ -f "$INTEGRITY" ]          || { echo "ERREUR : $INTEGRITY introuvable" >&2; ok=0; }
  [ -f "$RUNNER" ]             || { echo "ERREUR : $RUNNER introuvable"    >&2; ok=0; }
  (( ok )) || exit 1
}

# == Dispatch ==================================================================

# Extraire --quiet en tête s'il est présent
QUIET_FLAG=""
if [ "${1:-}" = "--quiet" ]; then
  QUIET_FLAG="--quiet"
  shift
fi

CMD="${1:-help}"
shift || true

case "$CMD" in

  compute|verify|compare)
    check_deps
    exec bash "$INTEGRITY" $QUIET_FLAG "$CMD" "$@"
    ;;

  runner)
    check_deps
    PIPELINE="${1:-/pipelines/pipeline.json}"
    if [ ! -f "$PIPELINE" ]; then
      echo "ERREUR : pipeline.json introuvable : $PIPELINE" >&2
      echo "Monter le fichier avec : -v /chemin/pipeline.json:/pipelines/pipeline.json" >&2
      exit 1
    fi
    exec bash "$RUNNER" "$PIPELINE"
    ;;

  shell|bash)
    echo "hash_tool - shell interactif (debug)"
    echo "  b3sum    : $(b3sum --version 2>/dev/null || echo 'non trouvé')"
    echo "  jq       : $(jq --version 2>/dev/null || echo 'non trouvé')"
    echo "  bash     : $BASH_VERSION"
    echo ""
    exec /bin/bash
    ;;

  help|--help|-h)
    print_help
    ;;

  version|--version|-v)
    echo "hash_tool"
    echo "  b3sum : $(b3sum --version 2>/dev/null || echo 'non trouvé')"
    echo "  jq    : $(jq --version 2>/dev/null || echo 'non trouvé')"
    echo "  bash  : $BASH_VERSION"
    ;;

  check-env)
    echo "hash_tool"
    command -v b3sum &>/dev/null && echo "  b3sum : $(b3sum --version)" || echo "  b3sum : KO"
    command -v jq    &>/dev/null && echo "  jq    : $(jq --version)"    || echo "  jq    : KO"
    echo "  bash  : $BASH_VERSION"
    ;;

  *)
    echo "ERREUR : commande inconnue : '$CMD'" >&2
    echo "Lancer 'docker run hash_tool help' pour la liste des commandes." >&2
    exit 1
    ;;

esac

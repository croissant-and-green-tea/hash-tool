#!/usr/bin/env bash
# integrity.sh - Vérification d'intégrité par hachage BLAKE3
#
# Point d'entrée CLI interne. Orchestre les modules :
#   src/lib/core.sh    - logique métier (hachage, vérification, comparaison, sidecar)
#   src/lib/ui.sh      - interface terminal (affichage, ETA, progression)
#   src/lib/results.sh - écriture des fichiers de résultats
#   src/lib/report.sh  - génération des rapports HTML
#
# Usage :
#   ./integrity.sh [--quiet] [--fast] compute <dossier> <base.b3> [commentaire_sidecar]
#   ./integrity.sh [--quiet]          verify  <base.b3> [dossier]
#   ./integrity.sh [--quiet]          compare <ancienne.b3> <nouvelle.b3>
#
# Options :
#   --quiet   Supprime toute sortie terminal. Écrit uniquement dans les
#             fichiers de résultats. Exit code propagé sans modification.
#   --fast    Mode batch : un seul appel b3sum pour tous les fichiers.
#             Pas de progression ETA. Significativement plus rapide sur
#             les grands volumes. Applicable à compute uniquement.
#
# Sidecar :
#   compute génère automatiquement <base.b3>.meta.json si jq est disponible.
#   Le troisième argument optionnel de compute est un commentaire libre.
#   verify et compare affichent le sidecar si présent (sauf --quiet).
#
# Dépendances : b3sum, bash >= 4, find, sort, awk, comm, join, stat, du, mktemp
#               jq (optionnel - requis pour la génération du sidecar)
#
# Exit codes :
#   0 - succès (voir contrat de chaque mode dans src/lib/core.sh)
#   1 - erreur (argument manquant, fichier introuvable, corruption détectée)

set -euo pipefail

# == Version ====================================================================

INTEGRITY_VERSION="2.0.0"

# == Prérequis bash =============================================================

(( BASH_VERSINFO[0] >= 4 )) || {
  echo "ERREUR : bash >= 4 requis (actuel : $BASH_VERSION)" >&2
  exit 1
}

# == Résolution des chemins =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# == Chargement des modules =====================================================

for _module in ui core results report; do
  _path="$SCRIPT_DIR/lib/${_module}.sh"
  [ -f "$_path" ] || { echo "ERREUR : module introuvable : $_path" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$_path"
done
unset _module _path

# == Parsing des arguments ======================================================

QUIET=0
FAST=0
ARGS=()

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --fast)  FAST=1  ;;
    *)       ARGS+=("$arg") ;;
  esac
done

MODE="${ARGS[0]:-}"
ARG2="${ARGS[1]:-}"
ARG3="${ARGS[2]:-}"
ARG4="${ARGS[3]:-}"   # commentaire sidecar optionnel pour compute

# == Configuration ==============================================================

# Dossier racine des résultats. Peut être surchargé par variable d'environnement.
# runner.sh surcharge cette valeur via export pour isoler les runs de pipeline.
RESULTATS_DIR="${RESULTATS_DIR:-${HOME}/integrity_resultats}"

# == Handlers des modes =========================================================

_run_compute() {
  local target="$ARG2"
  local hashfile="$ARG3"
  local sidecar_comment="${ARG4:-}"

  [ -n "$target"   ] || die "compute : dossier cible manquant.\nUsage : $0 compute <dossier> <base.b3> [commentaire]"
  [ -n "$hashfile" ] || die "compute : fichier de sortie .b3 manquant.\nUsage : $0 compute <dossier> <base.b3> [commentaire]"
  [ ! -d "$hashfile" ] || die "compute : '$hashfile' est un dossier. Le fichier .b3 de sortie doit être un chemin de fichier."

  core_assert_target_valid "$target"

  # Utilise ui_progress_callback uniquement si QUIET == 0 et FAST == 0
  if (( FAST )); then
    core_compute_fast "$target" "$hashfile"
  else
    local callback=""
    (( QUIET )) || callback="ui_progress_callback"
    core_compute "$target" "$hashfile" "$callback"
    ui_progress_clear
  fi

  say "Base enregistrée : $hashfile ($(wc -l < "$hashfile") fichiers)"

  # Sidecar : généré si jq est disponible
  if command -v jq &>/dev/null; then
    core_sidecar_write "$hashfile" "$target" "$sidecar_comment" "$INTEGRITY_VERSION"
    say "Sidecar : ${hashfile}.meta.json"
  fi
}

_run_verify() {
  local b3file="$ARG2"
  local workdir="${ARG3:-}"

  [ -n "$b3file" ] || die "verify : fichier .b3 manquant.\nUsage : $0 verify <base.b3> [dossier]"

  core_assert_b3_valid "$b3file" "base"

  # Résolution du chemin absolu AVANT le cd : un chemin relatif deviendrait
  # invalide après changement de répertoire
  local hashfile_abs
  hashfile_abs="$(cd "$(dirname "$b3file")" && pwd)/$(basename "$b3file")"

  # Affichage du sidecar avant le cd (chemin encore valide)
  (( QUIET )) || core_sidecar_read "$hashfile_abs"

  if [ -n "$workdir" ]; then
    [ -d "$workdir" ] || die "verify : '$workdir' n'est pas un dossier valide."
    cd "$workdir"
  fi

  local outdir
  outdir=$(core_make_result_dir "$hashfile_abs" "$RESULTATS_DIR")

  # core_verify positionne les variables CORE_VERIFY_* dans le scope courant
  local exit_code=0
  core_verify "$hashfile_abs" || exit_code=$?

  results_write_verify \
    "$outdir" "$hashfile_abs" \
    "$CORE_VERIFY_STATUS" "$CORE_VERIFY_NB_OK" "$CORE_VERIFY_NB_FAIL" \
    "$CORE_VERIFY_LINES_FAIL" "$CORE_VERIFY_LINES_ERR"

  ui_show_verify_result \
    "$CORE_VERIFY_STATUS" "$CORE_VERIFY_NB_OK" "$CORE_VERIFY_NB_FAIL" \
    "$CORE_VERIFY_LINES_FAIL" "$CORE_VERIFY_LINES_ERR" \
    "$outdir"

  return $exit_code
}

_run_compare() {
  local old="$ARG2"
  local new="$ARG3"

  [ -n "$old" ] || die "compare : fichier ancienne base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"
  [ -n "$new" ] || die "compare : fichier nouvelle base manquant.\nUsage : $0 compare <ancienne.b3> <nouvelle.b3>"

  core_assert_b3_valid "$old" "ancienne base"
  core_assert_b3_valid "$new" "nouvelle base"

  # Affichage des sidecars avant toute opération
  if (( ! QUIET )); then
    core_sidecar_read "$old"
    core_sidecar_read "$new"
  fi

  local outdir
  outdir=$(core_make_result_dir "$old" "$RESULTATS_DIR")

  # core_compare positionne CORE_COMPARE_NB_* dans le scope courant
  core_compare "$old" "$new" "$outdir"

  results_write_compare \
    "$outdir" "$old" "$new" \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU"

  generate_compare_html \
    "$old" "$new" \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU" \
    "${outdir}/modifies.b3" "${outdir}/disparus.txt" "${outdir}/nouveaux.txt" \
    "${outdir}/report.html"

  ui_show_compare_result \
    "$CORE_COMPARE_NB_MOD" "$CORE_COMPARE_NB_DIS" "$CORE_COMPARE_NB_NOU" \
    "$outdir"
}

# == Dispatch ===================================================================

case "$MODE" in
  compute) _run_compute ;;
  verify)  _run_verify  ;;
  compare) _run_compare ;;
  *)
    cat <<EOF
Usage :
  $0 [--quiet] compute <dossier> <base.b3> [commentaire]
  $0 [--quiet] verify  <base.b3> [dossier]
  $0 [--quiet] compare <ancienne.b3> <nouvelle.b3>

Options :
  --quiet      Silencieux : écrit uniquement dans les fichiers de résultats.

Arguments optionnels :
  [commentaire]  Texte libre stocké dans le sidecar <base.b3>.meta.json (compute uniquement).
                 Nécessite jq.

Note :
  Pour l'interface complète (list, diff, stats, check-env, version, pipeline),
  utiliser hash-tool à la racine du projet.
EOF
    exit 1
    ;;
esac
#!/usr/bin/env bash
# runner.sh - Exécuteur de pipeline integrity.sh depuis pipeline.json
#
# Supporte deux formats de pipeline :
#
#   Format legacy (rétrocompatible) :
#     { "pipeline": [ { "op": "compute", "source": "...", "bases": "...", "nom": "..." }, ... ] }
#
#   Format étendu (recommandé) :
#     { "pipeline": [ {
#         "type":        "compute",
#         "params":      { "input": "...", "output_dir": "...", "filename": "..." },
#         "options":     { "quiet": false, "verbose": false, "readonly": false },
#         "meta":        { "comment": "..." },
#         "description": "Texte explicatif de l'étape"
#       }, ... ] }
#
# Usage :
#   ./runner.sh                          # lit pipelines/pipeline.json
#   ./runner.sh /chemin/pipeline.json    # config explicite
#
# Dépendances : bash >= 4, jq, src/integrity.sh

set -euo pipefail

# == Chemins ===================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/src/integrity.sh"
CONFIG="${1:-$SCRIPT_DIR/pipelines/pipeline.json}"

# == Prérequis =================================================================

(( BASH_VERSINFO[0] >= 4 )) || { echo "ERREUR : bash >= 4 requis" >&2; exit 1; }

command -v jq &>/dev/null  || { echo "ERREUR : jq non trouvé (apt install jq)" >&2; exit 1; }
[ -f "$INTEGRITY" ]        || { echo "ERREUR : src/integrity.sh introuvable : $INTEGRITY" >&2; exit 1; }
[ -f "$CONFIG" ]           || { echo "ERREUR : config introuvable : $CONFIG" >&2; exit 1; }

# == Validation JSON ===========================================================

jq empty "$CONFIG" 2>/dev/null || { echo "ERREUR : JSON invalide : $CONFIG" >&2; exit 1; }

nb_ops=$(jq '.pipeline | length' "$CONFIG")
(( nb_ops > 0 )) || { echo "ERREUR : tableau .pipeline vide ou absent" >&2; exit 1; }

# == Fonctions utilitaires =====================================================

die() { echo "ERREUR : $*" >&2; exit 1; }

# Détecte si un bloc utilise le format legacy ("op") ou étendu ("type")
_bloc_format() {
  local idx="$1"
  local has_op has_type
  has_op=$(jq -r --argjson i "$idx" '.pipeline[$i].op // empty' "$CONFIG")
  has_type=$(jq -r --argjson i "$idx" '.pipeline[$i].type // empty' "$CONFIG")
  if [ -n "$has_type" ]; then
    echo "extended"
  elif [ -n "$has_op" ]; then
    echo "legacy"
  else
    echo "unknown"
  fi
}

# Lit un champ JSON obligatoire dans le format legacy
require_field() {
  local idx="$1" field="$2"
  local val
  val=$(jq -r --argjson i "$idx" '.pipeline[$i].'"$field" "$CONFIG")
  if [ "$val" = "null" ] || [ -z "$val" ]; then
    die "Bloc #$((idx+1)) : champ '$field' manquant ou vide."
  fi
  echo "$val"
}

# Lit un champ JSON optionnel - retourne "" si absent
optional_field() {
  local idx="$1" field="$2"
  local val
  val=$(jq -r --argjson i "$idx" '.pipeline[$i].'"$field // empty" "$CONFIG" 2>/dev/null || true)
  echo "${val:-}"
}

# Lit un champ dans params{} du format étendu (obligatoire)
require_param() {
  local idx="$1" param="$2"
  local val
  val=$(jq -r --argjson i "$idx" ".pipeline[\$i].params.${param} // empty" "$CONFIG" 2>/dev/null || true)
  [ -n "$val" ] || die "Bloc #$((idx+1)) : params.${param} manquant ou vide."
  echo "$val"
}

# Lit un champ dans params{} du format étendu (optionnel)
optional_param() {
  local idx="$1" param="$2"
  local val
  val=$(jq -r --argjson i "$idx" ".pipeline[\$i].params.${param} // empty" "$CONFIG" 2>/dev/null || true)
  echo "${val:-}"
}

# Lit un flag dans options{} du format étendu (retourne 0 si absent/false)
option_flag() {
  local idx="$1" opt="$2"
  local val
  val=$(jq -r --argjson i "$idx" ".pipeline[\$i].options.${opt} // false" "$CONFIG" 2>/dev/null || echo "false")
  [ "$val" = "true" ] && echo 1 || echo 0
}

# Lit le commentaire meta du format étendu
meta_comment() {
  local idx="$1"
  local val
  val=$(jq -r --argjson i "$idx" '.pipeline[$i].meta.comment // empty' "$CONFIG" 2>/dev/null || true)
  echo "${val:-}"
}

# == Opérations - Format legacy ================================================

run_compute_legacy() {
  local i="$1"
  local source bases nom
  source=$(require_field "$i" "source")
  bases=$(require_field "$i" "bases")
  nom=$(require_field "$i" "nom")

  echo "=== COMPUTE : $source ==="
  [ -d "$source" ] || die "Bloc #$((i+1)) compute : dossier source introuvable : $source"

  mkdir -p "$bases"
  local bases_abs
  bases_abs="$(cd "$bases" && pwd)"
  ( cd "$source" && "$INTEGRITY" compute . "$bases_abs/$nom" )
}

run_verify_legacy() {
  local i="$1"
  local source base
  source=$(require_field "$i" "source")
  base=$(require_field "$i" "base")

  echo "=== VERIFY : $source ==="
  [ -d "$source" ] || die "Bloc #$((i+1)) verify : dossier source introuvable : $source"
  [ -f "$base" ]   || die "Bloc #$((i+1)) verify : base .b3 introuvable : $base"

  local base_abs
  base_abs="$(cd "$(dirname "$base")" && pwd)/$(basename "$base")"
  ( cd "$source" && "$INTEGRITY" verify "$base_abs" ) || true
}

run_compare_legacy() {
  local i="$1"
  local base_a base_b
  base_a=$(require_field "$i" "base_a")
  base_b=$(require_field "$i" "base_b")

  echo "=== COMPARE : $(basename "$base_a") vs $(basename "$base_b") ==="
  [ -f "$base_a" ] || die "Bloc #$((i+1)) compare : base_a introuvable : $base_a"
  [ -f "$base_b" ] || die "Bloc #$((i+1)) compare : base_b introuvable : $base_b"

  local resultats_dir
  resultats_dir=$(optional_field "$i" "resultats")

  if [ -n "$resultats_dir" ]; then
    mkdir -p "$resultats_dir"
    local resultats_abs
    resultats_abs="$(cd "$resultats_dir" && pwd)"
    echo "    -> résultats dans : $resultats_abs"
    RESULTATS_DIR="$resultats_abs" "$INTEGRITY" compare "$base_a" "$base_b"
  else
    "$INTEGRITY" compare "$base_a" "$base_b"
  fi
}

# == Opérations - Format étendu ================================================

run_compute_extended() {
  local i="$1"
  local input output_dir filename
  input=$(require_param "$i" "input")
  output_dir=$(require_param "$i" "output_dir")
  filename=$(require_param "$i" "filename")

  local quiet
  quiet=$(option_flag "$i" "quiet")
  local comment
  comment=$(meta_comment "$i")

  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== COMPUTE : $input ==="
  [ -n "$desc" ] && echo "    -> $desc"
  [ -n "$comment" ] && echo "    -> meta: $comment"

  [ -d "$input" ] || die "Bloc #$((i+1)) compute : dossier source introuvable : $input"

  mkdir -p "$output_dir"
  local output_abs
  output_abs="$(cd "$output_dir" && pwd)"

  local quiet_flag=""
  (( quiet )) && quiet_flag="--quiet"

  # shellcheck disable=SC2086
  ( cd "$input" && "$INTEGRITY" $quiet_flag compute . "$output_abs/$filename" )

  # Sidecar : génération si jq disponible et commentaire présent
  local b3_path="${output_abs}/${filename}"
  if [ -f "$b3_path" ] && command -v jq &>/dev/null; then
    local nb_files; nb_files=$(wc -l < "$b3_path" 2>/dev/null || echo 0)
    jq -n \
      --arg version  "hash-tool runner" \
      --arg date     "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg comment  "$comment" \
      --arg dir      "$input" \
      --argjson nb   "$nb_files" \
      '{
        created_by: $version,
        date:       $date,
        comment:    $comment,
        parameters: { directory: $dir, hash_algo: "blake3", nb_files: $nb }
      }' > "${b3_path}.meta.json"
    echo "    -> sidecar : ${b3_path}.meta.json"
  fi
}

run_verify_extended() {
  local i="$1"
  local input base
  input=$(require_param "$i" "input")
  base=$(require_param "$i" "base")

  local quiet; quiet=$(option_flag "$i" "quiet")
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== VERIFY : $input ==="
  [ -n "$desc" ] && echo "    -> $desc"

  [ -d "$input" ] || die "Bloc #$((i+1)) verify : dossier source introuvable : $input"
  [ -f "$base" ]  || die "Bloc #$((i+1)) verify : base .b3 introuvable : $base"

  local base_abs
  base_abs="$(cd "$(dirname "$base")" && pwd)/$(basename "$base")"

  local quiet_flag=""
  (( quiet )) && quiet_flag="--quiet"

  # shellcheck disable=SC2086
  ( cd "$source" && "$INTEGRITY" verify "$base_abs" ) || true
}

run_compare_extended() {
  local i="$1"
  local input ref_base output_dir
  input=$(require_param "$i" "input")
  ref_base=$(require_param "$i" "reference")
  output_dir=$(optional_param "$i" "output_dir")

  local quiet; quiet=$(option_flag "$i" "quiet")
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== COMPARE : $(basename "$ref_base") vs $(basename "$input") ==="
  [ -n "$desc" ] && echo "    -> $desc"

  [ -f "$ref_base" ] || die "Bloc #$((i+1)) compare : référence introuvable : $ref_base"
  [ -f "$input" ]    || die "Bloc #$((i+1)) compare : base courante introuvable : $input"

  local quiet_flag=""
  (( quiet )) && quiet_flag="--quiet"

  if [ -n "$output_dir" ]; then
    mkdir -p "$output_dir"
    local output_abs
    output_abs="$(cd "$output_dir" && pwd)"
    echo "    -> résultats dans : $output_abs"
    # shellcheck disable=SC2086
    RESULTATS_DIR="$output_abs" "$INTEGRITY" $quiet_flag compare "$ref_base" "$input"
  else
    # shellcheck disable=SC2086
    "$INTEGRITY" $quiet_flag compare "$ref_base" "$input"
  fi
}

# Pour les commandes sans effet réel dans le pipeline mais documentées
run_list_extended() {
  local i="$1"
  local input_dir
  input_dir=$(require_param "$i" "input_dir")
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== LIST : $input_dir ==="
  [ -n "$desc" ] && echo "    -> $desc"

  find "$input_dir" -maxdepth 2 -name "*.b3" -type f | sort | while IFS= read -r f; do
    local nb; nb=$(wc -l < "$f" 2>/dev/null || echo "?")
    printf "  %-40s  %6s fichiers\n" "$(basename "$f")" "$nb"
  done
}

run_diff_extended() {
  local i="$1"
  local input ref_dir
  input=$(require_param "$i" "input")
  ref_dir=$(require_param "$i" "reference_dir")
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== DIFF : $(basename "$input") vs $ref_dir ==="
  [ -n "$desc" ] && echo "    -> $desc"
  [ -f "$input" ]  || die "Bloc #$((i+1)) diff : base introuvable : $input"
  [ -d "$ref_dir" ] || die "Bloc #$((i+1)) diff : dossier introuvable : $ref_dir"

  local tmp_base tmp_dir
  tmp_base=$(mktemp)
  tmp_dir=$(mktemp)
  trap 'rm -f "$tmp_base" "$tmp_dir"' EXIT

  awk '{ print substr($0,67) }' "$input" | sort > "$tmp_base"
  local prefix
  prefix=$(awk '{ p=substr($0,67); sub(/[^/]+$/, "", p); print p; exit }' "$input" 2>/dev/null || echo "./")
  find "$ref_dir" -type f | sed "s|^${ref_dir%/}/||" | sed "s|^|${prefix}|" | sort > "$tmp_dir"

  local dis; dis=$(comm -23 "$tmp_base" "$tmp_dir" | wc -l)
  local nou; nou=$(comm -13 "$tmp_base" "$tmp_dir" | wc -l)
  echo "  Disparus : $dis  |  Nouveaux : $nou"

  rm -f "$tmp_base" "$tmp_dir"
  trap - EXIT
}

run_stats_extended() {
  local i="$1"
  local input
  input=$(require_param "$i" "input")
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)

  echo "=== STATS : $(basename "$input") ==="
  [ -n "$desc" ] && echo "    -> $desc"
  [ -f "$input" ] || die "Bloc #$((i+1)) stats : base introuvable : $input"

  local nb; nb=$(wc -l < "$input")
  local sz; sz=$(du -sh "$input" | cut -f1)
  echo "  Fichiers indexés : $nb  |  Taille : $sz"
}

run_checkenv_extended() {
  local i="$1"
  local desc
  desc=$(jq -r --argjson i "$i" '.pipeline[$i].description // empty' "$CONFIG" 2>/dev/null || true)
  echo "=== CHECK-ENV ==="
  [ -n "$desc" ] && echo "    -> $desc"
  command -v b3sum &>/dev/null && echo "  b3sum : OK" || echo "  b3sum : KO"
  command -v jq    &>/dev/null && echo "  jq    : OK" || echo "  jq    : KO"
}

run_version_extended() {
  local i="$1"
  echo "=== VERSION ==="
  command -v b3sum &>/dev/null && b3sum --version || echo "b3sum non disponible"
}

# == Dispatch par bloc =========================================================

dispatch_bloc() {
  local i="$1"
  local fmt
  fmt=$(_bloc_format "$i")

  case "$fmt" in
    legacy)
      local op
      op=$(jq -r --argjson i "$i" '.pipeline[$i].op' "$CONFIG")
      if [ "$op" = "null" ] || [ -z "$op" ]; then
        die "Bloc #$((i+1)) : champ 'op' manquant."
      fi
      case "$op" in
        compute) run_compute_legacy "$i" ;;
        verify)  run_verify_legacy  "$i" ;;
        compare) run_compare_legacy "$i" ;;
        *)       die "Bloc #$((i+1)) : opération inconnue : '$op'" ;;
      esac
      ;;
    extended)
      local type
      type=$(jq -r --argjson i "$i" '.pipeline[$i].type' "$CONFIG")
      case "$type" in
        compute)   run_compute_extended   "$i" ;;
        verify)    run_verify_extended    "$i" ;;
        compare)   run_compare_extended   "$i" ;;
        list)      run_list_extended      "$i" ;;
        diff)      run_diff_extended      "$i" ;;
        stats)     run_stats_extended     "$i" ;;
        check-env) run_checkenv_extended  "$i" ;;
        version)   run_version_extended   "$i" ;;
        runner)    die "Bloc #$((i+1)) : 'runner' imbriqué non supporté." ;;
        *)         die "Bloc #$((i+1)) : type inconnu : '$type'" ;;
      esac
      ;;
    *)
      die "Bloc #$((i+1)) : ni 'op' (legacy) ni 'type' (étendu) trouvé."
      ;;
  esac
}

# == Main ======================================================================

echo "=== PIPELINE DÉMARRÉ : $(date) ==="
echo "=== Config : $CONFIG ($nb_ops opération(s)) ==="
echo ""

for (( i=0; i<nb_ops; i++ )); do
  dispatch_bloc "$i"
  echo ""
done

echo "=== PIPELINE TERMINÉ : $(date) ==="
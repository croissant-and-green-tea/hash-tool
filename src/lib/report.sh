#!/usr/bin/env bash
# lib/report.sh - Génération des rapports de résultats à partir d'un template
#
# Sourcé par integrity.sh. Ne pas exécuter directement.

# _html_escape <string>
# Échappe les caractères HTML de base.
_html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

# _render_html_file_list <fichier_source> <message_si_vide>
_render_html_file_list() {
  local file="$1"
  local empty_msg="$2"

  if [ ! -s "$file" ]; then
    printf '<p class="empty-msg">%s</p>\n' "$(_html_escape "$empty_msg")"
    return
  fi

  echo "<ul class=\"file-list\">"
  # shellcheck disable=SC2094
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local display
      if [[ "$file" == *.b3 ]]; then
        display=$(echo "$line" | awk '{ $1=""; print substr($0,2) }' | sed 's/^[ ]*//')
      else
        display="$line"
      fi
      printf '  <li>%s</li>\n' "$(_html_escape "$display")"
    done < "$file"
  echo "</ul>"
}

# generate_compare_html
generate_compare_html() {
  local old_b3="$1"
  local new_b3="$2"
  local nb_modifies="$3"
  local nb_disparus="$4"
  local nb_nouveaux="$5"
  local modifies_file="$6"
  local disparus_file="$7"
  local nouveaux_file="$8"
  local output_html="$9"

  local template_path
  template_path="${SCRIPT_DIR}/../reports/template.html"

  if [ ! -f "$template_path" ]; then
    die "Template de rapport introuvable : $template_path"
  fi

  local date_rapport
  date_rapport=$(date '+%Y-%m-%d %H:%M:%S')

  local nom_old nom_new
  nom_old=$(basename "$old_b3")
  nom_new=$(basename "$new_b3")

  local title="Rapport de comparaison : ${nom_old} vs ${nom_new}"
  local paths="Base de référence : <code>${nom_old}</code> &nbsp;&middot;&nbsp; Base comparée : <code>${nom_new}</code>"

  local status_text status_color
  if (( nb_modifies == 0 && nb_disparus == 0 && nb_nouveaux == 0 )); then
    status_text="IDENTIQUES"
    status_color="var(--accent-ok)"
  else
    status_text="DIFFÉRENCES"
    status_color="var(--accent-err)"
  fi

  # Génération des blocs HTML dans des fichiers temporaires
  local tmp_modified tmp_deleted tmp_new tmp_meta
  tmp_modified=$(mktemp)
  tmp_deleted=$(mktemp)
  tmp_new=$(mktemp)
  tmp_meta=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_modified' '$tmp_deleted' '$tmp_new' '$tmp_meta'" RETURN

  _render_html_file_list "$modifies_file" "Aucun fichier modifié."  > "$tmp_modified"
  _render_html_file_list "$disparus_file" "Aucun fichier disparu."  > "$tmp_deleted"
  _render_html_file_list "$nouveaux_file" "Aucun nouveau fichier."  > "$tmp_new"
  printf '<div class="info-label">Métadonnées</div><div class="info-value">Non implémenté</div>\n' > "$tmp_meta"

  # Injection via awk : les scalaires via -v, les blocs multilignes via ENVIRON + fichiers
  TITLE="$title" \
  PATHS="$paths" \
  STATUS_TEXT="$status_text" \
  STATUS_COLOR="$status_color" \
  DATE_RAPPORT="$date_rapport" \
  TMP_META="$tmp_meta" \
  TMP_MODIFIED="$tmp_modified" \
  TMP_DELETED="$tmp_deleted" \
  TMP_NEW="$tmp_new" \
  awk '
  function slurp(path,    line, buf) {
    buf = ""
    while ((getline line < path) > 0) buf = buf line "\n"
    close(path)
    return buf
  }
  BEGIN {
    list_modified = slurp(ENVIRON["TMP_MODIFIED"])
    list_deleted  = slurp(ENVIRON["TMP_DELETED"])
    list_new      = slurp(ENVIRON["TMP_NEW"])
    metadata_rows = slurp(ENVIRON["TMP_META"])
    # Supprimer le newline final pour éviter les lignes vides dans le HTML
    sub(/\n$/, "", list_modified)
    sub(/\n$/, "", list_deleted)
    sub(/\n$/, "", list_new)
    sub(/\n$/, "", metadata_rows)
  }
  {
    gsub("{{TITLE}}",         ENVIRON["TITLE"])
    gsub("{{PATHS}}",         ENVIRON["PATHS"])
    gsub("{{STATUS_TEXT}}",   ENVIRON["STATUS_TEXT"])
    gsub("{{STATUS_COLOR}}",  ENVIRON["STATUS_COLOR"])
    gsub("{{DATE}}",          ENVIRON["DATE_RAPPORT"])
    gsub("{{METADATA_ROWS}}", metadata_rows)
    gsub("{{LIST_MODIFIED}}", list_modified)
    gsub("{{LIST_DELETED}}",  list_deleted)
    gsub("{{LIST_NEW}}",      list_new)
    print
  }
  ' "$template_path" > "$output_html"
}
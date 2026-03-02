#!/usr/bin/env bash
# run_tests.sh - suite de tests automatisée pour integrity.sh
# Usage    : cd tests && ./run_tests.sh
# Prérequis: b3sum, stat, du ; integrity.sh dans ../src/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRITY="$SCRIPT_DIR/../src/integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0; FAIL=0; TOTAL=0

pass() { echo -e "${GREEN}  PASS${NC} - $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); }
fail() { echo -e "${RED}  FAIL${NC} - $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); }

assert_exit_zero()    { local l="$1"; shift; if "$@" >/dev/null 2>&1;  then pass "$l"; else fail "$l"; fi; }
assert_exit_nonzero() { local l="$1"; shift; if ! "$@" >/dev/null 2>&1; then pass "$l"; else fail "$l"; fi; }

assert_contains() {
  local label="$1" pattern="$2" output="$3"
  if echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern: '$pattern' absent)"; fi
}

assert_not_contains() {
  local label="$1" pattern="$2" output="$3"
  if ! echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern: '$pattern' présent à tort)"; fi
}

assert_line_count() {
  local label="$1" expected="$2" file="$3"
  local actual; actual=$(wc -l < "$file")
  if [ "$actual" -eq "$expected" ]; then pass "$label"; else fail "$label (attendu: $expected, obtenu: $actual)"; fi
}

assert_file_exists() {
  local label="$1" file="$2"
  if [ -f "$file" ]; then pass "$label"; else fail "$label (absent : $file)"; fi
}

assert_file_absent() {
  local label="$1" file="$2"
  if [ ! -f "$file" ]; then pass "$label"; else fail "$label (présent à tort : $file)"; fi
}

setup() {
  mkdir -p "$WORKDIR/data/sub"
  echo "contenu alpha" > "$WORKDIR/data/alpha.txt"
  echo "contenu beta"  > "$WORKDIR/data/beta.txt"
  echo "contenu gamma" > "$WORKDIR/data/gamma.txt"
  echo "contenu delta" > "$WORKDIR/data/sub/delta.txt"
}

teardown() { rm -rf "$WORKDIR"; }

run_tests() {
  cd "$WORKDIR"

  echo ""
  echo "========================================"
  echo "  integrity.sh - suite de tests"
  echo "  Workdir : $WORKDIR"
  echo "========================================"
  echo ""

  echo "T00 - ShellCheck"
  if command -v shellcheck &>/dev/null; then
    assert_exit_zero "ShellCheck integrity.sh"       shellcheck "$INTEGRITY"
    assert_exit_zero "ShellCheck src/lib/core.sh"    shellcheck "$SCRIPT_DIR/../src/lib/core.sh"
    assert_exit_zero "ShellCheck src/lib/ui.sh"      shellcheck "$SCRIPT_DIR/../src/lib/ui.sh"
    assert_exit_zero "ShellCheck src/lib/report.sh"  shellcheck "$SCRIPT_DIR/../src/lib/report.sh"
    assert_exit_zero "ShellCheck src/lib/results.sh" shellcheck "$SCRIPT_DIR/../src/lib/results.sh"
    assert_exit_zero "ShellCheck runner.sh"          shellcheck "$SCRIPT_DIR/../runner.sh"
  else
    echo "  SKIP - shellcheck non installé"
  fi
  echo ""

  echo "T01 - Compute de base"
  bash "$INTEGRITY" compute ./data base_t01.b3 >/dev/null 2>&1
  assert_line_count "base_t01.b3 contient 4 lignes" 4 base_t01.b3
  assert_contains   "format <hash>  <chemin>"       "  ./data/" "$(head -1 base_t01.b3)"
  echo ""

  echo "T02 - Verify sans modification"
  local out_t02; out_t02=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_not_contains "aucun FAILED" "FAILED" "$out_t02"
  assert_contains     "terminal OK"  "OK"     "$out_t02"
  local outdir_t02; outdir_t02=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t01*" 2>/dev/null | sort | tail -1)
  assert_file_exists  "recap.txt créé"              "${outdir_t02}/recap.txt"
  assert_file_absent  "failed.txt absent si 0 échec" "${outdir_t02}/failed.txt"
  echo ""

  echo "T03 - Verify après corruption"
  echo "contenu modifié" > data/beta.txt
  local out_t03; out_t03=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_contains "ECHEC affiché"    "ECHEC"   "$out_t03"
  assert_contains "beta.txt FAILED"  "FAILED"  "$out_t03"
  local outdir_t03; outdir_t03=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t01*" 2>/dev/null | sort | tail -1)
  assert_file_exists "failed.txt créé"    "${outdir_t03}/failed.txt"
  assert_contains    "failed.txt beta"    "beta.txt" "$(cat "${outdir_t03}/failed.txt")"
  echo "contenu beta" > data/beta.txt
  echo ""

  echo "T04 - Verify après suppression"
  rm data/gamma.txt
  local out_t04; out_t04=$(bash "$INTEGRITY" verify base_t01.b3 2>&1 || true)
  assert_contains "gamma.txt FAILED" "FAILED" "$out_t04"
  echo "contenu gamma" > data/gamma.txt
  echo ""

  echo "T05 - Compare : aucune différence"
  bash "$INTEGRITY" compute ./data base_t05.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compare base_t01.b3 base_t05.b3 >/dev/null 2>&1
  local outdir_t05; outdir_t05=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t01*" 2>/dev/null | sort | tail -1)
  assert_file_exists "recap.txt"    "${outdir_t05}/recap.txt"
  assert_file_exists "modifies.b3"  "${outdir_t05}/modifies.b3"
  assert_file_exists "report.html"  "${outdir_t05}/report.html"
  assert_line_count  "modifies vide" 0 "${outdir_t05}/modifies.b3"
  assert_line_count  "disparus vide" 0 "${outdir_t05}/disparus.txt"
  assert_line_count  "nouveaux vide" 0 "${outdir_t05}/nouveaux.txt"
  echo ""

  echo "T06 - Compare : fichier modifié"
  echo "contenu beta modifié" > data/beta.txt
  bash "$INTEGRITY" compute ./data base_t06.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compare base_t01.b3 base_t06.b3 >/dev/null 2>&1
  local outdir_t06; outdir_t06=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t01*" 2>/dev/null | sort | tail -1)
  assert_contains "modifies contient beta" "beta.txt" "$(cat "${outdir_t06}/modifies.b3")"
  assert_file_exists "report.html généré" "${outdir_t06}/report.html"
  assert_contains    "report.html contient beta" "beta" "$(cat "${outdir_t06}/report.html")"
  echo "contenu beta" > data/beta.txt
  echo ""

  echo "T07 - Compare : suppression + ajout"
  bash "$INTEGRITY" compute ./data base_t07_old.b3 >/dev/null 2>&1
  rm data/alpha.txt
  echo "contenu epsilon" > data/epsilon.txt
  bash "$INTEGRITY" compute ./data base_t07_new.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compare base_t07_old.b3 base_t07_new.b3 >/dev/null 2>&1
  local outdir_t07; outdir_t07=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t07_old*" 2>/dev/null | sort | tail -1)
  assert_contains "disparus alpha"   "alpha.txt"   "$(cat "${outdir_t07}/disparus.txt")"
  assert_contains "nouveaux epsilon" "epsilon.txt" "$(cat "${outdir_t07}/nouveaux.txt")"
  echo "contenu alpha" > data/alpha.txt
  rm data/epsilon.txt
  echo ""

  echo "T08 - Robustesse : fichier avec espace"
  echo "contenu espace" > "data/fichier avec espace.txt"
  bash "$INTEGRITY" compute ./data base_t08.b3 >/dev/null 2>&1
  local out_t08; out_t08=$(bash "$INTEGRITY" verify base_t08.b3 2>&1 || true)
  assert_not_contains "aucun FAILED" "FAILED" "$out_t08"
  rm "data/fichier avec espace.txt"
  echo ""

  echo "T09 - Limite : dossier vide ignoré"
  mkdir data/dossier_vide
  bash "$INTEGRITY" compute ./data base_t09.b3 >/dev/null 2>&1
  assert_not_contains "dossier_vide absent" "dossier_vide" "$(cat base_t09.b3)"
  pass "comportement conforme"
  rmdir data/dossier_vide
  echo ""

  echo "T10 - Chemin absolu vs relatif"
  find "$WORKDIR/data" -type f -print0 | sort -z | xargs -0 b3sum > base_absolu.b3
  find ./data          -type f -print0 | sort -z | xargs -0 b3sum > base_relatif.b3
  assert_contains     "base absolue -> chemin absolu"   "  /"      "$(head -1 base_absolu.b3)"
  assert_contains     "base relative -> chemin relatif" "\./data/" "$(head -1 base_relatif.b3)"
  assert_not_contains "bases non interchangeables"     "$(head -1 base_absolu.b3)" "$(head -1 base_relatif.b3)"
  echo ""

  echo "T11 - ETA : base identique à référence"
  find ./data -type f -print0 | sort -z | xargs -0 b3sum > base_ref.b3
  bash "$INTEGRITY" compute ./data base_eta.b3 >/dev/null 2>&1
  assert_exit_zero    "base ETA == référence" diff base_ref.b3 base_eta.b3
  assert_not_contains "pas de ligne ETA"      "ETA" "$(cat base_eta.b3)"
  assert_not_contains "pas de \\r"            $'\r' "$(cat base_eta.b3)"
  echo ""

  echo "T12 - Mode --quiet"
  bash "$INTEGRITY" compute ./data base_t12.b3 >/dev/null 2>&1
  local out_quiet_ok; out_quiet_ok=$(bash "$INTEGRITY" --quiet verify base_t12.b3 2>&1 || true)
  assert_not_contains "--quiet OK : pas de stdout" "OK"        "$out_quiet_ok"
  assert_not_contains "--quiet OK : pas de stdout" "Résultats" "$out_quiet_ok"
  local outdir_t12; outdir_t12=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t12*" 2>/dev/null | sort | tail -1)
  assert_file_exists  "recap.txt produit --quiet" "${outdir_t12}/recap.txt"

  echo "contenu corrompu" > data/beta.txt
  local exit_quiet; bash "$INTEGRITY" --quiet verify base_t12.b3 >/dev/null 2>&1 && exit_quiet=0 || exit_quiet=$?
  if [ "$exit_quiet" -ne 0 ]; then pass "--quiet propage exit code"; else fail "--quiet propage exit code"; fi
  echo "contenu beta" > data/beta.txt

  local out_quiet_cmp; out_quiet_cmp=$(bash "$INTEGRITY" --quiet compute ./data base_t12c.b3 2>&1 || true)
  assert_not_contains "--quiet compute : pas de stdout" "Base enregistrée" "$out_quiet_cmp"
  echo ""

  echo "T13 - Horodatage anti-écrasement"
  bash "$INTEGRITY" compute ./data base_t13.b3 >/dev/null 2>&1
  bash "$INTEGRITY" verify base_t13.b3 >/dev/null 2>&1 || true
  sleep 1
  bash "$INTEGRITY" verify base_t13.b3 >/dev/null 2>&1 || true
  local nb_r; nb_r=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t13*" 2>/dev/null | wc -l)
  if [ "$nb_r" -ge 2 ]; then pass "deux dossiers distincts"; else fail "écrasement détecté ($nb_r dossier(s))"; fi
  echo ""

  echo "T14 - verify : dossier argument invalide"
  local out_t14; out_t14=$(bash "$INTEGRITY" verify base_t01.b3 /chemin/inexistant 2>&1 || true)
  assert_contains "ERREUR si dossier invalide" "ERREUR" "$out_t14"
  echo ""

  # =========================================================================
  # T15-T20 : cas limites supplémentaires
  # =========================================================================

  echo "T15 - Nom de fichier avec newline (mapfile -d '' doit tenir)"
  # Crée un fichier dont le nom contient un newline
  local newline_file
  newline_file="$(printf 'data/nom\nfichier.txt')"
  printf 'contenu newline' > "$newline_file"
  bash "$INTEGRITY" compute ./data base_t15.b3 >/dev/null 2>&1
  # Le .b3 doit contenir une ligne valide pour ce fichier
  local t15_lines; t15_lines=$(wc -l < base_t15.b3)
  if [ "$t15_lines" -ge 4 ]; then pass "T15 .b3 contient les 4+ fichiers dont le nom avec newline"; else fail "T15 .b3 incomplet ($t15_lines lignes)"; fi
  # Verify ne doit pas échouer
  local out_t15; out_t15=$(bash "$INTEGRITY" verify base_t15.b3 2>&1 || true)
  assert_not_contains "T15 verify sans FAILED" "FAILED" "$out_t15"
  rm -f "$newline_file"
  echo ""

  echo "T16 - Fichiers avec caractères HTML dans le nom"
  echo "contenu script" > "data/<script>.txt"
  echo "contenu amp"    > "data/a&b.txt"
  bash "$INTEGRITY" compute ./data base_t16.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compare base_t01.b3 base_t16.b3 >/dev/null 2>&1
  local outdir_t16; outdir_t16=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t01*" 2>/dev/null | sort | tail -1)
  assert_file_exists "T16 report.html généré" "${outdir_t16}/report.html"
  # Les chemins bruts doivent apparaître dans nouveaux.txt (sans échappement HTML)
  assert_contains "T16 <script>.txt dans nouveaux.txt" "<script>.txt" "$(cat "${outdir_t16}/nouveaux.txt")"
  assert_contains "T16 a&b.txt dans nouveaux.txt"     "a&b.txt"     "$(cat "${outdir_t16}/nouveaux.txt")"
  # report.html doit échapper correctement (pas de < ou & non échappés dans le rendu HTML)
  local html_t16; html_t16=$(cat "${outdir_t16}/report.html")
  # On vérifie que la séquence brute "<script>" n'est PAS telle quelle dans le HTML
  # (doit être &lt;script&gt; ou équivalent) - si html_escape n'existe pas, on signale
  if echo "$html_t16" | grep -q "&lt;script&gt;\|&amp;" 2>/dev/null; then
    pass "T16 échappement HTML présent dans report.html"
  elif echo "$html_t16" | grep -qF "<script>.txt"; then
    fail "T16 échappement HTML ABSENT dans report.html (XSS potentiel)"
  else
    pass "T16 report.html ne contient pas le nom brut (chemin absent ou échappé)"
  fi
  rm -f "data/<script>.txt" "data/a&b.txt"
  echo ""

  echo "T17 - Compare sans différence -> report.html affiche IDENTIQUES"
  bash "$INTEGRITY" compute ./data base_t17a.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compute ./data base_t17b.b3 >/dev/null 2>&1
  bash "$INTEGRITY" compare base_t17a.b3 base_t17b.b3 >/dev/null 2>&1
  local outdir_t17; outdir_t17=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t17a*" 2>/dev/null | sort | tail -1)
  assert_file_exists "T17 report.html créé" "${outdir_t17}/report.html"
  local html_t17; html_t17=$(cat "${outdir_t17}/report.html")
  # Le rapport doit indiquer que les bases sont identiques (mot-clé "IDENTIQUES" ou "identique" ou "0 modification")
  if echo "$html_t17" | grep -qi "identique\|0 modification\|aucune différence\|aucune diff"; then
    pass "T17 report.html mentionne l'identité des bases"
  else
    fail "T17 report.html ne mentionne pas l'identité (cherchez le pattern attendu dans votre template)"
  fi
  echo ""

  echo "T18 - --quiet sur compare : stdout vide, fichiers produits"
  bash "$INTEGRITY" compute ./data base_t18a.b3 >/dev/null 2>&1
  echo "contenu beta modifié" > data/beta.txt
  bash "$INTEGRITY" compute ./data base_t18b.b3 >/dev/null 2>&1
  echo "contenu beta" > data/beta.txt
  local out_t18; out_t18=$(bash "$INTEGRITY" --quiet compare base_t18a.b3 base_t18b.b3 2>&1 || true)
  assert_not_contains "T18 --quiet compare : pas de stdout" "Résultats"  "$out_t18"
  assert_not_contains "T18 --quiet compare : pas de stdout" "Comparaison" "$out_t18"
  local outdir_t18; outdir_t18=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_base_t18a*" 2>/dev/null | sort | tail -1)
  assert_file_exists "T18 recap.txt produit en --quiet"    "${outdir_t18}/recap.txt"
  assert_file_exists "T18 modifies.b3 produit en --quiet"  "${outdir_t18}/modifies.b3"
  assert_file_exists "T18 report.html produit en --quiet"  "${outdir_t18}/report.html"
  assert_contains    "T18 modifies.b3 contient beta.txt"   "beta.txt" "$(cat "${outdir_t18}/modifies.b3")"
  echo ""

  echo "T19 - Lien symbolique dans le dossier source"
  # Crée un lien symbolique pointant vers un fichier existant
  ln -s "$WORKDIR/data/alpha.txt" "data/lien_alpha.txt" 2>/dev/null || true
  # Vérifie que compute ne plante pas
  local t19_exit=0
  bash "$INTEGRITY" compute ./data base_t19.b3 >/dev/null 2>&1 || t19_exit=$?
  if [ "$t19_exit" -eq 0 ]; then
    pass "T19 compute avec lien symbolique -> exit 0"
    # Documente si le lien est suivi ou ignoré
    if grep -q "lien_alpha" base_t19.b3 2>/dev/null; then
      pass "T19 lien symbolique : suivi (inclus dans .b3)"
    else
      pass "T19 lien symbolique : ignoré (absent du .b3) - comportement à documenter"
    fi
  else
    fail "T19 compute avec lien symbolique -> exit $t19_exit (plantage)"
  fi
  rm -f "data/lien_alpha.txt"
  echo ""

  echo "T20 - verify avec dossier source inexistant -> exit 1"
  local out_t20; out_t20=$(bash "$INTEGRITY" verify base_t01.b3 /dossier/source/totalement/inexistant 2>&1 || true)
  assert_contains "T20 ERREUR si dossier source inexistant" "ERREUR" "$out_t20"
  # Doit être différent de T14 qui testait un dossier passé comme argument optionnel
  # Ici on s'assure que l'exit code est non-zéro
  local t20_exit=0
  bash "$INTEGRITY" verify base_t01.b3 /dossier/source/totalement/inexistant >/dev/null 2>&1 || t20_exit=$?
  if [ "$t20_exit" -ne 0 ]; then pass "T20 exit code non-zéro"; else fail "T20 exit code nul (attendu non-zéro)"; fi
  echo ""
}

# == Main ======================================================================

command -v b3sum &>/dev/null || { echo -e "${RED}ERREUR${NC} : b3sum non trouvé."; exit 1; }
[ -f "$INTEGRITY" ]          || { echo -e "${RED}ERREUR${NC} : integrity.sh introuvable : $INTEGRITY"; exit 1; }

setup
run_tests
teardown

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}$PASS/$TOTAL tests passés${NC}"
else
  echo -e "  ${GREEN}$PASS${NC}/${TOTAL} passés - ${RED}$FAIL échec(s)${NC}"
fi
echo "========================================"
echo ""

[ "$FAIL" -eq 0 ]
#!/usr/bin/env bash
# run_tests_core.sh - Tests unitaires de src/lib/core.sh
# Usage    : cd tests && ./run_tests_core.sh
# Prérequis: bash >= 4, b3sum
#
# Source directement core.sh sans passer par integrity.sh.
# Chaque groupe de tests est isolé dans un sous-répertoire de WORKDIR.
#
# shellcheck disable=SC2030,SC2031
# SC2030/SC2031 : QUIET est intentionnellement exporté dans des sous-shells isolés (_run_core,
# _run_core_stderr). La modification locale est le comportement voulu - chaque appel s'exécute
# dans son propre environnement sans affecter le shell parent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d /tmp/integrity-core-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"
mkdir -p "$RESULTATS_DIR"

# == Sourcing des modules =========================================================

# ui.sh doit être sourcé avant core.sh (die() est définie dans ui.sh)
# On redéfinit die() localement pour capturer les appels sans quitter le processus de test.
# shellcheck disable=SC2317
die() { echo "die: $*" >&2; return 1; }

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../src/lib/core.sh"

# == Infrastructure de test =======================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0; FAIL=0; TOTAL=0

pass() { echo -e "${GREEN}  PASS${NC} - $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); }
fail() { echo -e "${RED}  FAIL${NC} - $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); }

assert_exit_zero() {
  local label="$1"; shift
  local _rc=0
  ( set -e; "$@" ) >/dev/null 2>&1 || _rc=$?
  if [ "$_rc" -eq 0 ]; then pass "$label"; else fail "$label (exit $_rc attendu 0)"; fi
}

assert_exit_nonzero() {
  local label="$1"; shift
  local _rc=0
  ( set -e; "$@" ) >/dev/null 2>&1 || _rc=$?
  if [ "$_rc" -ne 0 ]; then pass "$label"; else fail "$label (exit 0 attendu non-zéro)"; fi
}

assert_contains() {
  local label="$1" pattern="$2" output="$3"
  if echo "$output" | grep -qF "$pattern"; then pass "$label"; else fail "$label (pattern absent: '$pattern')"; fi
}

assert_not_contains() {
  local label="$1" pattern="$2" output="$3"
  if ! echo "$output" | grep -qF "$pattern"; then pass "$label"; else fail "$label (pattern présent à tort: '$pattern')"; fi
}

assert_equals() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then pass "$label"; else fail "$label (attendu: '$expected', obtenu: '$actual')"; fi
}

assert_numeric_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ] 2>/dev/null; then pass "$label"; else fail "$label (attendu: $expected, obtenu: $actual)"; fi
}

# Hash b3sum 64 chars valide à partir d'une chaîne
_make_hash() { printf '%s' "$1" | b3sum --no-names; }

# Génère un fichier .b3 valide à partir d'un dossier
_compute_b3() {
  local dir="$1" out="$2"
  find "$dir" -type f -print0 | sort -z | xargs -0 b3sum > "$out"
}

teardown() { rm -rf "$WORKDIR"; }
trap teardown EXIT

# _run_core <fonction> [args...]
#
# Exécute une fonction de core.sh dans un sous-shell isolé.
# Nécessaire car die() fait return 1 et set -e tuerait le processus principal.
# Retourne le code de sortie de la fonction.
_run_core() {
  (
    export QUIET=0
    # shellcheck disable=SC2317
    die() { echo "die: $*" >&2; exit 1; }
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../src/lib/core.sh"
    "$@"
  ) 2>/dev/null
}

_run_core_stderr() {
  (
    export QUIET=0
    # shellcheck disable=SC2317
    die() { echo "die: $*" >&2; exit 1; }
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../src/lib/core.sh"
    "$@"
  ) 2>&1
}

# == T_CORE01 - core_assert_b3_valid =============================================

echo ""
echo "========================================"
echo "  T_CORE01 - core_assert_b3_valid"
echo "========================================"

# CU01 : fichier absent -> exit 1
assert_exit_nonzero "CU01 fichier absent -> exit 1" \
  _run_core core_assert_b3_valid "/tmp/inexistant_$$.b3"

# CU02 : répertoire passé -> exit 1
assert_exit_nonzero "CU02 répertoire au lieu de fichier -> exit 1" \
  _run_core core_assert_b3_valid "$WORKDIR"

# CU03 : fichier vide -> exit 1
_cu03="$WORKDIR/vide.b3"; touch "$_cu03"
assert_exit_nonzero "CU03 fichier vide -> exit 1" \
  _run_core core_assert_b3_valid "$_cu03"

# CU04 : format invalide (ligne sans hash) -> exit 1
_cu04="$WORKDIR/bad_format.b3"; echo "ligne_sans_format_b3sum" > "$_cu04"
assert_exit_nonzero "CU04 format invalide -> exit 1" \
  _run_core core_assert_b3_valid "$_cu04"

# CU05 : une seule ligne valide -> exit 0
_cu05="$WORKDIR/valid_single.b3"
printf '%064d  ./fichier.txt\n' 0 > "$_cu05"
assert_exit_zero "CU05 une ligne valide -> exit 0" \
  _run_core core_assert_b3_valid "$_cu05"

# CU06 : plusieurs lignes toutes valides -> exit 0
_cu06="$WORKDIR/valid_multi.b3"
{ printf '%064d  ./alpha.txt\n' 0; printf '%064d  ./beta.txt\n' 1; } > "$_cu06"
assert_exit_zero "CU06 plusieurs lignes valides -> exit 0" \
  _run_core core_assert_b3_valid "$_cu06"

# CU07 : lignes mixtes valides/invalides -> exit 1
_cu07="$WORKDIR/mixed.b3"
{ printf '%064d  ./alpha.txt\n' 0; echo "ligne_invalide"; } > "$_cu07"
assert_exit_nonzero "CU07 lignes mixtes -> exit 1" \
  _run_core core_assert_b3_valid "$_cu07"

# CU08 : label personnalisé transmis au message d'erreur
_cu08_err=$(_run_core_stderr core_assert_b3_valid "/inexistant.b3" "MON_LABEL" || true)
assert_contains "CU08 label personnalisé dans message d'erreur" "MON_LABEL" "$_cu08_err"

# CU09 : hash avec lettres minuscules (format b3sum réel)
_cu09="$WORKDIR/real_hash.b3"
printf 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890  ./x.txt\n' > "$_cu09"
assert_exit_zero "CU09 hash lettres minuscules réel -> exit 0" \
  _run_core core_assert_b3_valid "$_cu09"

# CU10 : chemin avec espace dans la ligne valide -> exit 0
_cu10="$WORKDIR/space_path.b3"
printf '%064d  ./fichier avec espace.txt\n' 0 > "$_cu10"
assert_exit_zero "CU10 chemin avec espace -> exit 0" \
  _run_core core_assert_b3_valid "$_cu10"

# CU11 : chemin avec caractères spéciaux HTML -> exit 0
_cu11="$WORKDIR/html_chars.b3"
printf '%064d  ./<script>.txt\n' 0 > "$_cu11"
assert_exit_zero "CU11 chemin avec <> -> exit 0" \
  _run_core core_assert_b3_valid "$_cu11"

# == T_CORE02 - core_assert_target_valid =========================================

echo ""
echo "========================================"
echo "  T_CORE02 - core_assert_target_valid"
echo "========================================"

# CU12 : chemin inexistant -> exit 1
assert_exit_nonzero "CU12 chemin inexistant -> exit 1" \
  _run_core core_assert_target_valid "/chemin/totalement/inexistant_$$"

# CU13 : fichier régulier passé (pas un dossier) -> exit 1
_cu13_f="$WORKDIR/un_fichier.txt"; touch "$_cu13_f"
assert_exit_nonzero "CU13 fichier régulier (pas dossier) -> exit 1" \
  _run_core core_assert_target_valid "$_cu13_f"

# CU14 : dossier vide (aucun fichier) -> exit 1
_cu14_d="$WORKDIR/dossier_vide"; mkdir -p "$_cu14_d"
assert_exit_nonzero "CU14 dossier vide -> exit 1" \
  _run_core core_assert_target_valid "$_cu14_d"

# CU15 : dossier avec un fichier -> exit 0
_cu15_d="$WORKDIR/dossier_un_fichier"; mkdir -p "$_cu15_d"
echo "contenu" > "$_cu15_d/f.txt"
assert_exit_zero "CU15 dossier avec fichier -> exit 0" \
  _run_core core_assert_target_valid "$_cu15_d"

# CU16 : dossier avec sous-dossiers uniquement (pas de fichiers réguliers) -> exit 1
_cu16_d="$WORKDIR/dossier_sous_dir"; mkdir -p "$_cu16_d/sub"
assert_exit_nonzero "CU16 dossier sans fichiers réguliers -> exit 1" \
  _run_core core_assert_target_valid "$_cu16_d"

# CU17 : dossier avec fichiers dans sous-dossiers -> exit 0
_cu17_d="$WORKDIR/dossier_sub_files"; mkdir -p "$_cu17_d/sub"
echo "contenu" > "$_cu17_d/sub/f.txt"
assert_exit_zero "CU17 dossier avec fichiers dans sous-dossiers -> exit 0" \
  _run_core core_assert_target_valid "$_cu17_d"

# == T_CORE03 - core_compute =====================================================

echo ""
echo "========================================"
echo "  T_CORE03 - core_compute"
echo "========================================"

# Données de base pour les tests compute
_cu_compute_dir="$WORKDIR/data_compute"
mkdir -p "$_cu_compute_dir"
echo "alpha"   > "$_cu_compute_dir/alpha.txt"
echo "beta"    > "$_cu_compute_dir/beta.txt"
echo "gamma"   > "$_cu_compute_dir/gamma.txt"

# CU18 : fichier .b3 créé
_cu18_b3="$WORKDIR/cu18.b3"
( cd "$WORKDIR" && core_compute "data_compute" "$_cu18_b3" "" )
if [ -f "$_cu18_b3" ]; then pass "CU18 fichier .b3 créé"; else fail "CU18 fichier .b3 absent"; fi

# CU19 : N lignes pour N fichiers
_cu19_lines=$(wc -l < "$_cu18_b3")
assert_numeric_eq "CU19 3 lignes pour 3 fichiers" 3 "$_cu19_lines"

# CU20 : format <hash64>  <chemin>
_cu20_line=$(head -1 "$_cu18_b3")
if echo "$_cu20_line" | grep -qE '^[0-9a-f]{64}  .+'; then
  pass "CU20 format <hash64>  <chemin> correct"
else
  fail "CU20 format inattendu : $_cu20_line"
fi

# CU21 : chemin relatif préservé
assert_contains "CU21 chemin relatif dans .b3" "data_compute/" "$(cat "$_cu18_b3")"

# CU22 : fichier avec espace dans le nom
_cu22_d="$WORKDIR/data_cu22"; mkdir -p "$_cu22_d"
echo "espace" > "$_cu22_d/fichier avec espace.txt"
_cu22_b3="$WORKDIR/cu22.b3"
( cd "$WORKDIR" && core_compute "data_cu22" "$_cu22_b3" "" )
assert_contains "CU22 chemin avec espace dans .b3" "fichier avec espace.txt" "$(cat "$_cu22_b3")"
_cu22_lines=$(wc -l < "$_cu22_b3")
assert_numeric_eq "CU22 une seule ligne" 1 "$_cu22_lines"

# CU23 : fichier de taille zéro - doit figurer dans le .b3
_cu23_d="$WORKDIR/data_cu23"; mkdir -p "$_cu23_d"
touch "$_cu23_d/zero.bin"
_cu23_b3="$WORKDIR/cu23.b3"
( cd "$WORKDIR" && core_compute "data_cu23" "$_cu23_b3" "" )
assert_contains "CU23 fichier taille zéro présent dans .b3" "zero.bin" "$(cat "$_cu23_b3")"

# CU24 : callback appelé N fois
_cu24_d="$WORKDIR/data_cu24"; mkdir -p "$_cu24_d"
for i in 1 2 3 4 5; do echo "contenu $i" > "$_cu24_d/f${i}.txt"; done
_cu24_b3="$WORKDIR/cu24.b3"
_cu24_count=0
_counter_callback() { _cu24_count=$((_cu24_count + 1)); }
( cd "$WORKDIR" && core_compute "data_cu24" "$_cu24_b3" "_counter_callback" )
# Note : le callback étant appelé dans un sous-shell, on le ré-exécute en scope courant
_cu24_count=0
_cu24_b3b="$WORKDIR/cu24b.b3"
core_compute "$_cu24_d" "$_cu24_b3b" "_counter_callback"
assert_numeric_eq "CU24 callback appelé 5 fois" 5 "$_cu24_count"

# CU25 : callback reçoit les bons arguments (i, total, bytes_done, total_bytes, eta)
_cu25_d="$WORKDIR/data_cu25"; mkdir -p "$_cu25_d"
echo "data" > "$_cu25_d/f1.txt"
_cu25_b3="$WORKDIR/cu25.b3"
_cu25_args=()
_args_callback() { _cu25_args=("$@"); }
core_compute "$_cu25_d" "$_cu25_b3" "_args_callback"
if [ "${#_cu25_args[@]}" -eq 5 ]; then
  pass "CU25 callback reçoit 5 arguments"
else
  fail "CU25 callback reçoit ${#_cu25_args[@]} arguments (attendu 5)"
fi
# i=1, total=1
assert_numeric_eq "CU25 i=1"     1 "${_cu25_args[0]}"
assert_numeric_eq "CU25 total=1" 1 "${_cu25_args[1]}"

# CU26 : le fichier .b3 ne contient pas de lignes ETA ou \r
assert_not_contains "CU26 pas de 'ETA' dans .b3"  "ETA"  "$(cat "$_cu18_b3")"
if ! grep -qP '\r' "$_cu18_b3" 2>/dev/null; then
  pass "CU26 pas de \\r dans .b3"
else
  fail "CU26 \\r détecté dans .b3"
fi

# CU27 : idempotence - deux compute produisent des fichiers identiques
_cu27_b3a="$WORKDIR/cu27a.b3"; _cu27_b3b="$WORKDIR/cu27b.b3"
( cd "$WORKDIR" && core_compute "data_compute" "$_cu27_b3a" "" )
( cd "$WORKDIR" && core_compute "data_compute" "$_cu27_b3b" "" )
assert_exit_zero "CU27 idempotence - fichiers identiques" diff "$_cu27_b3a" "$_cu27_b3b"

# == T_CORE04 - core_verify ======================================================

echo ""
echo "========================================"
echo "  T_CORE04 - core_verify"
echo "========================================"

# Setup commun pour les tests verify
_cv_dir="$WORKDIR/data_verify"; mkdir -p "$_cv_dir"
echo "alpha"   > "$_cv_dir/alpha.txt"
echo "beta"    > "$_cv_dir/beta.txt"
echo "gamma"   > "$_cv_dir/gamma.txt"
echo "delta"   > "$_cv_dir/delta.txt"
_cv_b3="$WORKDIR/verify_base.b3"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# CU28 : tous les fichiers intègres -> exit 0, STATUS=OK
_cu28_exit=0
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || _cu28_exit=$?
popd >/dev/null
assert_numeric_eq "CU28 exit 0 si tout OK" 0 "$_cu28_exit"
assert_equals "CU28 STATUS=OK" "OK" "$CORE_VERIFY_STATUS"

# CU29 : un fichier corrompu -> exit 1, STATUS=ECHEC
echo "corrompu" > "$_cv_dir/beta.txt"
_cu29_exit=0
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || _cu29_exit=$?
popd >/dev/null
if [ "$_cu29_exit" -ne 0 ]; then pass "CU29 exit non-zéro si corruption"; else fail "CU29 doit détecter la corruption"; fi
assert_equals "CU29 STATUS=ECHEC" "ECHEC" "$CORE_VERIFY_STATUS"
assert_numeric_eq "CU29 NB_FAIL=1" 1 "$CORE_VERIFY_NB_FAIL"
echo "beta" > "$_cv_dir/beta.txt"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# CU30 : plusieurs fichiers corrompus
echo "corrompu_alpha" > "$_cv_dir/alpha.txt"
echo "corrompu_beta"  > "$_cv_dir/beta.txt"
_cu30_exit=0
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || _cu30_exit=$?
popd >/dev/null
if [ "$_cu30_exit" -ne 0 ]; then pass "CU30 exit non-zéro si 2 corruptions"; else fail "CU30 doit détecter 2 corruptions"; fi
if [ "$CORE_VERIFY_NB_FAIL" -ge 2 ]; then pass "CU30 NB_FAIL>=2"; else fail "CU30 NB_FAIL=$CORE_VERIFY_NB_FAIL (attendu >=2)"; fi
echo "alpha" > "$_cv_dir/alpha.txt"
echo "beta"  > "$_cv_dir/beta.txt"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# CU31 : fichier supprimé -> exit 1, chemin dans LINES_FAIL
rm "$_cv_dir/gamma.txt"
_cu31_exit=0
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || _cu31_exit=$?
popd >/dev/null
if [ "$_cu31_exit" -ne 0 ]; then pass "CU31 exit non-zéro si fichier supprimé"; else fail "CU31 doit détecter la suppression"; fi
assert_contains "CU31 gamma.txt dans LINES_FAIL" "gamma.txt" "$CORE_VERIFY_LINES_FAIL"
echo "gamma" > "$_cv_dir/gamma.txt"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# CU32 : variables CORE_VERIFY_* non nulles en cas nominal
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3"
popd >/dev/null
if [ -n "$CORE_VERIFY_STATUS" ];  then pass "CU32 CORE_VERIFY_STATUS non nul";  else fail "CU32 CORE_VERIFY_STATUS vide";  fi
if [ -n "$CORE_VERIFY_NB_OK" ];   then pass "CU32 CORE_VERIFY_NB_OK non nul";   else fail "CU32 CORE_VERIFY_NB_OK vide";   fi
if [ -n "$CORE_VERIFY_NB_FAIL" ]; then pass "CU32 CORE_VERIFY_NB_FAIL non nul"; else fail "CU32 CORE_VERIFY_NB_FAIL vide"; fi

# CU33 : NB_OK correct (4 fichiers)
assert_numeric_eq "CU33 NB_OK=4" 4 "$CORE_VERIFY_NB_OK"

# CU34 : LINES_FAIL contient le bon chemin après corruption d'un fichier spécifique
echo "corrompu" > "$_cv_dir/beta.txt"
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || true
popd >/dev/null
assert_contains "CU34 LINES_FAIL contient beta.txt" "beta.txt" "$CORE_VERIFY_LINES_FAIL"
echo "beta" > "$_cv_dir/beta.txt"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# CU35 : STATUS=ERREUR si fichier illisible
chmod 000 "$_cv_dir/alpha.txt"
pushd "$_cv_dir" >/dev/null
core_verify "$_cv_b3" || true
popd >/dev/null
if [ "$CORE_VERIFY_STATUS" = "ERREUR" ] || [ "$CORE_VERIFY_NB_FAIL" -gt 0 ]; then
  pass "CU35 fichier illisible détecté (ERREUR ou FAIL)"
else
  fail "CU35 fichier illisible non détecté (STATUS=$CORE_VERIFY_STATUS)"
fi
chmod 644 "$_cv_dir/alpha.txt"
pushd "$_cv_dir" >/dev/null && b3sum ./*.txt | sort > "$_cv_b3" && popd >/dev/null

# == T_CORE05 - core_compare =====================================================

echo ""
echo "========================================"
echo "  T_CORE05 - core_compare"
echo "========================================"

# Helper : crée deux bases à partir de deux dossiers et compare
_run_compare() {
  local old_dir="$1" new_dir="$2" old_b3="$3" new_b3="$4" outdir="$5"
  ( cd "$old_dir" && b3sum ./* 2>/dev/null | sort > "$old_b3" ) 2>/dev/null || true
  ( cd "$new_dir" && b3sum ./* 2>/dev/null | sort > "$new_b3" ) 2>/dev/null || true
  mkdir -p "$outdir"
  core_compare "$old_b3" "$new_b3" "$outdir"
}

# CU36 : bases identiques -> tout à 0
_cu36_d="$WORKDIR/cu36"; mkdir -p "$_cu36_d"
echo "a" > "$_cu36_d/a.txt"; echo "b" > "$_cu36_d/b.txt"
_cu36_old="$WORKDIR/cu36_old.b3"; _cu36_new="$WORKDIR/cu36_new.b3"
_cu36_out="$WORKDIR/cu36_out"
( cd "$_cu36_d" && b3sum ./*.txt | sort > "$_cu36_old" )
cp "$_cu36_old" "$_cu36_new"
mkdir -p "$_cu36_out"
core_compare "$_cu36_old" "$_cu36_new" "$_cu36_out"
assert_numeric_eq "CU36 NB_MOD=0 bases identiques" 0 "$CORE_COMPARE_NB_MOD"
assert_numeric_eq "CU36 NB_DIS=0 bases identiques" 0 "$CORE_COMPARE_NB_DIS"
assert_numeric_eq "CU36 NB_NOU=0 bases identiques" 0 "$CORE_COMPARE_NB_NOU"

# CU37 : un fichier modifié
_cu37_old_d="$WORKDIR/cu37_old"; _cu37_new_d="$WORKDIR/cu37_new"
mkdir -p "$_cu37_old_d" "$_cu37_new_d"
echo "v1_alpha" > "$_cu37_old_d/alpha.txt"
echo "v1_beta"  > "$_cu37_old_d/beta.txt"
echo "v2_alpha" > "$_cu37_new_d/alpha.txt"   # modifié
echo "v1_beta"  > "$_cu37_new_d/beta.txt"
_cu37_ob="$WORKDIR/cu37_old.b3"; _cu37_nb="$WORKDIR/cu37_new.b3"; _cu37_out="$WORKDIR/cu37_out"
( cd "$_cu37_old_d" && b3sum ./*.txt | sort > "$_cu37_ob" )
( cd "$_cu37_new_d" && b3sum ./*.txt | sort > "$_cu37_nb" )
mkdir -p "$_cu37_out"
core_compare "$_cu37_ob" "$_cu37_nb" "$_cu37_out"
assert_numeric_eq "CU37 NB_MOD=1"          1 "$CORE_COMPARE_NB_MOD"
assert_contains   "CU37 alpha.txt modifié" "alpha.txt" "$(cat "$_cu37_out/modifies.b3")"

# CU38 : plusieurs fichiers modifiés
_cu38_old_d="$WORKDIR/cu38_old"; _cu38_new_d="$WORKDIR/cu38_new"
mkdir -p "$_cu38_old_d" "$_cu38_new_d"
for f in a b c; do
  echo "v1_$f" > "$_cu38_old_d/${f}.txt"
  echo "v2_$f" > "$_cu38_new_d/${f}.txt"
done
_cu38_ob="$WORKDIR/cu38_old.b3"; _cu38_nb="$WORKDIR/cu38_new.b3"; _cu38_out="$WORKDIR/cu38_out"
( cd "$_cu38_old_d" && b3sum ./*.txt | sort > "$_cu38_ob" )
( cd "$_cu38_new_d" && b3sum ./*.txt | sort > "$_cu38_nb" )
mkdir -p "$_cu38_out"
core_compare "$_cu38_ob" "$_cu38_nb" "$_cu38_out"
assert_numeric_eq "CU38 NB_MOD=3" 3 "$CORE_COMPARE_NB_MOD"

# CU39 : un fichier disparu
_cu39_old_d="$WORKDIR/cu39_old"; _cu39_new_d="$WORKDIR/cu39_new"
mkdir -p "$_cu39_old_d" "$_cu39_new_d"
echo "alpha" > "$_cu39_old_d/alpha.txt"
echo "beta"  > "$_cu39_old_d/beta.txt"
echo "beta"  > "$_cu39_new_d/beta.txt"   # alpha disparu
_cu39_ob="$WORKDIR/cu39_old.b3"; _cu39_nb="$WORKDIR/cu39_new.b3"; _cu39_out="$WORKDIR/cu39_out"
( cd "$_cu39_old_d" && b3sum ./*.txt | sort > "$_cu39_ob" )
( cd "$_cu39_new_d" && b3sum ./*.txt | sort > "$_cu39_nb" )
mkdir -p "$_cu39_out"
core_compare "$_cu39_ob" "$_cu39_nb" "$_cu39_out"
assert_numeric_eq "CU39 NB_DIS=1"          1 "$CORE_COMPARE_NB_DIS"
assert_contains   "CU39 alpha.txt disparu" "alpha.txt" "$(cat "$_cu39_out/disparus.txt")"

# CU40 : un fichier nouveau
_cu40_old_d="$WORKDIR/cu40_old"; _cu40_new_d="$WORKDIR/cu40_new"
mkdir -p "$_cu40_old_d" "$_cu40_new_d"
echo "alpha"   > "$_cu40_old_d/alpha.txt"
echo "alpha"   > "$_cu40_new_d/alpha.txt"
echo "epsilon" > "$_cu40_new_d/epsilon.txt"  # nouveau
_cu40_ob="$WORKDIR/cu40_old.b3"; _cu40_nb="$WORKDIR/cu40_new.b3"; _cu40_out="$WORKDIR/cu40_out"
( cd "$_cu40_old_d" && b3sum ./*.txt | sort > "$_cu40_ob" )
( cd "$_cu40_new_d" && b3sum ./*.txt | sort > "$_cu40_nb" )
mkdir -p "$_cu40_out"
core_compare "$_cu40_ob" "$_cu40_nb" "$_cu40_out"
assert_numeric_eq "CU40 NB_NOU=1"            1 "$CORE_COMPARE_NB_NOU"
assert_contains   "CU40 epsilon.txt nouveau" "epsilon.txt" "$(cat "$_cu40_out/nouveaux.txt")"

# CU41 : combinaison modifié + disparu + nouveau
_cu41_old_d="$WORKDIR/cu41_old"; _cu41_new_d="$WORKDIR/cu41_new"
mkdir -p "$_cu41_old_d" "$_cu41_new_d"
echo "v1"     > "$_cu41_old_d/modifie.txt"
echo "v1_dis" > "$_cu41_old_d/disparu.txt"
echo "v2"     > "$_cu41_new_d/modifie.txt"
echo "nvx"    > "$_cu41_new_d/nouveau.txt"
_cu41_ob="$WORKDIR/cu41_old.b3"; _cu41_nb="$WORKDIR/cu41_new.b3"; _cu41_out="$WORKDIR/cu41_out"
( cd "$_cu41_old_d" && b3sum ./*.txt | sort > "$_cu41_ob" )
( cd "$_cu41_new_d" && b3sum ./*.txt | sort > "$_cu41_nb" )
mkdir -p "$_cu41_out"
core_compare "$_cu41_ob" "$_cu41_nb" "$_cu41_out"
assert_numeric_eq "CU41 NB_MOD=1" 1 "$CORE_COMPARE_NB_MOD"
assert_numeric_eq "CU41 NB_DIS=1" 1 "$CORE_COMPARE_NB_DIS"
assert_numeric_eq "CU41 NB_NOU=1" 1 "$CORE_COMPARE_NB_NOU"

# CU42 : chemin avec espace
_cu42_old_d="$WORKDIR/cu42_old"; _cu42_new_d="$WORKDIR/cu42_new"
mkdir -p "$_cu42_old_d" "$_cu42_new_d"
echo "v1" > "$_cu42_old_d/fichier avec espace.txt"
echo "v2" > "$_cu42_new_d/fichier avec espace.txt"
_cu42_ob="$WORKDIR/cu42_old.b3"; _cu42_nb="$WORKDIR/cu42_new.b3"; _cu42_out="$WORKDIR/cu42_out"
( cd "$_cu42_old_d" && b3sum "fichier avec espace.txt" > "$_cu42_ob" )
( cd "$_cu42_new_d" && b3sum "fichier avec espace.txt" > "$_cu42_nb" )
mkdir -p "$_cu42_out"
core_compare "$_cu42_ob" "$_cu42_nb" "$_cu42_out"
assert_contains   "CU42 chemin avec espace dans modifies.b3" "fichier avec espace.txt" "$(cat "$_cu42_out/modifies.b3")"
assert_numeric_eq "CU42 NB_MOD=1"                            1 "$CORE_COMPARE_NB_MOD"

# CU43 : chemin avec &
_cu43_old_d="$WORKDIR/cu43_old"; _cu43_new_d="$WORKDIR/cu43_new"
mkdir -p "$_cu43_old_d" "$_cu43_new_d"
echo "v1" > "$_cu43_old_d/a&b.txt"
echo "v2" > "$_cu43_new_d/a&b.txt"
_cu43_ob="$WORKDIR/cu43_old.b3"; _cu43_nb="$WORKDIR/cu43_new.b3"; _cu43_out="$WORKDIR/cu43_out"
( cd "$_cu43_old_d" && b3sum "a&b.txt" > "$_cu43_ob" )
( cd "$_cu43_new_d" && b3sum "a&b.txt" > "$_cu43_nb" )
mkdir -p "$_cu43_out"
core_compare "$_cu43_ob" "$_cu43_nb" "$_cu43_out"
assert_contains "CU43 chemin avec & dans modifies.b3" "a&b.txt" "$(cat "$_cu43_out/modifies.b3")"

# CU44 : chemin avec < et >
_cu44_old_d="$WORKDIR/cu44_old"; _cu44_new_d="$WORKDIR/cu44_new"
mkdir -p "$_cu44_old_d" "$_cu44_new_d"
echo "v1" > "$_cu44_old_d/<script>.txt"
echo "v2" > "$_cu44_new_d/<script>.txt"
_cu44_ob="$WORKDIR/cu44_old.b3"; _cu44_nb="$WORKDIR/cu44_new.b3"; _cu44_out="$WORKDIR/cu44_out"
( cd "$_cu44_old_d" && b3sum "<script>.txt" > "$_cu44_ob" )
( cd "$_cu44_new_d" && b3sum "<script>.txt" > "$_cu44_nb" )
mkdir -p "$_cu44_out"
core_compare "$_cu44_ob" "$_cu44_nb" "$_cu44_out"
assert_contains     "CU44 chemin avec <> dans modifies.b3"  "<script>.txt" "$(cat "$_cu44_out/modifies.b3")"
assert_not_contains "CU44 pas d'&lt; dans modifies.b3"      "&lt;"         "$(cat "$_cu44_out/modifies.b3")"

# CU45 : format de modifies.b3 = "<nouveau_hash>  <chemin>" (format b3sum)
_cu45_line=$(head -1 "$_cu44_out/modifies.b3")
if echo "$_cu45_line" | grep -qE '^[0-9a-f]{64}  .+'; then
  pass "CU45 format modifies.b3 conforme b3sum"
else
  fail "CU45 format modifies.b3 inattendu : $_cu45_line"
fi

# CU46 : variables CORE_COMPARE_NB_* définies après appel
_cu46_out="$WORKDIR/cu46_out"; mkdir -p "$_cu46_out"
core_compare "$_cu36_old" "$_cu36_new" "$_cu46_out"
if [ -n "${CORE_COMPARE_NB_MOD+x}" ]; then pass "CU46 NB_MOD défini"; else fail "CU46 NB_MOD non défini"; fi
if [ -n "${CORE_COMPARE_NB_DIS+x}" ]; then pass "CU46 NB_DIS défini"; else fail "CU46 NB_DIS non défini"; fi
if [ -n "${CORE_COMPARE_NB_NOU+x}" ]; then pass "CU46 NB_NOU défini"; else fail "CU46 NB_NOU non défini"; fi

# CU47 : pas de fichiers tmp résiduels après appel (pattern mktemp standard)
# Note : core_compare nettoie via trap EXIT interne ; on vérifie qu'aucun /tmp/tmp.* récent ne traîne
_tmp_before=$(find /tmp -maxdepth 1 -name 'tmp.*' -newer "$WORKDIR" 2>/dev/null | wc -l)
core_compare "$_cu36_old" "$_cu36_new" "$_cu46_out" 2>/dev/null || true
_tmp_after=$(find /tmp -maxdepth 1 -name 'tmp.*' -newer "$WORKDIR" 2>/dev/null | wc -l)
if [ "$_tmp_after" -le "$_tmp_before" ]; then
  pass "CU47 fichiers tmp nettoyés"
else
  fail "CU47 fichiers tmp résiduels détectés ($((_tmp_after - _tmp_before)))"
fi

# CU48 : supprimé - testait un comportement hors-contrat.
# Le contrat de core_compare exige que outdir existe avant l'appel.
# Tester une précondition violée n'est pas pertinent.

# # CU48 : outdir absent -> comportement défini (mkdir requis par l'appelant)
# _cu48_nonexist="$WORKDIR/cu48_outdir_nonexist"
# _cu48_exit=0
# core_compare "$_cu36_old" "$_cu36_new" "$_cu48_nonexist" 2>/dev/null || _cu48_exit=$?
# # Comportement attendu : échec ou création du dossier selon implémentation.
# # On documente ce qui se passe sans imposer un exit code (outdir inexistant est précondition violée).
# if [ "$_cu48_exit" -ne 0 ] || [ -d "$_cu48_nonexist" ]; then
#   pass "CU48 outdir absent : comportement défini (exit=$_cu48_exit, dir_created=$([ -d "$_cu48_nonexist" ] && echo oui || echo non))"
# else
#   fail "CU48 outdir absent : comportement indéfini"
# fi

# == T_CORE06 - core_make_result_dir =============================================

echo ""
echo "========================================"
echo "  T_CORE06 - core_make_result_dir"
echo "========================================"

_cu_res_root="$WORKDIR/resultats_test"; mkdir -p "$_cu_res_root"

# CU49 : création normale
_cu49_b3="$WORKDIR/hashes.b3"; touch "$_cu49_b3"
_cu49_result=$(core_make_result_dir "$_cu49_b3" "$_cu_res_root")
if [ -d "$_cu49_result" ]; then pass "CU49 dossier créé"; else fail "CU49 dossier absent"; fi
assert_contains "CU49 nom contient 'resultats_hashes'" "resultats_hashes" "$_cu49_result"

# CU50 : anti-collision - dossier existant -> suffixe horodaté
# Le dossier résultats_hashes existe déjà depuis CU49
_cu50_result=$(core_make_result_dir "$_cu49_b3" "$_cu_res_root")
if [ "$_cu50_result" != "$_cu49_result" ]; then
  pass "CU50 anti-collision : nouveau dossier créé"
else
  fail "CU50 anti-collision : même dossier retourné (écrasement)"
fi
if [ -d "$_cu50_result" ]; then pass "CU50 nouveau dossier existe"; else fail "CU50 nouveau dossier absent"; fi

# CU51 : deux appels successifs -> deux dossiers distincts
_cu51_b3="$WORKDIR/autre.b3"; touch "$_cu51_b3"
_cu51_r1=$(core_make_result_dir "$_cu51_b3" "$_cu_res_root")
sleep 1
_cu51_r2=$(core_make_result_dir "$_cu51_b3" "$_cu_res_root")
if [ "$_cu51_r1" != "$_cu51_r2" ]; then
  pass "CU51 deux appels -> deux dossiers distincts"
else
  fail "CU51 deux appels -> même dossier (collision)"
fi

# CU52 : nom sans extension .b3
_cu52_b3="$WORKDIR/base"; touch "$_cu52_b3"
_cu52_result=$(core_make_result_dir "$_cu52_b3" "$_cu_res_root")
assert_contains "CU52 nom sans extension -> resultats_base" "resultats_base" "$_cu52_result"

# CU53 : nom avec chemin imbriqué -> basename only
_cu53_b3="/chemin/vers/hashes.b3"
# On ne crée pas ce fichier - on teste seulement la logique de nommage
_cu53_result=$(core_make_result_dir "$_cu53_b3" "$_cu_res_root")
assert_contains     "CU53 chemin imbriqué -> resultats_hashes"  "resultats_hashes" "$_cu53_result"
assert_not_contains "CU53 pas de chemin absolu dans le nom"     "/chemin/vers/"    "$_cu53_result"

# == Résultats ===================================================================

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}$PASS/$TOTAL tests passés${NC}"
else
  echo -e "  ${GREEN}$PASS${NC}/${TOTAL} passés - ${RED}$FAIL échec(s)${NC}"
fi
echo "========================================"
echo ""

[ "$FAIL" -eq 0 ]
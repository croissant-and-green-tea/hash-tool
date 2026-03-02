#!/usr/bin/env bash
# run_tests_pipeline.sh - Tests automatisés pour runner.sh + pipeline.json
#
# Couvre : parsing JSON, compute, verify, compare, champ resultats, erreurs
#
# Prérequis : bash >= 4, jq, b3sum
#             runner.sh    à ../
#             integrity.sh à ../src/
# Usage     : cd tests && ./run_tests_pipeline.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../runner.sh"
INTEGRITY="$SCRIPT_DIR/../src/integrity.sh"
WORKDIR="$(mktemp -d /tmp/integrity-pipeline-test.XXXXXX)"
export RESULTATS_DIR="$WORKDIR/resultats"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0; FAIL=0; TOTAL=0

pass() { echo -e "${GREEN}  PASS${NC} - $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); }
fail() { echo -e "${RED}  FAIL${NC} - $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); }

assert_contains() {
    local label="$1" pattern="$2" output="$3"
    if echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern '$pattern' absent)"; fi
}

assert_not_contains() {
    local label="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -q "$pattern"; then pass "$label"; else fail "$label (pattern '$pattern' présent à tort)"; fi
}

assert_file_exists() {
    local label="$1" file="$2"
    if [ -f "$file" ]; then pass "$label"; else fail "$label (absent : $file)"; fi
}

assert_file_absent() {
    local label="$1" file="$2"
    if [ ! -f "$file" ]; then pass "$label"; else fail "$label (présent à tort : $file)"; fi
}

assert_line_count() {
    local label="$1" expected="$2" file="$3"
    local actual; actual=$(wc -l < "$file")
    if [ "$actual" -eq "$expected" ]; then pass "$label"; else fail "$label (attendu $expected, obtenu $actual)"; fi
}

write_config() {
    local path="$WORKDIR/pipeline.json"
    cat > "$path"
    echo "$path"
}

setup() {
    mkdir -p "$WORKDIR"/{src_a,src_b,bases,resultats}

    echo "alpha content" > "$WORKDIR/src_a/alpha.txt"
    echo "beta content"  > "$WORKDIR/src_a/beta.txt"
    mkdir -p "$WORKDIR/src_a/sub"
    echo "delta content" > "$WORKDIR/src_a/sub/delta.txt"

    echo "gamma content" > "$WORKDIR/src_b/gamma.txt"
    echo "delta content" > "$WORKDIR/src_b/delta.txt"
}

teardown() { rm -rf "$WORKDIR"; }

run_tests() {
    cd "$WORKDIR"

    echo ""
    echo "========================================"
    echo "  runner.sh - suite de tests"
    echo "  Workdir : $WORKDIR"
    echo "========================================"
    echo ""

    echo "TP00 - Permissions integrity.sh"
    if [ -x "$INTEGRITY" ]; then pass "integrity.sh est exécutable"; else fail "integrity.sh non exécutable (chmod +x requis)"; fi
    echo ""

    # == TP01 : JSON invalide ==================================================
    echo "TP01 - JSON invalide : erreur propre sans stacktrace jq"
    local cfg_invalid="$WORKDIR/invalid.json"
    echo "{ pipeline: [ BROKEN" > "$cfg_invalid"
    local out_tp01; out_tp01=$(bash "$RUNNER" "$cfg_invalid" 2>&1 || true)
    assert_contains     "ERREUR signalée"         "ERREUR"      "$out_tp01"
    assert_not_contains "pas de stacktrace jq"    "parse error" "$out_tp01"
    echo ""

    # == TP02 : .pipeline absent ===============================================
    echo "TP02 - .pipeline absent"
    local cfg_no_pipeline
    cfg_no_pipeline=$(write_config <<'EOF'
{ "config": [] }
EOF
)
    local out_tp02; out_tp02=$(bash "$RUNNER" "$cfg_no_pipeline" 2>&1 || true)
    assert_contains "ERREUR si .pipeline absent" "ERREUR" "$out_tp02"
    echo ""

    # == TP03 : champ manquant =================================================
    echo "TP03 - Champ 'nom' manquant dans compute"
    local cfg_missing
    cfg_missing=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/src_a", "bases": "$WORKDIR/bases" }
    ]
}
EOF
)
    local out_tp03; out_tp03=$(bash "$RUNNER" "$cfg_missing" 2>&1 || true)
    assert_contains "ERREUR signalée"       "ERREUR" "$out_tp03"
    assert_contains "champ 'nom' mentionné" "nom"    "$out_tp03"
    echo ""

    # == TP04 : opération inconnue =============================================
    echo "TP04 - Opération inconnue"
    local cfg_unknown
    cfg_unknown=$(write_config <<'EOF'
{ "pipeline": [ { "op": "migrate", "source": "/tmp" } ] }
EOF
)
    local out_tp04; out_tp04=$(bash "$RUNNER" "$cfg_unknown" 2>&1 || true)
    assert_contains "ERREUR signalée"           "ERREUR"   "$out_tp04"
    assert_contains "nom de l'op dans l'erreur" "migrate"  "$out_tp04"
    echo ""

    # == TP05 : compute - chemins relatifs =====================================
    echo "TP05 - Compute : cd correct, chemins relatifs dans la base"
    local cfg_compute
    cfg_compute=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/src_a", "bases": "$WORKDIR/bases", "nom": "hashes_a.b3" }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compute" >/dev/null 2>&1
    assert_file_exists "base hashes_a.b3 créée" "$WORKDIR/bases/hashes_a.b3"
    local first_path; first_path=$(awk '{print $2}' "$WORKDIR/bases/hashes_a.b3" | head -1)
    assert_contains     "chemin relatif (./) dans base"    "./"       "$first_path"
    assert_not_contains "pas de chemin absolu dans base"   "$WORKDIR" "$first_path"
    assert_line_count   "3 fichiers indexés"               3          "$WORKDIR/bases/hashes_a.b3"
    echo ""

    # == TP06 : compute - source absente ======================================
    echo "TP06 - Compute : source absente -> erreur"
    local cfg_absent
    cfg_absent=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/inexistant", "bases": "$WORKDIR/bases", "nom": "ko.b3" }
    ]
}
EOF
)
    local out_tp06; out_tp06=$(bash "$RUNNER" "$cfg_absent" 2>&1 || true)
    assert_contains    "ERREUR signalée"              "ERREUR"  "$out_tp06"
    assert_file_absent "pas de base créée si source KO" "$WORKDIR/bases/ko.b3"
    echo ""

    # == TP07 : verify - OK ===================================================
    echo "TP07 - Verify : répertoire de travail correct, vérification OK"
    local cfg_verify
    cfg_verify=$(write_config <<EOF
{
    "pipeline": [
        { "op": "verify", "source": "$WORKDIR/src_a", "base": "$WORKDIR/bases/hashes_a.b3" }
    ]
}
EOF
)
    local out_tp07; out_tp07=$(bash "$RUNNER" "$cfg_verify" 2>&1 || true)
    assert_contains     "verify OK"     "OK"     "$out_tp07"
    assert_not_contains "aucun FAILED"  "FAILED" "$out_tp07"
    local outdir_tp07; outdir_tp07=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | sort | tail -1)
    assert_file_exists  "recap.txt produit" "${outdir_tp07}/recap.txt"
    echo ""

    # == TP08 : verify - corruption ===========================================
    echo "TP08 - Verify : corruption détectée"
    echo "contenu corrompu" > "$WORKDIR/src_a/alpha.txt"
    local out_tp08; out_tp08=$(bash "$RUNNER" "$cfg_verify" 2>&1 || true)
    assert_contains "ECHEC détecté" "ECHEC" "$out_tp08"
    echo "alpha content"   > "$WORKDIR/src_a/alpha.txt"
    echo ""

    # == TP09 : verify - base absente =========================================
    echo "TP09 - Verify : base .b3 absente -> erreur"
    local cfg_verify_bad
    cfg_verify_bad=$(write_config <<EOF
{
    "pipeline": [
        { "op": "verify", "source": "$WORKDIR/src_a", "base": "$WORKDIR/bases/fantome.b3" }
    ]
}
EOF
)
    local out_tp09; out_tp09=$(bash "$RUNNER" "$cfg_verify_bad" 2>&1 || true)
    assert_contains "ERREUR si base absente" "ERREUR" "$out_tp09"
    echo ""

    # == TP10 : compare - résultats produits (RESULTATS_DIR par défaut) ========
    echo "TP10 - Compare : fichiers de résultats produits (sans champ resultats)"
    local cfg_compute_b
    cfg_compute_b=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/src_b", "bases": "$WORKDIR/bases", "nom": "hashes_b.b3" }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compute_b" >/dev/null 2>&1

    local cfg_compare
    cfg_compare=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compare", "base_a": "$WORKDIR/bases/hashes_a.b3", "base_b": "$WORKDIR/bases/hashes_b.b3" }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compare" >/dev/null 2>&1 || true
    local outdir_tp10; outdir_tp10=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | sort | tail -1)
    assert_file_exists "recap.txt"    "${outdir_tp10}/recap.txt"
    assert_file_exists "modifies.b3"  "${outdir_tp10}/modifies.b3"
    assert_file_exists "disparus.txt" "${outdir_tp10}/disparus.txt"
    assert_file_exists "nouveaux.txt" "${outdir_tp10}/nouveaux.txt"
    assert_file_exists "report.html"  "${outdir_tp10}/report.html"
    echo ""

    # == TP10b : compare - champ resultats personnalisé =======================
    echo "TP10b - Compare : champ 'resultats' personnalisé dans pipeline.json"
    local custom_dir="$WORKDIR/mon_rapport_custom"
    local cfg_compare_custom
    cfg_compare_custom=$(write_config <<EOF
{
    "pipeline": [
        {
            "op":       "compare",
            "base_a":   "$WORKDIR/bases/hashes_a.b3",
            "base_b":   "$WORKDIR/bases/hashes_b.b3",
            "resultats": "$custom_dir"
        }
    ]
}
EOF
)
    bash "$RUNNER" "$cfg_compare_custom" >/dev/null 2>&1 || true
    local outdir_custom; outdir_custom=$(find "${custom_dir}" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | sort | tail -1)
    assert_file_exists "rapport dans dossier custom"            "${outdir_custom}/recap.txt"
    assert_file_exists "report.html dans dossier custom"        "${outdir_custom}/report.html"
    # Vérifier que le dossier par défaut n'a PAS reçu ce résultat
    local nb_before; nb_before=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | wc -l)
    bash "$RUNNER" "$cfg_compare_custom" >/dev/null 2>&1 || true
    local nb_after; nb_after=$(find "${RESULTATS_DIR}" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | wc -l)
    if [ "$nb_before" -eq "$nb_after" ]; then
        pass "champ resultats isolé : RESULTATS_DIR par défaut non pollué"
    else
        fail "champ resultats isolé : RESULTATS_DIR par défaut non pollué"
    fi
    echo ""

    # == TP11 : compare - base_a absente ======================================
    echo "TP11 - Compare : base_a absente -> erreur"
    local cfg_compare_bad
    cfg_compare_bad=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compare", "base_a": "$WORKDIR/bases/fantome.b3", "base_b": "$WORKDIR/bases/hashes_b.b3" }
    ]
}
EOF
)
    local out_tp11; out_tp11=$(bash "$RUNNER" "$cfg_compare_bad" 2>&1 || true)
    assert_contains "ERREUR si base_a absente" "ERREUR" "$out_tp11"
    echo ""

    # == TP12 : pipeline complet ===============================================
    echo "TP12 - Pipeline complet : compute × 2 + verify + compare"
    rm -f "$WORKDIR/bases/hashes_a.b3" "$WORKDIR/bases/hashes_b.b3"
    local cfg_full
    cfg_full=$(write_config <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/src_a", "bases": "$WORKDIR/bases", "nom": "hashes_a.b3" },
        { "op": "compute", "source": "$WORKDIR/src_b", "bases": "$WORKDIR/bases", "nom": "hashes_b.b3" },
        { "op": "verify",  "source": "$WORKDIR/src_a", "base":  "$WORKDIR/bases/hashes_a.b3" },
        { "op": "compare", "base_a": "$WORKDIR/bases/hashes_a.b3", "base_b": "$WORKDIR/bases/hashes_b.b3",
          "resultats": "$WORKDIR/resultats_pipeline" }
    ]
}
EOF
)
    local out_tp12; out_tp12=$(bash "$RUNNER" "$cfg_full" 2>&1 || true)
    assert_contains     "COMPUTE mentionné"     "COMPUTE" "$out_tp12"
    assert_contains     "VERIFY mentionné"      "VERIFY"  "$out_tp12"
    assert_contains     "COMPARE mentionné"     "COMPARE" "$out_tp12"
    assert_file_exists  "hashes_a.b3 créée"     "$WORKDIR/bases/hashes_a.b3"
    assert_file_exists  "hashes_b.b3 créée"     "$WORKDIR/bases/hashes_b.b3"
    assert_not_contains "pas d'ERREUR"          "ERREUR"  "$out_tp12"
    local outdir_tp12; outdir_tp12=$(find "${WORKDIR}/resultats_pipeline" -maxdepth 1 -type d -name "resultats_hashes_a*" 2>/dev/null | sort | tail -1)
    assert_file_exists  "report.html pipeline complet" "${outdir_tp12}/report.html"
    echo ""
}

# == Main ======================================================================

for dep in jq b3sum; do
    command -v "$dep" &>/dev/null || { echo -e "${RED}ERREUR${NC} : $dep non trouvé."; exit 1; }
done

[ -f "$RUNNER" ]    || { echo -e "${RED}ERREUR${NC} : runner.sh introuvable : $RUNNER";      exit 1; }
[ -f "$INTEGRITY" ] || { echo -e "${RED}ERREUR${NC} : src/integrity.sh introuvable : $INTEGRITY"; exit 1; }

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
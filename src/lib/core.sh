#!/usr/bin/env bash
# src/lib/core.sh - Logique métier BLAKE3 : hachage, vérification, comparaison, sidecar
#
# Ce module contient uniquement la logique métier. Il ne produit aucune
# sortie terminal directement - toute communication avec l'utilisateur
# est déléguée à src/lib/ui.sh via les codes de retour et les variables
# de sortie déclarées dans les contrats ci-dessous.
#
# Sourcé par src/integrity.sh. Ne pas exécuter directement.
#
# == Dépendances ================================================================
#   b3sum, find, sort, awk, join, comm, mktemp, stat, du
#   jq (optionnel - requis pour core_sidecar_write et core_sidecar_read)
#
# == Invariants globaux =========================================================
#   - Toutes les fonctions supposent bash >= 4 (vérifié par integrity.sh)
#   - Les chemins dans les bases .b3 sont toujours RELATIFS (jamais absolus)
#   - Le format .b3 est celui natif de b3sum : "<hash64>  <chemin>" (2 espaces)
#   - L'encodage supposé est UTF-8 ; les noms non UTF-8 sont traités comme des
#     séquences d'octets opaques (find -print0 / mapfile -d '' garantissent
#     l'absence d'interprétation)
#   - La locale n'affecte pas le tri : sort utilise l'ordre binaire (LC_ALL=C
#     doit être positionné par l'appelant si nécessaire pour reproductibilité)

# == Validation =================================================================

# core_assert_b3_valid <fichier> [label]
#
# Contrat d'entrée :
#   $1 - chemin vers un fichier .b3 à valider
#   $2 - label optionnel pour les messages d'erreur (défaut : $1)
#
# Contrat de sortie :
#   exit 0  - fichier valide : existe, est un fichier régulier, non vide,
#             contient au moins une ligne au format "<hash64>  <chemin>"
#   exit 1  - fichier invalide ; appelle die() avec message explicite
#
# Effets de bord : aucun
core_assert_b3_valid() {
  local file="$1"
  local label="${2:-$1}"

  [ -e "$file" ] || die "$label : fichier introuvable."
  [ -f "$file" ] || die "$label : est un dossier, pas un fichier .b3."
  [ -s "$file" ] || die "$label : fichier vide - aucun hash à traiter."

  local valid_lines
  valid_lines=$(grep -c -E '^[0-9a-f]{64}  .+' "$file" || true)
  [ "$valid_lines" -gt 0 ] || die "$label : format invalide - aucune ligne au format b3sum détectée."

  local total_lines
  total_lines=$(wc -l < "$file")
  if [ "$total_lines" -gt "$valid_lines" ]; then
    die "$label : fichier corrompu - $((total_lines - valid_lines)) ligne(s) sur $total_lines ne respectent pas le format b3sum."
  fi
}

# core_assert_target_valid <dossier>
#
# Contrat d'entrée :
#   $1 - chemin vers un dossier à indexer
#
# Contrat de sortie :
#   exit 0  - dossier valide : existe, est un dossier, contient au moins un fichier régulier
#   exit 1  - invalide ; appelle die() avec message explicite
#
# Effets de bord : aucun
core_assert_target_valid() {
  local dir="$1"

  [ -e "$dir" ] || die "Dossier cible introuvable : $dir"
  [ -d "$dir" ] || die "Le chemin cible n'est pas un dossier : $dir"

  local nb_files
  nb_files=$(find "$dir" -type f -print0 | grep -zc '' || echo 0)
  (( nb_files > 0 )) || die "Le dossier $dir ne contient aucun fichier régulier - rien à hacher."
}

# == Utilitaires internes ========================================================

# _core_file_size <fichier>
#
# Contrat de sortie :
#   stdout - taille du fichier en octets (entier)
#   Portable : GNU stat (-c%s) avec fallback BSD stat (-f%z)
#
# Effets de bord : aucun
_core_file_size() {
  local f="$1"
  if stat -c%s "$f" 2>/dev/null; then
    return
  fi
  stat -f%z "$f"
}

# == Hachage ====================================================================

# core_compute <dossier> <fichier_sortie> [callback_progression]
#
# Contrat d'entrée :
#   $1 - dossier cible (chemin relatif RECOMMANDÉ pour portabilité des bases)
#   $2 - chemin du fichier .b3 de sortie (créé ou écrasé)
#   $3 - (optionnel) nom d'une fonction de callback appelée après chaque fichier
#         Signature callback : callback <i> <total_files> <bytes_done> <total_bytes> <eta_seconds>
#         Passer "" ou omettre pour désactiver la progression
#
# Contrat de sortie :
#   exit 0       - base calculée avec succès
#   exit 1       - erreur (propagée depuis b3sum ou find)
#   $2 (fichier) - contient N lignes "<hash64>  <chemin>", triées par chemin,
#                  sans artefact terminal (ETA, \r, etc.)
#
# Invariants garantis :
#   - Les chemins dans $2 sont identiques à ceux vus par find depuis $1
#   - L'ordre est déterministe (sort -z sur les chemins)
#   - Aucune ligne ETA ou de progression ne peut être écrite dans $2 :
#     b3sum est appelé par fichier individuel, la progression est gérée
#     par le callback, pas par redirection
#
# Effets de bord :
#   - Crée ou écrase $2
#   - Appelle $3 si fourni (effets de bord dépendants du callback)
core_compute() {
  local target="$1"
  local hashfile="$2"
  local callback="${3:-}"

  local -a files
  mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)

  local total_files=${#files[@]}
  local total_bytes
  total_bytes=$(du -sb "$target" | awk '{print $1}')

  local bytes_done=0
  local t_start
  t_start=$(date +%s)

  local i=0
  for file in "${files[@]}"; do
    b3sum "$file" >> "$hashfile"

    local fsize
    fsize=$(_core_file_size "$file")
    # Fichier de taille zéro : bytes_done inchangé, ETA non calculée pour ce fichier
    if (( fsize > 0 )); then
      bytes_done=$(( bytes_done + fsize ))
    fi
    i=$(( i + 1 ))

    if [ -n "$callback" ]; then
      local t_now elapsed eta_seconds=0
      t_now=$(date +%s)
      elapsed=$(( t_now - t_start ))
      if (( bytes_done > 0 && elapsed > 0 )); then
        # shellcheck disable=SC2034  # remaining : réservé pour usage futur (affichage temps restant)
        local speed remaining
        speed=$(( bytes_done / elapsed ))
        if (( speed > 0 )); then
          eta_seconds=$(( (total_bytes - bytes_done) / speed ))
        else
          eta_seconds=0
        fi
      fi
      "$callback" "$i" "$total_files" "$bytes_done" "$total_bytes" "$eta_seconds"
    fi
  done
}

# core_compute_fast <dossier> <fichier_sortie>
#
# Variante de core_compute sans progression : appelle b3sum en batch sur tous
# les fichiers en un seul process. Significativement plus rapide sur les grands
# volumes (N × overhead process → 1 × overhead process + hachage pur).
#
# Contrat d'entrée :
#   $1 - dossier cible (chemin relatif RECOMMANDÉ pour portabilité des bases)
#   $2 - chemin du fichier .b3 de sortie (créé ou écrasé)
#
# Contrat de sortie :
#   exit 0       - base calculée avec succès
#   exit 1       - erreur (propagée depuis b3sum ou find)
#   $2 (fichier) - contient N lignes "<hash64>  <chemin>", triées par chemin
#
# Effets de bord :
#   - Crée ou écrase $2
#   - Aucune sortie terminal (pas de progression, pas de callback)
core_compute_fast() {
  local target="$1"
  local hashfile="$2"

  find "$target" -type f -print0 | sort -z | xargs -0 b3sum > "$hashfile"
}

# == Vérification ===============================================================

# core_verify <fichier_b3>
#
# Contrat d'entrée :
#   $1 - chemin absolu vers un fichier .b3 valide (validé par core_assert_b3_valid)
#         Le répertoire de travail courant DOIT être celui depuis lequel compute
#         a été exécuté (les chemins dans .b3 sont relatifs à ce répertoire)
#
# Contrat de sortie :
#   exit 0  - tous les fichiers intègres
#   exit 1  - au moins un FAILED ou erreur b3sum
#   CORE_VERIFY_RAW        - sortie brute de b3sum --check
#   CORE_VERIFY_LINES_OK   - lignes "chemin: OK"
#   CORE_VERIFY_LINES_FAIL - lignes "chemin: FAILED"
#   CORE_VERIFY_LINES_ERR  - lignes d'erreur b3sum non liées aux hashes
#   CORE_VERIFY_NB_OK      - entier : nombre de fichiers OK
#   CORE_VERIFY_NB_FAIL    - entier : nombre de fichiers FAILED
#   CORE_VERIFY_STATUS     - "OK" | "ECHEC" | "ERREUR"
#
# Effets de bord :
#   - Positionne les variables CORE_VERIFY_* dans le scope de l'appelant
#     (les variables doivent être déclarées locales dans l'appelant si isolation requise)
core_verify() {
  local hashfile="$1"

  local raw exit_code
  raw=$(b3sum --check "$hashfile" 2>&1) && exit_code=0 || exit_code=$?

  # Variables de sortie lues par l'appelant (integrity.sh) - pas des variables locales
  # shellcheck disable=SC2034
  CORE_VERIFY_RAW="$raw"
  # shellcheck disable=SC2034
  CORE_VERIFY_LINES_OK=$(echo    "$raw" | grep ': OK$'    || true)
  # shellcheck disable=SC2034
  CORE_VERIFY_LINES_FAIL=$(echo  "$raw" | grep ': FAILED' || true)
  # shellcheck disable=SC2034
  CORE_VERIFY_LINES_ERR=$(echo   "$raw" | grep -Ev ': (OK|FAILED)' | grep -v '^$' || true)

  if [ -n "$CORE_VERIFY_LINES_OK" ]; then
    # shellcheck disable=SC2034
    CORE_VERIFY_NB_OK=$(echo "$CORE_VERIFY_LINES_OK" | grep -c '^')
  else
    # shellcheck disable=SC2034
    CORE_VERIFY_NB_OK=0
  fi

  if [ -n "$CORE_VERIFY_LINES_FAIL" ]; then
    # shellcheck disable=SC2034
    CORE_VERIFY_NB_FAIL=$(echo "$CORE_VERIFY_LINES_FAIL" | grep -c '^')
  else
    # shellcheck disable=SC2034
    CORE_VERIFY_NB_FAIL=0
  fi

  if [ -n "$CORE_VERIFY_LINES_ERR" ]; then
      CORE_VERIFY_STATUS="ERREUR"
    elif [ "$CORE_VERIFY_NB_FAIL" -gt 0 ]; then
      CORE_VERIFY_STATUS="ECHEC"
    else
      # shellcheck disable=SC2034
      CORE_VERIFY_STATUS="OK"
    fi

  return $exit_code
}

# == Comparaison ================================================================

# core_compare <ancienne_b3> <nouvelle_b3> <outdir>
#
# Contrat d'entrée :
#   $1 - chemin vers l'ancienne base .b3 (validée par core_assert_b3_valid)
#   $2 - chemin vers la nouvelle base .b3 (validée par core_assert_b3_valid)
#   $3 - dossier de sortie (doit exister avant l'appel)
#
# Contrat de sortie :
#   exit 0  - comparaison effectuée (même si des différences existent)
#   exit 1  - erreur technique (b3sum, awk, join, comm)
#   $3/modifies.b3   - fichiers présents dans les deux bases avec hashes différents
#                      Format : "<nouveau_hash>  <chemin>" (format b3sum)
#   $3/disparus.txt  - chemins présents dans $1, absents de $2 (un chemin par ligne)
#   $3/nouveaux.txt  - chemins absents de $1, présents dans $2 (un chemin par ligne)
#   CORE_COMPARE_NB_MOD  - entier : nombre de fichiers modifiés
#   CORE_COMPARE_NB_DIS  - entier : nombre de fichiers disparus
#   CORE_COMPARE_NB_NOU  - entier : nombre de nouveaux fichiers
#
# Algorithme :
#   1. Conversion "<hash>  <chemin>" -> "<chemin>\t<hash>" via awk (offset fixe 64+2)
#      Robuste aux chemins avec espaces : le séparateur est le tab, pas l'espace
#   2. sort par chemin (clé 1 uniquement)
#   3. join inner sur le chemin -> identifie les modifiés (hashes différents)
#   4. comm -23 / -13 sur les chemins -> disparus et nouveaux
#
# Effets de bord :
#   - Écrit $3/modifies.b3, $3/disparus.txt, $3/nouveaux.txt
#   - Positionne CORE_COMPARE_NB_* dans le scope de l'appelant
#   - Utilise mktemp pour les fichiers temporaires (nettoyés via trap EXIT)
core_compare() {
  local old="$1"
  local new="$2"
  local outdir="$3"

  local tmp_old tmp_new
  tmp_old=$(mktemp)
  tmp_new=$(mktemp)

  trap 'rm -f "$tmp_old" "$tmp_new"' EXIT

  # Conversion vers format "chemin\thash" - offset fixe 64 chars pour le hash
  # Robuste aux espaces dans les chemins
  _b3_to_path_hash() {
    awk '{ print substr($0,67) "\t" substr($0,1,64) }' "$1" | sort -t $'\t' -k1,1
  }

  _b3_to_path_hash "$old" > "$tmp_old"
  _b3_to_path_hash "$new" > "$tmp_new"

  # Fichiers modifiés : présents dans les deux bases, hashes différents
  join -t $'\t' -1 1 -2 1 "$tmp_old" "$tmp_new" \
    | awk -F $'\t' '$2 != $3 { print $3 "  " $1 }' \
    > "${outdir}/modifies.b3"

  # Fichiers disparus : dans old, pas dans new
  comm -23 <(cut -f1 "$tmp_old") <(cut -f1 "$tmp_new") > "${outdir}/disparus.txt"

  # Nouveaux fichiers : dans new, pas dans old
  comm -13 <(cut -f1 "$tmp_old") <(cut -f1 "$tmp_new") > "${outdir}/nouveaux.txt"

  # Variables de sortie lues par l'appelant (integrity.sh)
  # shellcheck disable=SC2034
  CORE_COMPARE_NB_MOD=$(wc -l < "${outdir}/modifies.b3")
  # shellcheck disable=SC2034
  CORE_COMPARE_NB_DIS=$(wc -l < "${outdir}/disparus.txt")
  # shellcheck disable=SC2034
  CORE_COMPARE_NB_NOU=$(wc -l < "${outdir}/nouveaux.txt")

  rm -f "$tmp_old" "$tmp_new"
  trap - EXIT
}

# == Gestion des dossiers de résultats ==========================================

# core_make_result_dir <fichier_b3> <resultats_dir>
#
# Contrat d'entrée :
#   $1 - chemin vers le fichier .b3 (utilisé pour nommer le dossier)
#   $2 - dossier racine des résultats (RESULTATS_DIR)
#
# Contrat de sortie :
#   stdout - chemin absolu du dossier de résultats créé
#   exit 0 - dossier créé avec succès
#   exit 1 - échec de création (permissions, chemin invalide)
#
# Invariant anti-écrasement :
#   Si "<resultats_dir>/resultats_<nom_base>" existe déjà, un suffixe horodaté
#   "_YYYYMMDD-HHMMSS" est ajouté. Aucun résultat existant n'est jamais écrasé.
core_make_result_dir() {
  local b3file="$1"
  local resultats_dir="$2"

  local basename_noext
  basename_noext=$(basename "$b3file" .b3)
  local outdir="${resultats_dir}/resultats_${basename_noext}"

  if [ -d "$outdir" ]; then
    outdir="${outdir}_$(date +%Y%m%d-%H%M%S)"
  fi

  mkdir -p "$outdir" || die "Impossible de créer le dossier de résultats : $outdir"
  echo "$outdir"
}

# == Sidecar file ===============================================================

# core_sidecar_write <b3_path> <data_dir> <comment> <version>
#
# Génère un fichier <b3_path>.meta.json contenant les métadonnées du compute.
#
# Contrat d'entrée :
#   $1 - chemin du fichier .b3 produit (utilisé pour nommer le sidecar)
#   $2 - dossier source ayant été haché
#   $3 - commentaire libre (peut être vide)
#   $4 - version de l'outil (ex. "integrity.sh v2.0.0" ou "hash-tool v2.0.0")
#
# Contrat de sortie :
#   exit 0  - sidecar créé : <b3_path>.meta.json
#   exit 1  - jq introuvable (silencieux : pas d'erreur fatale, compute reste valide)
#   stdout  - aucun
#
# Invariants :
#   - Le fichier .b3 doit exister avant l'appel (nb_files lu via wc -l)
#   - Si jq est absent, la fonction retourne silencieusement sans créer le sidecar
#   - Le sidecar n'écrase pas un éventuel sidecar existant : c'est un nouveau compute
#
# Effets de bord :
#   - Écrit <b3_path>.meta.json sur le disque
core_sidecar_write() {
  local b3_path="$1"
  local data_dir="$2"
  local comment="${3:-}"
  local version="${4:-integrity.sh}"
  local sidecar_path="${b3_path}.meta.json"

  # jq requis - absence non fatale
  command -v jq &>/dev/null || return 0

  local nb_files
  nb_files=$(wc -l < "$b3_path" 2>/dev/null || echo 0)

  jq -n \
    --arg version  "$version" \
    --arg date     "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg comment  "$comment" \
    --arg dir      "$data_dir" \
    --argjson nb   "$nb_files" \
    '{
      created_by: $version,
      date:       $date,
      comment:    $comment,
      parameters: {
        directory:  $dir,
        hash_algo:  "blake3",
        nb_files:   $nb
      }
    }' > "$sidecar_path"
}

# core_sidecar_read <b3_path>
#
# Affiche le contenu du sidecar associé à un fichier .b3 si celui-ci existe.
# Aucun effet si le sidecar est absent ou si jq est indisponible.
#
# Contrat d'entrée :
#   $1 - chemin du fichier .b3 (le sidecar est <b3_path>.meta.json)
#
# Contrat de sortie :
#   exit 0  - toujours
#   stdout  - contenu JSON formaté si sidecar présent ; rien sinon
#
# Effets de bord : aucun
core_sidecar_read() {
  local b3_path="$1"
  local sidecar_path="${b3_path}.meta.json"

  [ -f "$sidecar_path" ] || return 0

  echo "--- Métadonnées (sidecar) ---"
  if command -v jq &>/dev/null; then
    jq '.' "$sidecar_path" 2>/dev/null || cat "$sidecar_path"
  else
    cat "$sidecar_path"
  fi
  echo "-----------------------------"
}
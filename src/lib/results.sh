#!/usr/bin/env bash
# src/lib/results.sh - Écriture des fichiers de résultats texte
#
# Ce module produit les fichiers recap.txt et failed.txt à partir des
# données de sortie de core_verify() et core_compare().
# Il ne contient ni logique métier ni logique d'affichage terminal.
#
# Sourcé par src/integrity.sh. Ne pas exécuter directement.

# == Résultats de vérification ==================================================

# results_write_verify <outdir> <hashfile> <statut> <nb_ok> <nb_fail> <lines_fail> <lines_err>
#
# Contrat d'entrée :
#   $1 - dossier de sortie (doit exister)
#   $2 - chemin du fichier .b3 vérifié
#   $3 - statut : "OK" | "ECHEC" | "ERREUR"
#   $4 - nombre de fichiers OK
#   $5 - nombre de fichiers FAILED
#   $6 - lignes FAILED (chaîne multi-lignes, peut être vide)
#   $7 - lignes d'erreur b3sum (chaîne multi-lignes, peut être vide)
#
# Contrat de sortie :
#   exit 0
#   $1/recap.txt  - toujours créé
#   $1/failed.txt - créé si $5 > 0 ou $7 non vide ; supprimé sinon
#                   (suppression pour éviter un failed.txt obsolète d'un run précédent)
#
# Effets de bord : écrit sur le disque
results_write_verify() {
  local outdir="$1"
  local hashfile="$2"
  local statut="$3"
  local nb_ok="$4"
  local nb_fail="$5"
  local lines_fail="$6"
  local lines_err="$7"

  # recap.txt
  {
    echo "========================================"
    echo "  STATUT : $statut"
    echo "========================================"
    echo ""
    echo "Commande  : integrity.sh verify $(basename "$hashfile")"
    echo "Date      : $(date)"
    echo "Base      : $hashfile"
    echo ""
    echo "OK        : $nb_ok"
    if (( nb_fail > 0 )); then
      echo "FAILED    : $nb_fail  ← voir failed.txt"
    fi
    if [ -n "$lines_err" ]; then
      echo ""
      echo "== Erreurs b3sum ======================"
      echo "$lines_err"
    fi
  } > "${outdir}/recap.txt"

  # failed.txt
  if (( nb_fail > 0 )) || [ -n "$lines_err" ]; then
    {
      echo "========================================"
      echo "  FICHIERS EN ECHEC"
      echo "========================================"
      echo ""
      [ -n "$lines_fail" ] && echo "$lines_fail"
      if [ -n "$lines_err" ]; then
        echo ""
        echo "== Erreurs ============================"
        echo "$lines_err"
      fi
    } > "${outdir}/failed.txt"
  else
    rm -f "${outdir}/failed.txt"
  fi
}

# == Résultats de comparaison ===================================================

# results_write_compare <outdir> <old_b3> <new_b3> <nb_mod> <nb_dis> <nb_nou>
#
# Contrat d'entrée :
#   $1 - dossier de sortie (doit exister, contient déjà modifies.b3, disparus.txt, nouveaux.txt)
#   $2 - chemin de l'ancienne base .b3
#   $3 - chemin de la nouvelle base .b3
#   $4 - nombre de fichiers modifiés
#   $5 - nombre de fichiers disparus
#   $6 - nombre de nouveaux fichiers
#
# Contrat de sortie :
#   exit 0
#   $1/recap.txt - créé
#
# Effets de bord : écrit sur le disque
results_write_compare() {
  local outdir="$1"
  local old="$2"
  local new="$3"
  local nb_mod="$4"
  local nb_dis="$5"
  local nb_nou="$6"

  {
    echo "Commande      : integrity.sh compare $(basename "$old") $(basename "$new")"
    echo "Date          : $(date)"
    echo "Ancienne base : $old"
    echo "Nouvelle base : $new"
    echo ""
    echo "Modifiés      : $nb_mod"
    echo "Disparus      : $nb_dis"
    echo "Nouveaux      : $nb_nou"
  } > "${outdir}/recap.txt"
}

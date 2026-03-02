# Troubleshooting

---

## Diagnostic de premier niveau

Avant toute investigation, lancer ces trois commandes dans l'ordre :

```bash
# 1. Confirme que le script est accessible et exécutable
bash hash-tool version

# 2. État de toutes les dépendances + mode d'exécution actif
bash hash-tool check-env

# 3. Inspecte le préfixe des chemins dans la base concernée
head -3 <fichier.b3>
```

La sortie de `check-env` identifie immédiatement les composants manquants ou défaillants.
Le préfixe des chemins dans le `.b3` révèle les problèmes de répertoire de travail.

---

## Convention

Chaque problème suit le format :

**Symptôme** → ce qui est observable  
**Cause** → pourquoi cela se produit  
**Diagnostic** → commande à lancer pour confirmer  
**Solution** → correctif à appliquer

---

## Tableau symptôme → page

| Symptôme | Page |
|---|---|
| `b3sum` introuvable, `hash-tool` non exécutable | [Installation](installation.md) |
| `bash` version insuffisante, erreurs de syntaxe au démarrage | [Installation](installation.md) |
| Image Docker absente, fallback non déclenché | [Installation](installation.md) |
| Exit 126 en CI (`integrity.sh` non exécutable) | [Installation](installation.md) |
| `verify` échoue sur tous les fichiers malgré données intactes | [Exécution](execution.md) |
| `.b3` vide ou nombre de fichiers anormal | [Exécution](execution.md) |
| `compare` retourne des milliers de modifiés inattendus | [Exécution](execution.md) |
| `verify` retourne exit 1 alors que la sortie affiche OK | [Exécution](execution.md) |
| Fichiers `.b3` non créés sur l'hôte après `compute` Docker | [Docker](docker.md) |
| Exécution Docker très lente sur WSL2 | [Docker](docker.md) |
| Permission denied sur `/bases` ou `/resultats` | [Docker](docker.md) |
| `exec format error` sur ARM64 / NAS Synology | [Docker](docker.md) |
| Chemins `/mnt/c/` non montés correctement | [Docker](docker.md) |
| Pipeline JSON : erreur jq, parse error | [Pipeline](pipeline.md) |
| Champ `op` / `type` non reconnu | [Pipeline](pipeline.md) |
| Pipeline s'arrête à mi-exécution | [Pipeline](pipeline.md) |
| Chemins relatifs non résolus dans le pipeline | [Pipeline](pipeline.md) |
| `report.html` absent ou vide | [Résultats](results.md) |
| `RESULTATS_DIR` ignoré, résultats écrits ailleurs | [Résultats](results.md) |
| Résultats écrasés à chaque exécution | [Résultats](results.md) |
| `failed.txt` absent malgré exit 1 | [Résultats](results.md) |

---

## Ouvrir une issue GitHub

Inclure systématiquement :

1. Sortie de `bash hash-tool version`
2. Sortie de `bash hash-tool check-env`
3. Commande exacte lancée
4. Sortie complète (avec `bash -x hash-tool <commande>` pour le mode trace)
5. OS et version (`uname -a`)
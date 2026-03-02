# Troubleshooting — Résultats

---

## `report.html` absent ou vide

**Symptôme** : le fichier `report.html` est absent du dossier de résultats,
ou présent mais de taille 0.

**Cause** : `reports/template.html` introuvable au moment de la génération.
`report.sh` cherche le template relativement à `SCRIPT_DIR` (répertoire de `integrity.sh`).

**Diagnostic** :

```bash
# Vérifier que le template est présent
ls reports/template.html

# Vérifier que SCRIPT_DIR résout correctement
grep "SCRIPT_DIR" src/integrity.sh
```

**Solution** :

```bash
# Vérifier depuis la racine du dépôt
ls -la reports/template.html

# Si absent, le restaurer depuis git
git checkout reports/template.html
```

En mode Docker : le template est copié dans l'image lors du build.
Si vous utilisez une image outdatée, rebuilder :

```bash
docker build -t hash_tool .
```

---

## `modifies.b3` liste des fichiers visiblement non modifiés

**Symptôme** : `compare` retourne des centaines de fichiers comme modifiés alors
que les données n'ont pas changé. `modifies.b3` contient des fichiers dont le
contenu est identique.

**Cause** : les deux bases ont été calculées depuis des répertoires de travail
différents — les préfixes de chemins diffèrent, donc `compare` ne peut pas faire
correspondre les entrées.

**Diagnostic** :

```bash
# Comparer les préfixes des deux bases
head -1 hashes_source.b3
head -1 hashes_destination.b3
# Si les préfixes diffèrent (./data/ vs ./), c'est la cause
```

**Solution** : recalculer les deux bases depuis le même répertoire parent.
Voir [Troubleshooting — Exécution](execution.md) pour le détail complet.

---

## `RESULTATS_DIR` ignoré — résultats écrits ailleurs

**Symptôme** : les résultats apparaissent dans un dossier inattendu
(souvent `~/integrity_resultats/`) au lieu du dossier configuré.

**Priorité de résolution :**

1. Argument `-save <dossier>` (priorité maximale)
2. Variable d'environnement `RESULTATS_DIR`
3. Valeur par défaut : `~/integrity_resultats/`

**Diagnostic** :

```bash
echo $RESULTATS_DIR
```

Si vide ou non défini, la valeur par défaut s'applique.

**Solution** :

```bash
# Via argument (recommandé)
bash hash-tool verify -base hashes.b3 -data ./donnees -save /srv/resultats

# Via variable d'environnement
export RESULTATS_DIR=/srv/resultats
bash hash-tool verify -base hashes.b3 -data ./donnees
```

**En mode Docker** : s'assurer que `RESULTATS_DIR` est configuré dans `docker-compose.yml`
ou passé via `-e` lors d'un appel `docker run` direct. Si absent, les résultats sont écrits
dans le conteneur et perdus à l'arrêt. En utilisation normale via `bash hash-tool`, ce cas
ne se produit pas — `hash-tool` gère le volume automatiquement.

---

## Résultats écrasés à chaque exécution

**Comportement attendu** : le dossier de résultats est recréé à chaque exécution.
Les résultats précédents sont écrasés. C'est intentionnel.

**Pour conserver l'historique**, utiliser un chemin horodaté avec `-save` :

```bash
bash hash-tool verify \
  -base ./bases/hashes.b3 \
  -data ./donnees \
  -save ./resultats/$(date +%Y%m%d_%H%M%S)
```

Ou via une variable dans un script cron :

```bash
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
bash hash-tool verify -base hashes.b3 -data ./donnees -save "./resultats/$TIMESTAMP"
```

---

## `failed.txt` absent alors que `verify` a retourné exit 1

**Symptôme** : `verify` retourne exit 1 mais `failed.txt` est absent du dossier
de résultats.

**Cause** : `verify` retourne exit 1 dans deux cas distincts :
- `STATUT : ECHEC` — corruption détectée → `failed.txt` produit
- `STATUT : ERREUR` — erreur technique (base invalide, fichier inaccessible, b3sum en échec)
  → pas de `failed.txt`, seulement `recap.txt`

**Diagnostic** :

```bash
cat ~/integrity_resultats/resultats_*/recap.txt | grep STATUT
# STATUT : ECHEC  -> failed.txt présent
# STATUT : ERREUR -> erreur technique, consulter la sortie de la commande
```
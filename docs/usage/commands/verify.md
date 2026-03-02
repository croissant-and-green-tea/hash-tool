# verify

Relit un fichier `.b3` et recalcule les empreintes BLAKE3 pour détecter toute modification,
disparition ou erreur d'accès. C'est l'opération de contrôle d'intégrité au sens strict.

---

## Syntaxe

```bash
bash src/integrity.sh verify <base.b3> [dossier]
```

| Argument | Obligatoire | Description |
|---|---|---|
| `<base.b3>` | Oui | Fichier de base contenant les empreintes de référence |
| `[dossier]` | Non | Répertoire de travail à utiliser pour résoudre les chemins. Si absent, le répertoire courant est utilisé. |

Option globale applicable :

| Option | Description |
|---|---|
| `--quiet` | Supprime toute sortie terminal. Les fichiers de résultats sont quand même produits. |

---

## Comportement

1. **Validation** : vérifie que `<base.b3>` existe et respecte le format b3sum (hash 64 chars +
   deux espaces + chemin). Erreur immédiate sinon.
2. **Résolution du chemin absolu** : le chemin de la base est converti en absolu avant tout
   `cd`, pour rester valide après changement de répertoire.
3. **Affichage du sidecar** : si `<base.b3>.meta.json` existe, son contenu est affiché en tête
   d'exécution (sauf `--quiet`). Permet de confirmer que l'on vérifie la bonne base.
4. **Changement de répertoire** : si `[dossier]` est fourni, `cd` vers ce dossier avant
   la vérification. Les chemins relatifs dans la base sont résolus depuis ce dossier.
5. **Vérification** : `b3sum --check <base.b3>` recalcule chaque empreinte et compare.
   Trois catégories de résultats :
   - `OK` — hash identique, fichier intègre
   - `FAILED` — hash différent, contenu modifié
   - Erreur — fichier inaccessible ou disparu
6. **Fichiers de résultats** : écrits dans `$RESULTATS_DIR/resultats_<nom_base>/`.
   Si ce dossier existe déjà (run précédent), un horodatage est ajouté au nom pour éviter
   l'écrasement.

---

## Fichiers produits

Les résultats sont toujours écrits dans le dossier de résultats, même si tout est OK.

### `recap.txt` — toujours produit

Synthèse de l'opération :

```
========================================
  STATUT : OK
========================================

Commande  : integrity.sh verify hashes.b3
Date      : Fri Feb 28 14:00:00 UTC 2026
Base      : /srv/bases/hashes.b3

OK        : 147
```

En cas d'échec :

```
========================================
  STATUT : ECHEC
========================================

Commande  : integrity.sh verify hashes.b3
Date      : Fri Feb 28 14:00:00 UTC 2026
Base      : /srv/bases/hashes.b3

OK        : 145
FAILED    : 2  <- voir failed.txt
```

### `failed.txt` — produit uniquement en cas d'anomalie

Liste des fichiers en échec avec leur statut :

```
========================================
  FICHIERS EN ECHEC
========================================

./données/export.csv: FAILED
./rapport-2024.pdf: FAILED (No such file or directory)
```

`FAILED` seul signifie que le fichier existe mais que son contenu a changé (hash différent).
`FAILED (No such file or directory)` signifie que le fichier a disparu du disque.

Si aucune anomalie n'est détectée, `failed.txt` n'est pas créé (ou supprimé s'il existait
d'un run précédent dans le même dossier).

---

## Codes de sortie

| Code | Signification |
|---|---|
| `0` | Intégrité confirmée — tous les fichiers sont intègres |
| `1` | Anomalie détectée (fichiers modifiés ou disparus) **ou** erreur d'exécution |

!!! warning "Distinction anomalie / erreur"
    Le code `1` couvre deux cas distincts : une corruption détectée (comportement attendu)
    et une erreur technique (base introuvable, `b3sum` absent). Le `recap.txt` permet de
    distinguer les deux : statut `ECHEC` pour une corruption, statut `ERREUR` pour une
    erreur technique.

---

## Répertoire de travail

!!! warning "Point critique"
    Les chemins dans le `.b3` sont relatifs au répertoire de travail au moment du `compute`.
    Le `verify` doit être lancé depuis le même répertoire, ou le dossier équivalent doit
    être passé en second argument.

    **Exemple :**

    ```bash
    # compute lancé depuis /home/user/projet
    cd /home/user/projet
    bash src/integrity.sh compute ./data hashes.b3
    # -> chemins dans hashes.b3 : ./data/fichier.txt

    # verify correct : même répertoire de travail
    cd /home/user/projet
    bash src/integrity.sh verify hashes.b3

    # verify avec dossier explicite (utile en Docker ou CI)
    bash src/integrity.sh verify /bases/hashes.b3 /home/user/projet
    ```

    Voir [Troubleshooting — chemins relatifs](../../troubleshooting/execution.md).

---

## Dossier de résultats

Par défaut : `~/integrity_resultats/resultats_<nom_base>/`.

Surchargeable via la variable d'environnement `RESULTATS_DIR` :

```bash
RESULTATS_DIR=/srv/audits bash src/integrity.sh verify hashes.b3
```

Le nom du dossier est dérivé du nom de la base : `hashes.b3` -> `resultats_hashes`.
Si ce dossier existe déjà, un horodatage est ajouté : `resultats_hashes_20260228-140000`.

---

## Exemples

### Vérification nominale

```bash
cd /home/user/projet
bash src/integrity.sh verify hashes.b3
```

```
--- Métadonnées (sidecar) ---
{
  "created_by": "2.0.0",
  "date": "2026-02-28T14:00:00Z",
  "comment": "Snapshot avant archivage",
  ...
}
-----------------------------
Vérification OK - 147 fichiers intègres.
Résultats dans : ~/integrity_resultats/resultats_hashes
  recap.txt
```

### Avec dossier explicite

Utile quand la base est stockée ailleurs que dans le répertoire de travail :

```bash
bash src/integrity.sh verify /srv/bases/hashes.b3 /home/user/projet
```

### En mode silencieux pour un script

```bash
bash src/integrity.sh --quiet verify hashes.b3
if [ $? -ne 0 ]; then
    echo "ANOMALIE DÉTECTÉE - voir $RESULTATS_DIR" >&2
    exit 1
fi
```

### Intégration cron

```bash
# /etc/cron.d/hash_tool
0 3 * * * root cd /opt/hash-tool && bash hash-tool verify \
  -base /srv/bases/hashes.b3 -data /srv/donnees -quiet \
  >> /var/log/hash_tool.log 2>&1 || echo "ECHEC $(date)" >> /var/log/hash_tool_alerts.log
```

---

## Erreurs fréquentes

**`FAILED (No such file or directory)`**
Le fichier existait au moment du `compute` mais a disparu. Vérifier s'il a été déplacé,
renommé ou supprimé.

**Tous les fichiers en FAILED**
Répertoire de travail incorrect. Le `verify` est lancé depuis un dossier différent de celui
du `compute`. Passer le bon dossier en second argument ou se positionner dans le bon répertoire.
Voir [Troubleshooting](../../troubleshooting/execution.md).

**`fichier .b3 introuvable`**
Le chemin passé en premier argument est incorrect ou relatif à un mauvais répertoire courant.
Utiliser un chemin absolu pour éviter toute ambiguïté.

---

## Voir aussi

- [compute](compute.md) — calculer une base d'empreintes
- [compare](compare.md) — comparer deux bases
- [Fichiers de résultats](../../reference/output-files.md) — description complète de `recap.txt` et `failed.txt`
- [Troubleshooting — exécution](../../troubleshooting/execution.md) — problèmes de chemins relatifs
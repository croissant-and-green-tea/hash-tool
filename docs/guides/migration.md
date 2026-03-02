# Guide — Vérification d'une migration

Certifier qu'une copie, migration ou transfert de données est parfait :
chaque fichier de la source est présent et identique dans la destination.

---

## Cas d'usage

- Copie de disque dur vers un NAS
- Migration d'un serveur vers un autre
- Transfert d'archives vers un stockage froid
- Duplication d'une partition VeraCrypt
- Sauvegarde rsync — vérifier que rsync n'a pas introduit de corruption

---

## Workflow complet

### 1. Calculer les empreintes de la source (avant migration)

```bash
bash hash-tool compute \
  -data /chemin/vers/source \
  -save /chemin/vers/bases \
  -meta "Source avant migration - $(date +%Y-%m-%d)"
```

!!! tip "Faire le compute avant la migration"
    Calculer les empreintes **avant** de lancer la migration garantit un état
    de référence non altéré. Si vous calculez après, vous ne pouvez pas distinguer
    une corruption en transit d'une corruption déjà présente dans la source.

### 2. Exécuter la migration

Rsync, cp, robocopy, ou tout autre outil de copie.

### 3. Calculer les empreintes de la destination

```bash
bash hash-tool compute \
  -data /chemin/vers/destination \
  -save /chemin/vers/bases \
  -meta "Destination après migration - $(date +%Y-%m-%d)"
```

### 4. Comparer les deux bases

```bash
bash hash-tool compare \
  -old /chemin/vers/bases/hashes_source.b3 \
  -new /chemin/vers/bases/hashes_destination.b3 \
  -save /chemin/vers/resultats/migration-$(date +%Y-%m-%d)
```

### 5. Lire le rapport

```
recap.txt — modifiés: 0, disparus: 0, nouveaux: 0
```

**Migration validée si et seulement si : 0 modifié + 0 disparu + 0 nouveau.**

---

## Interpréter les écarts

| Résultat | Signification | Action |
|---|---|---|
| **Modifiés > 0** | Hash différent entre source et destination | Erreur de copie ou corruption en transit — recopier les fichiers concernés depuis `modifies.b3` |
| **Disparus > 0** | Fichiers non transférés | Identifier depuis `disparus.txt` et relancer le transfert |
| **Nouveaux > 0** | Fichiers présents en destination absents de la source | Fichiers système, logs, index créés par l'OS ou l'outil de copie — qualifier et décider |

---

## Pipeline recommandé

Enchaîner compute source + verify immédiat + compute destination + compare
en une seule commande via `pipeline-migration.json` (disponible dans `examples/pipelines/`) :

```bash
bash hash-tool runner -pipeline ./examples/pipelines/pipeline-migration.json
```

L'étape `verify` intermédiaire détecte un problème de compute avant de lancer
la migration — évite de comparer une base corrompue avec la destination.

Adapter les chemins dans le fichier avant usage :

```json
{
  "pipeline": [
    {
      "type": "compute",
      "params": {
        "input":      "/chemin/vers/source",
        "output_dir": "/chemin/vers/bases",
        "filename":   "hashes_source.b3"
      },
      "meta": { "comment": "Source avant migration" }
    },
    {
      "type": "verify",
      "params": {
        "input": "/chemin/vers/source",
        "base":  "/chemin/vers/bases/hashes_source.b3"
      }
    },
    {
      "type": "compute",
      "params": {
        "input":      "/chemin/vers/destination",
        "output_dir": "/chemin/vers/bases",
        "filename":   "hashes_destination.b3"
      },
      "meta": { "comment": "Destination après migration" }
    },
    {
      "type": "compare",
      "params": {
        "base_a":    "/chemin/vers/bases/hashes_source.b3",
        "base_b":    "/chemin/vers/bases/hashes_destination.b3",
        "resultats": "/chemin/vers/resultats"
      }
    }
  ]
}
```

---

## Cas particulier — Source et destination sur des montages différents

Quand source et destination sont sur des disques ou machines différentes,
utiliser des chemins absolus dans les deux `compute` et s'assurer que
les deux bases sont sauvegardées dans le **même dossier** pour que `compare`
puisse les lire.

!!! warning "Répertoire de travail cohérent"
    Les chemins dans les `.b3` sont relatifs au répertoire de travail au moment
    du `compute`. Si les deux `compute` sont lancés depuis des répertoires différents,
    les préfixes de chemin dans les bases seront différents et `compare` signalera
    tous les fichiers comme modifiés (faux positifs).

    Solution : toujours utiliser des chemins absolus avec `-data /chemin/absolu`.

---

## Archiver les bases après validation

Une fois la migration validée, archiver les deux bases avec la date :

```bash
mv /chemin/vers/bases/hashes_source.b3 \
   /chemin/vers/bases/hashes_source_$(date +%Y-%m-%d).b3
mv /chemin/vers/bases/hashes_destination.b3 \
   /chemin/vers/bases/hashes_destination_$(date +%Y-%m-%d).b3
```

Ces bases constituent une preuve horodatée de l'état des données à la date de migration.
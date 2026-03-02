# Docker Compose

`docker-compose.yml` préconfigure les volumes pour que `hash-tool` puisse utiliser
le mode Docker sans avoir à spécifier les chemins à chaque commande.

L'interface reste **toujours** `bash hash-tool <commande>` — Docker Compose est
une configuration de l'environnement d'exécution, pas une interface alternative.

---

## Configuration initiale

Adapter la section `x-volumes` en tête du fichier :

```yaml
x-volumes:
  data:      &vol-data      /chemin/vers/donnees     # données à hacher (lecture seule)
  bases:     &vol-bases     /chemin/vers/bases        # fichiers .b3
  pipelines: &vol-pipelines /chemin/vers/pipelines   # fichiers pipeline.json
  resultats: &vol-resultats /chemin/vers/resultats   # résultats compare/verify
```

C'est le **seul endroit à modifier** — tous les services référencent ces chemins
via les ancres YAML (`*vol-data`, `*vol-bases`, etc.).

### Exemples de chemins selon l'environnement

| Environnement | Exemple |
|---|---|
| Linux / serveur | `/srv/hash-tool/données` |
| macOS | `/Users/moi/Documents/données` |
| WSL2 | `/home/wsl-acer/données` (pas `/mnt/c/...`) |
| NAS Synology | `/volume1/données` |

!!! warning "WSL2"
    Ne pas utiliser les chemins `/mnt/c/...` — Docker Desktop ne monte pas
    correctement les chemins Windows comme volumes. Utiliser le filesystem Linux
    natif (`/home/...`).

---

## Services

Trois services sont définis dans `docker-compose.yml` :

### `integrity` — compute, verify, compare

Service utilisé par `hash-tool` pour les commandes unitaires. Il est invoqué
automatiquement par `hash-tool` en mode Docker — pas besoin de l'appeler manuellement.

### `pipeline` — runner.sh

Service utilisé par `hash-tool runner`. Lance `runner.sh` avec le pipeline JSON
monté via le volume `/pipelines`.

### `cron` — vérification périodique

Service optionnel, désactivé par défaut (profil `cron`). Voir [Automatisation](../guides/automation.md).

---

## Utilisation

Avec Docker Compose configuré, `hash-tool` utilise automatiquement les services
et volumes définis — aucune option supplémentaire n'est requise :

```bash
# Exactement les mêmes commandes qu'en mode natif
bash hash-tool compute -data /chemin/vers/donnees -save /chemin/vers/bases
bash hash-tool verify  -base /chemin/vers/bases/hashes.b3 -data /chemin/vers/donnees
bash hash-tool compare -old /chemin/vers/bases/old.b3 -new /chemin/vers/bases/new.b3
bash hash-tool runner  -pipeline /chemin/vers/pipelines/pipeline.json
```

`hash-tool` détecte le mode Docker, construit les `-v` appropriés et dispatche
vers le bon service.

---

## Service cron

Activation :

```bash
docker compose --profile cron up -d cron
```

Variables de configuration dans `docker-compose.yml` :

| Variable | Défaut | Description |
|---|---|---|
| `CRON_SCHEDULE` | `0 3 * * *` | Expression cron (03h00 chaque nuit) |
| `CRON_BASE` | `/bases/hashes.b3` | Base à vérifier |

!!! warning "Image étendue requise"
    Le service `cron` nécessite une image dérivée avec `crond` installé.
    Voir [Automatisation](../guides/automation.md) pour le setup complet.

---

## Exemple complet — workflow audit

```bash
# 1. Configurer les chemins dans docker-compose.yml (une seule fois)
# data:      /srv/archives
# bases:     /srv/bases
# resultats: /srv/resultats

# 2. Calculer les empreintes
bash hash-tool compute -data /srv/archives -save /srv/bases -meta "Avant archivage"

# 3. Vérifier l'intégrité
bash hash-tool verify -base /srv/bases/hashes_archives.b3 -data /srv/archives

# 4. Après une migration, comparer deux états
bash hash-tool compare \
  -old /srv/bases/hashes_avant.b3 \
  -new /srv/bases/hashes_apres.b3
```
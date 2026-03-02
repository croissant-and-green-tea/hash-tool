# Guide — Automatisation et planification

---

## Vérification planifiée en cron Linux

Lancer `verify` automatiquement chaque nuit et enregistrer le résultat dans un log :

```bash
crontab -e
```

```
# hash_tool - vérification nocturne à 03h00
0 3 * * * cd /chemin/vers/hash-tool && bash hash-tool verify \
  -base /srv/bases/hashes_archives.b3 \
  -data /srv/archives \
  -quiet \
  >> /var/log/hash_tool.log 2>&1
```

Le `cd` en tête garantit que `hash-tool` résout `src/integrity.sh` correctement.
`-quiet` supprime la sortie terminal — seuls les logs fichiers sont conservés.

---

## Script wrapper avec alerte

Pour déclencher une alerte en cas d'anomalie, exploiter le code de sortie `1` :

```bash
#!/usr/bin/env bash
# /usr/local/bin/hash-tool-check.sh

set -euo pipefail

HASH_TOOL_DIR="/chemin/vers/hash-tool"
BASE="/srv/bases/hashes_archives.b3"
DATA="/srv/archives"
LOG="/var/log/hash_tool.log"
EMAIL="admin@example.com"

cd "$HASH_TOOL_DIR"

if ! bash hash-tool verify -base "$BASE" -data "$DATA" -quiet >> "$LOG" 2>&1; then
  echo "ALERTE hash_tool : anomalie détectée sur $DATA" \
    | mail -s "[ALERTE] Intégrité compromise" "$EMAIL"
fi
```

Autres options d'alerte :

```bash
# Webhook Slack
curl -s -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-type: application/json' \
  -d '{"text":"ALERTE hash_tool : anomalie détectée"}'

# Notification système (systemd)
systemd-cat -t hash_tool echo "ALERTE : intégrité compromise"
```

---

## Service Docker cron

Le service `cron` dans `docker-compose.yml` est désactivé par défaut (profil `cron`).
L'image standard `hash_tool` ne contient pas `crond` — il faut une image étendue.

### Build de l'image étendue

Créer un `Dockerfile.cron` à la racine du projet :

```dockerfile
FROM hash_tool

RUN apk add --no-cache dcron

COPY docker/cron-entrypoint.sh /cron-entrypoint.sh
RUN chmod +x /cron-entrypoint.sh

ENTRYPOINT ["/cron-entrypoint.sh"]
```

Créer `docker/cron-entrypoint.sh` :

```bash
#!/usr/bin/env bash
set -euo pipefail

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
BASE="${CRON_BASE:-/bases/hashes.b3}"

echo "$SCHEDULE cd /app && /entrypoint.sh verify $BASE /data >> /var/log/cron.log 2>&1" \
  | crontab -

crond -f -l 2
```

Builder et activer :

```bash
docker build -f Dockerfile.cron -t hash_tool_cron .
docker compose --profile cron up -d cron
```

Variables de configuration dans `docker-compose.yml` :

```yaml
environment:
  - CRON_SCHEDULE=0 3 * * *
  - CRON_BASE=/bases/hashes.b3
```

---

## Intégration CI/CD (GitHub Actions)

Pour intégrer un contrôle d'intégrité dans un pipeline externe :

```yaml
- name: Vérifier l'intégrité des artefacts
  run: |
    git clone https://github.com/Alan45678/hash-tool /tmp/hash-tool
    chmod +x /tmp/hash-tool/hash-tool /tmp/hash-tool/src/integrity.sh
    cd /tmp/hash-tool

    # Calculer les empreintes des artefacts de build
    bash hash-tool compute -data ./dist -save /tmp/bases -meta "Build CI"

    # Vérifier contre une base de référence archivée
    bash hash-tool verify \
      -base ./bases/hashes_reference.b3 \
      -data ./dist \
      -save /tmp/resultats
```

---

## Rotation des logs

```bash
# /etc/logrotate.d/hash_tool
/var/log/hash_tool.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
}
```
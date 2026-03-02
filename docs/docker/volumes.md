# Volumes Docker

Référence interne des volumes utilisés par `hash-tool` en mode Docker.
Cette page est destinée aux cas avancés (débogage, CI sans `hash-tool`, NAS).

En utilisation normale, `hash-tool` construit les montages de volumes automatiquement
— vous n'avez pas à les gérer manuellement.

---

## Les quatre volumes

| Volume conteneur | Mode recommandé | Contenu |
|---|---|---|
| `/data` | `:ro` (lecture seule) | Données à hacher — le conteneur ne modifie jamais la source |
| `/bases` | lecture/écriture | Fichiers `.b3` et sidecars `.meta.json` |
| `/pipelines` | `:ro` | Fichiers `pipeline.json` |
| `/resultats` | lecture/écriture | Résultats `verify` et `compare` |

---

## Volumes requis par commande

| Commande | `/data` | `/bases` | `/pipelines` | `/resultats` |
|---|---|---|---|---|
| `compute` | ✓ `:ro` | ✓ écriture | — | — |
| `verify` | ✓ `:ro` | ✓ `:ro` | — | ✓ écriture |
| `compare` | — | ✓ `:ro` | — | ✓ écriture |
| `runner` | ✓ `:ro` | ✓ écriture | ✓ `:ro` | ✓ écriture |

`hash-tool` applique ces règles automatiquement lors de la construction des volumes.

---

## Usage avancé sans `hash-tool`

Ces exemples s'appliquent uniquement quand `hash-tool` n'est pas disponible :
CI bare Docker, NAS Synology sans bash moderne, débogage de l'entrypoint.

```bash
# compute
docker run --rm \
  -v /srv/donnees:/data:ro \
  -v /srv/bases:/bases \
  hash_tool compute /data /bases/hashes.b3

# verify
docker run --rm \
  -v /srv/donnees:/data:ro \
  -v /srv/bases:/bases:ro \
  -v /srv/resultats:/resultats \
  -e RESULTATS_DIR=/resultats \
  hash_tool verify /bases/hashes.b3 /data

# compare
docker run --rm \
  -v /srv/bases:/bases:ro \
  -v /srv/resultats:/resultats \
  -e RESULTATS_DIR=/resultats \
  hash_tool compare /bases/old.b3 /bases/new.b3

# runner
docker run --rm \
  -v /srv/donnees:/data:ro \
  -v /srv/bases:/bases \
  -v /srv/resultats:/resultats \
  -v /srv/pipelines/pipeline.json:/pipelines/pipeline.json:ro \
  -e RESULTATS_DIR=/resultats \
  hash_tool runner /pipelines/pipeline.json

# shell interactif (debug)
docker run --rm -it hash_tool shell
```

---

## Chemins hôte selon l'OS

| Environnement | Exemple chemin hôte |
|---|---|
| Linux / serveur | `/srv/hash-tool/donnees` |
| macOS | `/Users/moi/Documents/donnees` |
| WSL2 | `/home/wsl-acer/donnees` (pas `/mnt/c/...`) |
| NAS Synology | `/volume1/donnees` |

---

## Erreurs fréquentes

**Résultats écrits dans le conteneur et perdus**

`/resultats` non monté ou `RESULTATS_DIR` non défini. En utilisation normale via
`hash-tool`, ce cas ne se produit pas — `hash-tool` monte et configure le volume
automatiquement.

**Erreur "read-only file system"**

Tentative d'écriture sur un volume monté en `:ro`. `compute` doit écrire dans
`/bases` (lecture/écriture), pas dans `/data` (`:ro`).

**Base écrite dans `/data`**

Toujours écrire la base dans `/bases`, jamais dans `/data` monté en `:ro`.
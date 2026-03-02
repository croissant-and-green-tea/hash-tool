# Setup Docker

---

## Build de l'image

L'image n'est pas publiée sur Docker Hub — elle se construit depuis les sources.
Lancer depuis la racine du dépôt (présence du `Dockerfile`) :

```bash
docker build -t hash_tool .
```

Build multi-architecture pour ARM64 (NAS Synology, Raspberry Pi) :

```bash
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

Vérifier que l'image est disponible :

```bash
docker image inspect hash_tool
```

---

## Contenu de l'image

Base : **Alpine 3.19** (~5 Mo). Taille finale de l'image : ~15 Mo.

Packages installés via `apk` :

| Package | Rôle |
|---|---|
| `bash` | Interpréteur |
| `jq` | Lecture/écriture des sidecars JSON |
| `b3sum` | Calcul des empreintes BLAKE3 |
| `coreutils` | `wc`, `du`, `date`, etc. |
| `findutils` | `find` récursif |
| `grep` | Filtrage des résultats |

Tous les packages viennent des dépôts Alpine — aucun binaire téléchargé depuis GitHub.
Avantage : builds reproductibles, pas de dépendance à la disponibilité de GitHub Releases.

---

## Entrypoint

`docker/entrypoint.sh` dispatche les commandes vers `integrity.sh` ou `runner.sh`.

Commandes supportées :

| Commande | Dispatch |
|---|---|
| `compute` | `integrity.sh compute ...` |
| `verify` | `integrity.sh verify ...` |
| `compare` | `integrity.sh compare ...` |
| `runner` | `runner.sh <pipeline.json>` |
| `shell` | `/bin/bash` interactif (debug) |
| `help` | Affiche l'aide |
| `version` | Affiche la version |
| Commande inconnue | Exit non-zéro |

```bash
# Ouvrir un shell dans le conteneur pour déboguer
docker run --rm -it hash_tool shell
```

---

## Variables d'environnement

| Variable | Défaut dans le conteneur | Description |
|---|---|---|
| `RESULTATS_DIR` | `/resultats` | Dossier de sortie des résultats `verify` et `compare` |

`RESULTATS_DIR` doit correspondre à un volume monté. Si `/resultats` n'est pas monté,
les résultats sont écrits à l'intérieur du conteneur et perdus à l'arrêt.

```bash
# Passer RESULTATS_DIR explicitement
docker run --rm \
  -v /mon/dossier/resultats:/resultats \
  -e RESULTATS_DIR=/resultats \
  hash_tool verify /bases/hashes.b3 /data
```

---

## Mise à jour de l'image

Après modification du code source, rebuilder l'image pour que les changements
soient pris en compte :

```bash
docker build -t hash_tool .
```

!!! warning "Image obsolète"
    Si `hash-tool` produit des résultats inattendus en mode Docker, vérifier que
    l'image est à jour par rapport au code source. Une image buildée avant un
    correctif n'intègre pas ce correctif.

---

## `.dockerignore`

Le `.dockerignore` exclut du contexte de build ce qui n'est pas nécessaire dans
l'image : `tests/`, `docs/`, `examples/`, `*.b3`, fichiers temporaires.
Le contexte envoyé au daemon Docker est minimal (~quelques Ko).
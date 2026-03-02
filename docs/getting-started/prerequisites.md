# Prérequis

---

## Mode natif

Le mode natif est recommandé pour tous les usages réguliers. Il est plus rapide
et ne nécessite pas Docker.

| Dépendance | Version minimale | Rôle |
|---|---|---|
| `bash` | 4.0 | Interpréteur - bash 3.x (macOS système) est incompatible |
| `b3sum` | toute version récente | Calcul des empreintes BLAKE3 |
| `jq` | 1.6 | Lecture et écriture des sidecars `.meta.json` |

### Vérification

```bash
bash --version   # doit afficher "version 4." ou supérieur
b3sum --version
jq --version
```

### Installation par OS

**Debian / Ubuntu**

```bash
sudo apt-get update
sudo apt-get install -y jq

# b3sum : absent des dépôts par défaut, installer le binaire statique
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum
```

**Alpine Linux**

```bash
apk add --no-cache jq
apk add --no-cache b3sum   # dépôt community requis
```

**macOS**

```bash
brew install jq b3sum bash
```

!!! warning "bash sur macOS"
    Le bash système macOS (`/bin/bash`) est en version 3.2 pour des raisons de licence.
    Il est incompatible avec hash_tool. Après `brew install bash`, utiliser
    `/opt/homebrew/bin/bash` ou ajouter `/opt/homebrew/bin` en tête de `PATH`.
    Ne pas remplacer `/bin/bash` système.

**WSL2 (Windows)**

```bash
sudo apt-get update
sudo apt-get install -y jq
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum
```

!!! tip "WSL2 : privilégier le mode natif"
    Le mode Docker sur WSL2 est fonctionnel mais lent (overhead conteneur + pont réseau).
    Installer `b3sum` et `jq` nativement - `hash-tool` bascule automatiquement en mode natif.

---

## Mode Docker

Le mode Docker est utile quand l'installation native n'est pas possible :
NAS Synology, environnement restrictif, ou machine sans droits d'installation.

| Dépendance | Version minimale | Rôle |
|---|---|---|
| `docker` | 20.10 | Moteur de conteneurs |
| image `hash_tool` | - | Image buildée localement (non publiée sur Docker Hub) |

### Vérification

```bash
docker --version
docker image inspect hash_tool   # doit retourner des infos sur l'image
```

### Build de l'image

L'image n'est pas publiée sur Docker Hub - elle doit être buildée depuis les sources :

```bash
cd /chemin/vers/hash-tool
docker build -t hash_tool .
```

Build multi-architecture (ARM64 pour NAS Synology) :

```bash
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

!!! warning "Performance Docker sur WSL2"
    Sur WSL2, Docker accède aux volumes via un pont réseau. Combiné au fait que
    `b3sum` est appelé une fois par fichier, les performances sont très dégradées
    sur de grands volumes de fichiers. Voir
    [Troubleshooting Docker](../troubleshooting/docker.md) pour la solution.

!!! warning "Emplacement du projet sur WSL2"
    Le projet doit être cloné dans le filesystem Linux natif (`/home/...`),
    pas sur le disque Windows (`/mnt/c/...`). Docker Desktop ne monte pas
    correctement les chemins `/mnt/c/` comme volumes.

    ```bash
    # Correct
    cd ~
    git clone <url> hash-tool

    # Incorrect - volumes non montés
    cd /mnt/c/Users/moi/Desktop
    git clone <url> hash-tool
    ```

---

## Compatibilité OS

| Environnement | Mode natif | Mode Docker | Notes |
|---|---|---|---|
| Ubuntu 22.04 / 24.04 | ✓ | ✓ | Environnement de référence CI |
| Debian 11+ | ✓ | ✓ | |
| Alpine Linux 3.18+ | ✓ | ✓ | b3sum via dépôt community |
| macOS 13+ | ✓ | ✓ | bash via brew obligatoire |
| Windows WSL2 | ✓ | ✓ (lent) | Projet dans `/home/`, pas `/mnt/c/` |
| NAS Synology (ARM64) | - | ✓ | Build `--platform linux/arm64` |
| Raspberry Pi (ARM64) | ✓ | ✓ | b3sum binaire ARM64 requis |

---

## Détection automatique du mode d'exécution

`hash-tool` détecte automatiquement le mode au démarrage :

1. **Natif** : si `b3sum`, `jq` et `src/integrity.sh` sont disponibles -> mode natif
2. **Docker** : si l'image `hash_tool` est présente -> mode Docker
3. **Erreur** : aucun mode disponible -> message d'erreur explicite

```bash
# Vérifier le mode sélectionné
bash hash-tool check-env
```

La dernière ligne de `check-env` indique le mode actif :
```
-> Exécution native active
```
ou
```
-> Exécution Docker active (fallback)
```
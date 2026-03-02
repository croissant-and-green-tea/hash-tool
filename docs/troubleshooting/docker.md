# Troubleshooting — Docker

---

## Exécution Docker très lente sur WSL2

**Symptôme** : `compute` sur quelques fichiers prend plusieurs secondes.
Sur 1000+ fichiers, c'est inutilisable.

**Cause** : trois facteurs cumulés :
- Overhead de démarrage du conteneur (~1-2s par appel)
- `b3sum` appelé une fois par fichier (pas en batch)
- Accès aux volumes WSL2 via un pont réseau lent (filesystem Windows bridgé)

**Solution recommandée** : installer les dépendances nativement dans WSL2.
`hash-tool` bascule automatiquement en mode natif si `b3sum` et `jq` sont disponibles.

```bash
# Ubuntu / WSL2
sudo apt-get install -y jq
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum

# Vérifier le mode actif
bash hash-tool check-env
# -> Exécution native active
```

Gain de performance typique en mode natif sur WSL2 : 10x à 100x selon le volume.

---

## Fichiers `.b3` non créés sur l'hôte après `compute`

**Symptôme** : `compute` affiche `Base enregistrée` mais aucun fichier `.b3`
n'apparaît dans le dossier hôte.

**Cause 1 — version antérieure à 2.0.2** : bug dans `_run_docker_integrity` —
le chemin passé au conteneur manquait le préfixe `/bases/`. La base était écrite
dans `/app` à l'intérieur du conteneur au lieu de `/bases` monté.

**Solution** : mettre à jour vers la version ≥ 2.0.2.

**Cause 2 — chemin hôte relatif dans `-v`** : Docker exige des chemins absolus
pour les montages de volumes.

**Diagnostic :**

```bash
# Tester l'accès au volume depuis l'intérieur du conteneur
docker run --rm -v "$(pwd)/bases":/bases hash_tool shell
ls /bases
```

**Solution** :

```bash
# Utiliser $(pwd) pour résoudre en absolu
docker run --rm \
  -v "$(pwd)/data":/data:ro \
  -v "$(pwd)/bases":/bases \
  hash_tool compute /data /bases/hashes.b3
```

---

## Permission denied sur `/bases` ou `/resultats`

**Symptôme** : erreur `Permission denied` lors de l'écriture du `.b3` ou des résultats.

**Cause** : le conteneur Alpine tourne en root (UID 0). Si le dossier hôte appartient
à un autre utilisateur avec des permissions restrictives, l'écriture échoue.

**Diagnostic :**

```bash
ls -la /chemin/vers/bases
# Si "drwx------" ou propriétaire différent -> problème de permissions
```

**Solution 1** : faire tourner le conteneur avec l'UID de l'utilisateur hôte :

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v /srv/bases:/bases \
  hash_tool compute /data /bases/hashes.b3
```

**Solution 2** : élargir les permissions du dossier hôte (moins recommandé) :

```bash
chmod 777 /chemin/vers/bases
```

---

## `/data` monté en `:ro` mais `compute` échoue

**Symptôme** : `Permission denied` sur l'écriture du `.b3`.

**Cause** : tentative d'écrire la base dans `/data` monté en lecture seule.
`compute` doit écrire dans `/bases`, pas dans `/data`.

**Solution** : séparer les volumes source et bases :

```bash
# Mauvais — compute ne peut pas écrire dans /data:ro
docker run --rm \
  -v /srv/donnees:/data:ro \
  hash_tool compute /data /data/hashes.b3

# Correct — base écrite dans /bases séparé
docker run --rm \
  -v /srv/donnees:/data:ro \
  -v /srv/bases:/bases \
  hash_tool compute /data /bases/hashes.b3
```

---

## Fallback Docker non déclenché

**Symptôme** : `check-env` signale `EXEC_MODE=none` alors que Docker est installé
et `b3sum` est absent.

**Cause** : `_docker_available()` vérifie `docker image inspect hash_tool` —
si l'image n'est pas buildée localement, le fallback ne s'active pas.

**Solution** :

```bash
docker build -t hash_tool .
bash hash-tool check-env
# -> Exécution Docker active (fallback)
```

---

## ARM64 / NAS Synology : `exec format error`

**Symptôme** : `exec format error` ou `standard_init_linux.go: exec user process
caused: exec format error` au lancement du conteneur.

**Cause** : image buildée pour `amd64`, exécutée sur un hôte `arm64`.

**Diagnostic :**

```bash
# Architecture de l'hôte
uname -m
# aarch64 -> ARM64

# Architecture de l'image
docker image inspect hash_tool | grep Architecture
```

**Solution** : builder l'image pour la bonne architecture :

```bash
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

Puis adapter la variable `HASH_TOOL_DOCKER_IMAGE` :

```bash
export HASH_TOOL_DOCKER_IMAGE=hash_tool:arm64
bash hash-tool check-env
```

---

## Chemins `/mnt/c/` non montés correctement (WSL2)

**Symptôme** : `compute` tourne sans erreur mais les fichiers `.b3` n'apparaissent
pas dans le dossier Windows attendu, ou `verify` ne trouve pas les données.

**Cause** : Docker Desktop sur WSL2 ne monte pas les chemins `/mnt/c/...` (filesystem
Windows) comme volumes Docker de manière fiable.

**Solution** : travailler exclusivement dans le filesystem Linux natif :

```bash
# Mauvais
cd /mnt/c/Users/moi/Documents/hash-tool
bash hash-tool compute -data /mnt/c/Users/moi/Documents/donnees ...

# Correct
cd ~/hash-tool
bash hash-tool compute -data ~/donnees ...
```

Si les fichiers doivent rester sur Windows, copier les résultats après exécution :

```bash
cp ~/bases/hashes.b3 /mnt/c/Users/moi/Desktop/
```
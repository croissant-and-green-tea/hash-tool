# Troubleshooting — Installation

---

## `b3sum` introuvable

**Symptôme** : `check-env` retourne `[KO] b3sum introuvable`.

**Cause** : absent des dépôts par défaut sur certaines distributions.

**Solution par OS :**

```bash
# Alpine (activer le dépôt community au préalable)
apk add --no-cache b3sum

# Ubuntu / Debian — via cargo
sudo apt-get install -y cargo
cargo install b3sum
# Le binaire est installé dans ~/.cargo/bin/ — ajouter au PATH

# Ubuntu / Debian — via binaire GitHub (sans cargo)
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum

# macOS
brew install b3sum

# WSL2 (Ubuntu) — même procédure que Debian
sudo wget https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_x64_musl \
  -O /usr/local/bin/b3sum
sudo chmod +x /usr/local/bin/b3sum
```

**Vérification :**

```bash
b3sum --version
```

---

## `jq` introuvable

**Symptôme** : `check-env` retourne `[KO] jq introuvable`.

```bash
# Ubuntu / Debian / WSL2
sudo apt-get install -y jq

# Alpine
apk add --no-cache jq

# macOS
brew install jq
```

---

## `bash` version insuffisante (< 4)

**Symptôme** : erreurs de syntaxe bash au lancement, ou `check-env` signale
`[KO] bash >= 4 requis`.

**Cause fréquente** : macOS — le bash système est la version 3.2 (Apple distribue
bash 3.x pour des raisons de licence GPLv2). La version 4+ est incompatible
avec cette licence et n'est pas fournie par Apple.

**Diagnostic :**

```bash
bash --version
# GNU bash, version 3.2.57(1)-release  ← trop ancien
```

**Solution (macOS) :**

```bash
brew install bash
# Utiliser le bash Homebrew pour lancer hash-tool
/opt/homebrew/bin/bash hash-tool check-env
```

!!! warning "Ne pas remplacer `/bin/bash` système sur macOS"
    Modifier `/bin/bash` peut casser des outils système. Utiliser le bash
    Homebrew explicitement, ou ajouter `/opt/homebrew/bin` en tête de `PATH`.

---

## `hash-tool` non exécutable

**Symptôme** : `Permission denied` ou `bash: hash-tool: command not found`.

**Cause 1** : `chmod +x` non appliqué après le clonage.

```bash
chmod +x hash-tool runner.sh src/integrity.sh src/lib/*.sh docker/entrypoint.sh
```

**Cause 2** : fichiers sur un système de fichiers FAT32 ou NTFS (les bits de
permission Unix sont ignorés).

**Diagnostic :**

```bash
ls -la hash-tool
# Si les permissions affichent "-rw-r--r--" sans "x", le chmod n'a pas été appliqué
# Si vous êtes sur /mnt/c/... (WSL2), c'est un filesystem Windows
df -T .
```

**Solution (filesystem Windows) :** cloner le dépôt sur un filesystem Linux natif :

```bash
cd ~
git clone https://github.com/croissant-and-green-tea/hash-tool
cd hash-tool
chmod +x hash-tool runner.sh src/integrity.sh
```

---

## Image Docker absente

**Symptôme** : `check-env` affiche `[--] Image Docker 'hash_tool' absente`
et le mode Docker ne s'active pas.

**Cause** : l'image n'est pas publiée sur Docker Hub — elle doit être buildée
localement depuis les sources.

**Solution :**

```bash
# Depuis la racine du dépôt (présence du Dockerfile requise)
docker build -t hash_tool .
```

**Erreur fréquente :** lancer le build depuis un sous-dossier.

```bash
# Mauvais — Dockerfile introuvable
cd src && docker build -t hash_tool .

# Correct
cd /chemin/vers/hash-tool && docker build -t hash_tool .
```

**Vérification :**

```bash
docker image inspect hash_tool
bash hash-tool check-env
```

---

## `integrity.sh` non exécutable (exit 126 en CI)

**Symptôme** : en CI ou après un `git clone` frais, les tests échouent avec
`exit code 126` et le message `integrity.sh non exécutable`.

**Cause** : les bits exécutables ont été perdus lors d'un commit sans
`git add --chmod=+x`.

**Solution (une fois pour toutes) :**

```bash
git add --chmod=+x src/integrity.sh runner.sh hash-tool src/lib/*.sh docker/entrypoint.sh
git commit -m "fix: restaurer bits exécutables"
git push
```

Une fois les permissions enregistrées dans git, elles sont préservées à chaque clone.
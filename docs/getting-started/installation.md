# Installation

---

## Installation native

### 1. Cloner le dépôt

```bash
git clone https://github.com/Alan45678/hash-tool
cd hash-tool
```

### 2. Appliquer les permissions

```bash
chmod +x hash-tool runner.sh src/integrity.sh
```

### 3. Vérifier l'installation

```bash
bash hash-tool check-env
```

Sortie attendue en mode natif :

```
=== check-env : Analyse de l'environnement ===

  [OK] b3sum disponible : b3sum 1.5.0
  [OK] jq disponible : jq-1.7.1
  [OK] bash 5.2.21(1)-release
  [OK] integrity.sh présent et exécutable : /chemin/hash-tool/src/integrity.sh
  [OK] runner.sh présent et exécutable : /chemin/hash-tool/runner.sh
  [OK] Image Docker 'hash_tool' disponible

  -> Exécution native active
```

Les indicateurs `[OK]` / `[KO]` signalent l'état de chaque dépendance.
La dernière ligne indique le mode qui sera utilisé pour toutes les commandes.

Si `b3sum` ou `jq` sont absents, la ligne correspondante affiche `[KO]` et
`hash-tool` basculera en mode Docker si l'image est disponible. Voir
[Prérequis](prerequisites.md) pour les commandes d'installation.

---

## Installation en mode Docker uniquement

Si vous ne souhaitez pas installer `b3sum` et `jq` nativement :

### 1. Cloner le dépôt

```bash
git clone https://github.com/Alan45678/hash-tool
cd hash-tool
chmod +x hash-tool
```

### 2. Construire l'image Docker

```bash
docker build -t hash_tool .
```

### 3. Vérifier

```bash
bash hash-tool check-env
```

Sortie attendue en mode Docker :

```
=== check-env : Analyse de l'environnement ===

  [KO] b3sum introuvable (requis pour exécution native)
  [KO] jq introuvable (requis pour pipelines JSON)
  [OK] bash 5.2.21(1)-release
  [KO] integrity.sh introuvable ou non exécutable
  [KO] runner.sh introuvable ou non exécutable
  [OK] Image Docker 'hash_tool' disponible

  -> Exécution Docker active (fallback)
```

!!! warning "WSL2 : cloner dans le filesystem Linux"
    Le projet doit être cloné dans `/home/...`, pas dans `/mnt/c/...`.
    Docker Desktop ne monte pas correctement les chemins Windows comme volumes.
    ```bash
    # Correct
    cd ~ && git clone https://github.com/Alan45678/hash-tool

    # Incorrect — volumes non montés
    cd /mnt/c/Users/moi/Desktop && git clone ...
    ```

---

## Build multi-architecture (ARM64)

Pour un NAS Synology ou Raspberry Pi :

```bash
docker build --platform linux/arm64 -t hash_tool:arm64 .
```

---

## Vérification finale

```bash
bash hash-tool version
```

```
hash-tool v2.0.0
```

```bash
bash hash-tool help
```

Affiche la liste des commandes disponibles. Si la commande retourne sans erreur,
l'installation est opérationnelle.
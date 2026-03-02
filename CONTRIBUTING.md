# Guide de contribution

## Prérequis

- bash >= 4, b3sum, jq, shellcheck
- Docker (pour les tests en mode conteneur)
- make
- git

## Démarrage
```bash
git clone https://github.com/hash_tool/hash_tool
cd hash_tool
chmod +x hash-tool runner.sh src/integrity.sh tests/*.sh
./hash-tool check-env
```

## Lancer les tests
```bash
# Tous les tests (recommandé)
make test

# Suites individuelles
cd tests && bash run_tests.sh
cd tests && bash run_tests_core.sh
cd tests && bash run_tests_pipeline.sh
```

Tous les tests doivent passer avant de soumettre une PR.

## Lint
```bash
make lint
```

Lance ShellCheck sur tous les scripts du projet. Aucun avertissement toléré.

## Autres commandes Makefile
```bash
make build-docker   # construit l'image Docker locale
make run-docs       # lance le serveur MkDocs sur http://127.0.0.1:8000
make clean          # supprime les artefacts générés (site/, fichiers /tmp)
```

## Standards de code

- Bash strict mode obligatoire : `set -euo pipefail` en tête de chaque script
- Fonctions documentées avec contrat d'entrée / contrat de sortie / effets de bord
- Nommage : fonctions internes préfixées `_`, commandes CLI préfixées `cmd_`
- Pas de dépendances externes au-delà de : bash, b3sum, jq, coreutils, findutils

## Structure des branches

- `main` : branche stable, protégée
- `feat/<nom>` : nouvelle fonctionnalité
- `fix/<nom>` : correction de bug
- `docs/<nom>` : modifications documentation uniquement

## Soumettre une PR

1. Créer une branche depuis `main`
2. Écrire ou mettre à jour les tests correspondants
3. S'assurer que `make test` et `make lint` passent intégralement
4. Mettre à jour `CHANGELOG.md` dans la section `[Unreleased]`
5. Ouvrir la PR avec une description du problème résolu et de l'approche choisie

## Ajouter un test

Les tests suivent la convention de `run_tests.sh` : chaque cas est une fonction
`test_<nom>()` qui retourne 0 (succès) ou 1 (échec). Les données de test
se placent dans `examples/` en suivant la structure existante.

## Signaler un bug

Ouvrir une issue GitHub avec :
- Version : `hash-tool version`
- Environnement : sortie de `hash-tool check-env`
- Commande exacte exécutée
- Sortie terminal complète
- Comportement attendu vs comportement observé

## Signaler une vulnérabilité

Ne pas ouvrir d'issue publique. Voir [SECURITY.md](SECURITY.md).
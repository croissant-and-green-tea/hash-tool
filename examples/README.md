

# examples/

Ce dossier contient les données de démonstration et les pipelines d'exemple du projet.
Il ne doit pas être modifié pour un usage en production - il sert de support aux
tutoriels et aux tests automatisés.

## Structure

```
examples/
├── pipelines/
│   ├── pipeline-migration.json    Template : audit de migration source -> destination
│   └── pipeline-veracrypt.json    Template : vérification de volumes VeraCrypt
└── workspace/
    ├── _data-source/              4 fichiers lorem-ipsum (état source)
    ├── _data-destination/         4 fichiers lorem-ipsum (état destination)
    │                              └── lorem-ipsum-01-modif.txt diffère intentionnellement
    ├── bases/                     Bases .b3 pré-calculées + sidecars .meta.json
    └── result/                    Résultats de compare de référence
```

## pipelines/

Templates à copier dans `pipelines/` et adapter à votre environnement.
Ne pas exécuter directement - les chemins sont des placeholders.

| Fichier | Cas d'usage |
|---|---|
| `pipeline-migration.json` | Audit complet : compute source + verify + compute destination + compare |
| `pipeline-veracrypt.json` | Vérification de deux volumes VeraCrypt montés sous WSL/Linux |

Voir `docs/guides/migration.md` et `docs/guides/veracrypt.md` pour le détail
de chaque cas d'usage.

## workspace/

Données de test utilisées par les tutoriels et la suite de tests automatisés.

**Scénario intégré** : `_data-source/` et `_data-destination/` contiennent les
mêmes 4 fichiers, à une exception près - `lorem-ipsum-01-modif.txt` diffère entre
les deux dossiers. Ce défaut intentionnel permet de valider que `compare` détecte
bien 1 fichier modifié, 0 disparu, 0 nouveau.

`bases/` contient les bases pré-calculées correspondant à cet état de référence.
`result/` contient les résultats de compare attendus.

> **Ne pas modifier le contenu de `workspace/`.**
> Les tests automatisés (`tests/run_tests.sh`) s'appuient sur l'état exact de ces
> fichiers. Toute modification invalide les assertions de la suite de tests.


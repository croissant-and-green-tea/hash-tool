# Tutoriels

Les tutoriels utilisent les données de test incluses dans le dépôt (`examples/workspace/`).
Aucune donnée personnelle requise — tout fonctionne depuis la racine du projet.

---

## Avant de commencer

```bash
# Vérifier que l'environnement est opérationnel
bash hash-tool check-env
```

La sortie doit afficher `[OK]` pour `b3sum`, `jq`, et `integrity.sh` (mode natif),
ou confirmer que l'image Docker est disponible (mode Docker).

---

## Quel tutoriel choisir ?

| Objectif | Tutoriel |
|---|---|
| Comprendre le cycle de base : calculer, vérifier, lire les résultats | [T1 — Premier audit](01-premier-audit.md) |
| Vérifier qu'une copie ou migration de données est parfaite | [T2 — Vérifier une migration](02-migration.md) |
| Automatiser et ne plus retaper les commandes à chaque fois | [T3 — Automatiser avec un pipeline](03-automatisation.md) |

Les tutoriels sont **indépendants** mais **progressifs** — T2 et T3 présupposent
la maîtrise du cycle de base introduit en T1.

---

## Ce que vous allez apprendre

**T1 — Premier audit** *(~15 min)*
Calculer une base d'empreintes, vérifier l'intégrité, simuler une corruption,
lire `recap.txt` et `failed.txt`. Commandes maîtrisées : `compute`, `stats`, `verify`.

**T2 — Vérifier une migration** *(~20 min)*
Calculer deux bases (source et destination), les comparer, interpréter les 5 fichiers
de résultats, décider si la migration est valide. Commandes maîtrisées : `compare`.

**T3 — Automatiser avec un pipeline** *(~25 min)*
Écrire un fichier `pipeline.json`, lancer le workflow complet en une commande,
planifier l'exécution en cron. Commandes maîtrisées : `runner`.
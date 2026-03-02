# diff

Détecte les fichiers ajoutés ou supprimés entre une base `.b3` et un dossier,
**sans recalculer les hashes**. Diagnostic rapide, non cryptographique.

---

## Syntaxe

```bash
bash hash-tool diff -base <fichier.b3> [-data <dossier>]
```

| Option | Obligatoire | Description |
|---|---|---|
| `-base <fichier.b3>` | Oui | Base de référence |
| `-data <dossier>` | Non | Dossier à comparer. Défaut : répertoire courant. |

---

## Comportement

Comparaison des **listes de chemins** uniquement — aucun `b3sum` n'est lancé :

- **Disparus** : fichiers présents dans la base, introuvables sur le disque
- **Nouveaux** : fichiers présents sur le disque, absents de la base

Les **modifications de contenu** ne sont pas détectées — utiliser `verify` pour cela.

---

## Différence avec `compare` et `verify`

| Commande | Détecte ajouts/suppressions | Détecte modifications | Recalcul des hashes |
|---|---|---|---|
| `diff` | ✓ | ✗ | Non — rapide |
| `verify` | ✓ (fichier disparu = FAILED) | ✓ | Oui — lent |
| `compare` | ✓ | ✓ | Non (compare deux bases déjà calculées) |

`diff` est utile pour un diagnostic rapide quand on suspecte des ajouts ou
suppressions de fichiers mais qu'on ne veut pas attendre un `verify` complet.

---

## Exemples

**Vérification rapide après suspicion de suppression :**

```bash
bash hash-tool diff \
  -base ./bases/hashes_archives.b3 \
  -data ./archives
```

Sortie si tout est intact :

```
=== DIFF : hashes_archives.b3 vs ./archives ===

  Fichiers disparus depuis la base : 0

  Nouveaux fichiers non indexés : 0
```

Sortie si des fichiers ont changé :

```
=== DIFF : hashes_archives.b3 vs ./archives ===

  Fichiers disparus depuis la base : 1
    - ./rapport-2025-01.pdf

  Nouveaux fichiers non indexés : 2
    + ./rapport-2026-01.pdf
    + ./rapport-2026-02.pdf
```

**Dans le répertoire courant :**

```bash
cd ./archives
bash hash-tool diff -base ../bases/hashes_archives.b3
```
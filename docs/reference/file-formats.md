# Formats de fichiers

---

## Format `.b3`

Fichier texte UTF-8, une ligne par fichier haché. Format compatible avec la
sortie native de `b3sum` — peut être relu directement par `b3sum --check`.

### Structure d'une ligne

```
<hash>  <chemin>
```

- `<hash>` : 64 caractères hexadécimaux (empreinte BLAKE3)
- deux espaces de séparation
- `<chemin>` : chemin du fichier, relatif au répertoire de travail au moment du `compute`

### Exemple réel

```
7c211433f02071597741e6f5f6520d2d0962f1d7aa42e7f88e8e3f98aeabeaf  ./lorem-ipsum-01-modif.txt
3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d  ./lorem-ipsum-02.txt
ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb  ./lorem-ipsum-03.txt
```

### Pas d'en-tête

Le fichier `.b3` ne contient pas d'en-tête, de version, ni de métadonnées.
Les métadonnées sont dans le sidecar `.meta.json` séparé.

---

## Chemins relatifs dans la base

Les chemins dans le `.b3` sont **relatifs au répertoire de travail au moment du `compute`**,
pas au dossier cible lui-même.

Exemple : si vous lancez `compute` depuis `/srv` avec `-data ./archives` :

```
./archives/document.pdf
./archives/sous-dossier/image.jpg
```

Si vous lancez depuis `/srv/archives` avec `-data .` :

```
./document.pdf
./sous-dossier/image.jpg
```

Les deux bases sont fonctionnellement équivalentes mais leurs chemins internes diffèrent.
`verify` doit être lancé depuis le **même répertoire de travail** que `compute`,
ou avec `-data` pointant vers le bon dossier. C'est la source d'erreur la plus fréquente.

Voir [Troubleshooting — Exécution](../troubleshooting/execution.md) pour les cas d'erreur.

---

## Format `.meta.json` (sidecar)

Fichier JSON accolé à chaque base : `<base>.b3.meta.json`.
Voir [Référence sidecar](sidecar.md) pour le schéma complet.

---

## `.gitignore`

Fichiers et dossiers exclus du dépôt git :

| Règle | Raison |
|---|---|
| `*.b3`, `*.b3.meta.json` | Données utilisateur — propres à chaque installation |
| `resultats/`, `integrity_resultats/` | Résultats d'exécution — non versionnés |
| `site/` | Documentation générée par MkDocs — reconstruite en CI |
| `*temp*` | Fichiers temporaires — exception : `!reports/template.html` |
| `hors_git/` | Dossier de travail personnel |

---

## `.dockerignore`

Fichiers exclus du contexte de build Docker :

| Règle | Raison |
|---|---|
| `examples/`, `*.b3` | Données utilisateur — inutiles dans l'image |
| `tests/` | Suite de tests — non requise en production |
| `docs/`, `*.md` (sauf README) | Documentation — non requise dans l'image |
| `resultats/` | Résultats — propres à l'hôte |
| `.git/` | Historique git — inutile dans l'image |

Le contexte envoyé au daemon Docker est minimal (~quelques Ko).
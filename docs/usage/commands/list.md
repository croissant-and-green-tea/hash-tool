# list

Inventaire des bases d'empreintes `.b3` disponibles dans un dossier.
Affiche le nombre de fichiers indexés, la taille et les métadonnées sidecar si présentes.

---

## Syntaxe

```bash
bash hash-tool list [-data <dossier>]
```

| Option | Obligatoire | Description |
|---|---|---|
| `-data <dossier>` | Non | Dossier à parcourir. Défaut : répertoire courant. |

Profondeur de recherche : 2 niveaux maximum.

---

## Affichage

Pour chaque base `.b3` trouvée :

```
=== Bases d'empreintes dans : ./bases ===

  hashes__data-source.b3              4 fichiers    4.0K [+meta]
     -> Snapshot initial (2026-02-28T14:30:00Z)
  hashes__data-destination.b3         4 fichiers    4.0K [+meta]
     -> Migration T2 (2026-02-28T15:00:00Z)
```

- `[+meta]` — sidecar `.meta.json` présent
- Commentaire et date affichés si sidecar disponible
- Résultats triés par nom

Si aucune base n'est trouvée :

```
  Aucune base .b3 trouvée dans : ./bases
```

---

## Utilité

Vérifier qu'une base existe et contient le bon nombre de fichiers avant de lancer
un `verify` ou `compare`, sans avoir à ouvrir le fichier manuellement.

---

## Exemples

**Lister les bases dans le répertoire courant :**

```bash
bash hash-tool list
```

**Lister les bases dans un dossier spécifique :**

```bash
bash hash-tool list -data ./examples/workspace/bases
```

**Sortie typique avec sidecar :**

```
=== Bases d'empreintes dans : ./examples/workspace/bases ===

  hashes__data-source.b3              4 fichiers    4.0K [+meta]
     -> Audit initial T1 (2026-02-28T14:30:00Z)
```

**Sortie sans sidecar :**

```
=== Bases d'empreintes dans : ./bases ===

  hashes_archives.b3                 1247 fichiers   82K
```
# hash-tool

Outil CLI de vérification d'intégrité de fichiers par hachage BLAKE3.

## Présentation

hash-tool permet de calculer, vérifier et comparer des empreintes cryptographiques (BLAKE3) sur des dossiers de fichiers. Il détecte les fichiers modifiés, disparus ou ajoutés entre deux états d'un même dossier.

Fonctionne en mode natif (b3sum + bash) ou via Docker.

## Cas d'usage typiques

- Audit d'intégrité avant archivage
- Vérification après migration ou copie de données
- Contrôle périodique de données archivées 
- Automatisation via pipeline JSON

## Utilisation

```bash
hash-tool compute  -data ./donnees -save ./bases -meta "Snapshot initial"
hash-tool verify   -base ./bases/hashes_donnees.b3 -data ./donnees
hash-tool compare  -old ancien.b3 -new nouveau.b3 -save ./rapports
hash-tool runner   -pipeline ./pipelines/pipeline.json
```

## Documentation complète

-> [Docs](https://alan45678.github.io/hash-tool/) 

## Licence

Voir [LICENSE](LICENSE).

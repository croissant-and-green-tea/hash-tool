# Politique de sécurité

## Versions supportées

| Version | Supportée |
|---------|-----------|
| 1.x     | ✅ Oui    |
| 0.x     | ❌ Non    |

## Signaler une vulnérabilité

**Ne pas ouvrir d'issue publique GitHub pour une vulnérabilité de sécurité.**

Envoyer un rapport par email à : security@hash-tool (à remplacer par l'adresse réelle)

Inclure dans le rapport :
- Description de la vulnérabilité
- Étapes de reproduction
- Impact potentiel
- Version concernée (sortie de `hash-tool version`)

## Délai de réponse

- Accusé de réception : sous 72 heures
- Évaluation et décision : sous 7 jours
- Correction et publication : selon criticité, entre 7 et 30 jours

## Périmètre

Ce projet est un outil d'intégrité de fichiers local. Les surfaces d'attaque
pertinentes incluent :

- Injection via les chemins de fichiers passés aux commandes bash
- Falsification de fichiers `.b3` ou `.meta.json`
- Contournement de la vérification d'intégrité
- Vulnérabilités dans l'image Docker (dépendances Alpine, b3sum, jq)

## Divulgation responsable

Une fois corrigée, la vulnérabilité est documentée dans le `CHANGELOG.md`
avec le niveau de criticité (bas / moyen / élevé / critique) sans révéler
les détails techniques permettant l'exploitation avant que les utilisateurs
aient pu mettre à jour.

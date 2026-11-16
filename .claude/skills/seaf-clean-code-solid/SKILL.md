---
name: seaf-clean-code-solid
description: "Assess or improve cohesion and maintainability in a scoped code change."
---
# Clean Code Solid

## Purpose and activation
Assess or improve cohesion and maintainability in a scoped code change.

## Required inputs
Diff ou modules ciblés, conventions et contrats publics.

## Procedure
Identifier duplication métier, responsabilités mêlées, dépendances cachées et erreurs masquées. Corriger seulement les problèmes utiles au périmètre. Préférer des noms et un contrôle de flux clairs aux abstractions spéculatives.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Code lisible ou remarques actionnables avec fichiers et conséquences.

## Validation checklist
Comportement préservé; aucune abstraction gratuite; tests comportementaux pertinents.

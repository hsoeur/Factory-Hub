---
name: seaf-database-design-migration
description: "Design persistence changes and migrations with data integrity and recovery planning."
---
# Database Design Migration

## Purpose and activation
Design persistence changes and migrations with data integrity and recovery planning.

## Required inputs
Schéma, volumes, accès, transactions et compatibilité.

## Procedure
Modéliser contraintes et relations; utiliser des requêtes paramétrées. Définir transactions et index selon les accès. Préférer une évolution compatible expand/contract; tester migration sur données représentatives et prévoir sauvegarde et récupération.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Modèle, migration, validation d’intégrité et plan de récupération.

## Validation checklist
Aucune perte de données non autorisée; contraintes testées; rollback ou limites documentés.

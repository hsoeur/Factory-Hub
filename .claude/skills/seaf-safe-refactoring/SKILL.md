---
name: seaf-safe-refactoring
description: "Restructure code while preserving its observable behavior and public contracts."
---
# Safe Refactoring

## Purpose and activation
Restructure code while preserving its observable behavior and public contracts.

## Required inputs
Périmètre, odeurs de code, contrats et tests existants.

## Procedure
Évaluer les risques; exécuter une baseline et ajouter des tests de caractérisation si nécessaire. Refactorer par petites étapes vérifiables; séparer changement de comportement et restructuration. Comparer résultats, API et effets.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Refactoring incrémental et preuves d’équivalence pertinentes.

## Validation checklist
Aucun changement fonctionnel caché; baseline connue; contrats conservés.

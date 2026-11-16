---
name: seaf-automated-testing
description: "Design and execute behavior-focused tests for changed or critical software paths."
---
# Automated Testing

## Purpose and activation
Design and execute behavior-focused tests for changed or critical software paths.

## Required inputs
Critères, risques, infrastructure et commandes existantes.

## Procedure
Choisir unitaires, intégration, contrats ou E2E selon les frontières. Couvrir limites et erreurs avec données déterministes. Éviter les mocks qui reproduisent l’implémentation. Exécuter les tests ciblés puis les régressions nécessaires; conserver commande, code de sortie et résumé.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Tests utiles, résultats exécutés et comportements non couverts.

## Validation checklist
Aucun succès supposé; échec expliqué; infrastructure absente signalée.

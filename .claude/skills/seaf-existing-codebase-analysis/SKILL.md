---
name: seaf-existing-codebase-analysis
description: "Trace relevant execution paths and assess change impact in an existing repository."
---
# Existing Codebase Analysis

## Purpose and activation
Trace relevant execution paths and assess change impact in an existing repository.

## Required inputs
Demande, dépôt, points d’entrée et symptômes éventuels.

## Procedure
Lire instructions et état Git; rechercher symboles et appels concernés. Suivre entrées, logique métier, persistance et effets externes. Repérer contrats, dépendances et tests existants avant de proposer les lieux de modification.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Carte des chemins concernés, fichiers cités, conventions et impact.

## Validation checklist
Différencier observation et hypothèse; tests pertinents localisés; périmètre limité.

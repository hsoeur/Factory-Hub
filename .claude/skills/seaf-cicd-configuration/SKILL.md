---
name: seaf-cicd-configuration
description: "Configure reproducible builds and repository-appropriate verification or deployment pipelines."
---
# Cicd Configuration

## Purpose and activation
Configure reproducible builds and repository-appropriate verification or deployment pipelines.

## Required inputs
Commandes locales, CI existante, plateformes et cible de livraison.

## Procedure
Rendre le build reproductible; figer les dépendances selon les conventions. Adapter la CI existante; permissions minimales, gestion sûre des secrets, intégrité des artefacts. Vérifier localement ce qui est possible et documenter déploiement et récupération.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Configuration CI/build et procédure d’exploitation vérifiable.

## Validation checklist
Local-first; Windows/Linux selon besoin; aucun cloud supposé ni déploiement production implicite.

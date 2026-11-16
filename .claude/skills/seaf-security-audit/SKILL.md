---
name: seaf-security-audit
description: "Review a scoped change for exploitable security risks and evidence-backed findings."
---
# Security Audit

## Purpose and activation
Review a scoped change for exploitable security risks and evidence-backed findings.

## Required inputs
Diff, frontières de confiance, données sensibles et dépendances.

## Procedure
Adapter le modèle de menace au risque. Examiner authentification, autorisation, validation, injection, secrets, exposition et dépendances. Vérifier les vulnérabilités alléguées avec une source ou reproduction. Prioriser par impact et plausibilité.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Constats avec preuve, sévérité et correction; limites de couverture.

## Validation checklist
Aucun secret révélé; pas de vulnérabilité inventée; critiques bloquées avant livraison.

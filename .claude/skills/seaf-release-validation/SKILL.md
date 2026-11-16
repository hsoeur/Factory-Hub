---
name: seaf-release-validation
description: "Consolidate acceptance and quality-gate evidence into an honest release readiness decision."
---
# Release Validation

## Purpose and activation
Consolidate acceptance and quality-gate evidence into an honest release readiness decision.

## Required inputs
Critères, diff, résultats de tests/build/revue/sécurité et risques.

## Procedure
Associer les critères aux preuves. Évaluer les sept gates; chaque preuve indique commande ou artefact et résultat. Renseigner execution_mode avec solo-agent ou multi-agent. En Solo-Agent, effectuer cette validation dans la session principale sans agent QA séparé. Déclarer review.independent_required selon l'exigence réelle et fournir independent_evidence lorsqu'une revue indépendante a eu lieu. Une auto-relecture ne remplit pas cette exigence; en Solo-Agent, une revue indépendante obligatoire reste NOT RUN et bloque. Ne pas réduire une exigence pour contourner ce blocage. Exécuter check-release sur le rapport. Bloquer toute validation obligatoire absente ou échouée. Distinguer risques non bloquants et défauts bloquants.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Rapport READY, READY WITH WARNINGS ou BLOCKED avec preuves et actions restantes.

## Validation checklist
NOT RUN jamais PASSED; NA justifié; READY interdit si preuve obligatoire absente.

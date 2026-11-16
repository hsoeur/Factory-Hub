---
name: seaf-root-cause-debugging
description: "Reproduce a software defect and fix its demonstrated root cause with regression evidence."
---
# Root Cause Debugging

## Purpose and activation
Reproduce a software defect and fix its demonstrated root cause with regression evidence.

## Required inputs
Symptômes, étapes, logs expurgés, environnement et code.

## Procedure
Reproduire et relever attendu/observé. Formuler puis tester des hypothèses falsifiables. Identifier la cause avec preuves; ajouter si possible un test qui échoue avant correction. Appliquer un correctif ciblé et exécuter le test puis les régressions pertinentes.

## Engineering constraints
Respecter le périmètre et les permissions de l'utilisateur; préserver le travail existant. Ne jamais inventer une observation ou un résultat. Lire seulement le contexte pertinent; demander une précision uniquement si elle change la correction ou la sécurité de l'action.

## Expected outputs
Cause démontrée, correctif, résultat avant/après et limites.

## Validation checklist
Symptôme distinct de la cause; test réellement exécuté; reproduction impossible explicitée.

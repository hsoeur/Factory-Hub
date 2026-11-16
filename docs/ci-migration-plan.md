# Migration CI/CD vers Gitea Actions

## Périmètre confirmé

- Mode : `multi-agent`, scénario `maintenance`, niveau 3.
- Gitea : `1.27.3` (lecture de `/api/v1/version`).
- Runner : Windows sur VM-DEVOPS, label `windows`.
- Production inchangée : `adminprod@192.168.1.104`, Docker, conteneur
  `factoryhub_container`, port HTTP `12000`, répertoire
  `C:\Deploy\containers\factoryhub_container`.
- Validation puis déploiement automatique sur push de `main`.
- Aucun push, changement de secret ni déploiement exécuté pendant cette migration.

## Contrats et responsabilités

1. L'orchestrateur analyse l'existant, confirme les paramètres et désactive les
   déclencheurs YAML Azure. Il préserve les changements applicatifs antérieurs.
2. Le spécialiste DevOps possède le workflow Gitea, les scripts et tests CI,
   l'ADR, la documentation de déploiement et le contexte Docker.
3. Une revue indépendante du diff est obligatoire avant validation du code.
4. L'orchestrateur intègre les corrections, relance les tests et consigne les
   preuves et limites dans le rapport de qualité.

## Acceptation

- Exécution native Windows, pas de job de PR sur le runner de production.
- Secrets hors du dépôt, authentification SSH par clé et contrôle strict d'hôte.
- Image liée au commit, intégrité du transfert vérifiée avant bascule.
- Précontrôles, exclusion concurrente côté cible, santé vérifiée et restauration
  de l'ancien conteneur en cas d'échec de la nouvelle version.
- Tests locaux des chemins de succès et d'échec, documentation d'activation.
- Conservation du correctif de chargement sans Google Fonts.

## Conditions opérationnelles avant activation

Contrôler les protections de `main`, l'isolation et les droits du runner, les
secrets et l'empreinte SSH, la sécurité du transport vers Gitea (le remote observé
est HTTP), ainsi que la désactivation effective d'Azure et l'absence de job Azure
en cours. Le build Docker réel et un déploiement de validation restent à exécuter
sur une cible autorisée : le moteur Docker local est indisponible.

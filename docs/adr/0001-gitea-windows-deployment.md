# ADR 0001 — Gitea Actions, runner Windows et transfert SSH

## Décision

Remplacer le déclenchement Azure par Gitea Actions (serveur constaté : 1.27.3).
Le runner VM-DEVOPS porte le label `windows:host`, le job utilise `runs-on: windows`.
Le job de confiance ne traite que `main` (push automatique ou lancement manuel).
Pas de workflow PR sur cet hôte privilégié, pas de registre ni de service d'artefacts.
Checkout est épinglé au commit amont de v4.2.2 avec URL explicite.

PowerShell 7 sur le runner et Windows PowerShell 5.1 sur la cible évitent de
supposer un shell Linux. OpenSSH transporte une archive Docker, son SHA256 et
l'identité de l'image ; les commandes PowerShell distantes sont encodées UTF-16LE
pour éviter les ambiguïtés entre shells Windows. La clé et les clés d'hôte
proviennent uniquement des secrets Gitea ; aucun apprentissage automatique d'hôte.

Une transaction distante détient un verrou fichier exclusif depuis les préchecks
jusqu'au rollback. L'ancien conteneur est conservé avec sa configuration et son
image ; le nouveau n'est accepté qu'à l'état `healthy`. Les dossiers de transfert
sont uniques. On conserve les sauvegardes et ne fait aucun `docker image prune`.

Le verrou sérialise l'exécution mais ne garantit pas l'ordre des builds terminés.
Le workflow fournit donc `github.run_number` via `DEPLOY_SEQUENCE`, validé comme
entier positif 64 bits. Sous verrou, `deploy-sequence.txt` rejette tout numéro
inférieur ou égal avant Docker. Après validation image et santé de l'ancien,
mais avant renommage/arrêt, la nouvelle séquence est écrite avec WriteThrough et
Flush(true) dans un temporaire puis publiée atomiquement. Elle reste acquise même
après un échec/rollback. Un watermark vide/invalide bloque sans remise à zéro.
L'absence du fichier est réservée à la première activation contrôlée.

## Conséquences et limites

Le runner `host` possède des privilèges Docker et SSH : dépôt privé/de confiance,
branche protégée, accès d'administration restreint et hôte dédié obligatoires.
Le Gitea observé en `http://vm-devops:3000` nécessite, **avant secrets et activation**,
HTTPS valide et vérifié de bout en bout (runner/API/checkout et UI), ou une
protection de transport équivalente explicitement approuvée et documentée.
Ne pas désactiver la validation TLS (`sslVerify=false`, etc.). L'hôte SSH épinglé
ne protège pas les secrets ni le code téléchargés depuis Gitea en HTTP.
Les protections d'environnement ne sont pas une barrière Gitea fiable ; la
séparation et les droits du runner doivent être effectifs hors YAML.
Azure doit être désactivé aussi dans son UI avant activation : son ancien script
ne respecte pas le verrou et ne doit jamais concurrencer Gitea.

Un réessai doit être un nouveau run/dispatch de séquence supérieure : un rerun
garde le même numéro et est rejeté dès que celui-ci est accepté. Revenir à une
ancienne version nécessite un revert et un nouveau run. Garder un seul workflow
et une numérotation stable ; recréer/renommer le workflow ou restaurer une cible
exige une réconciliation du watermark approuvée, triggers suspendus, jamais sa
suppression ou son abaissement aveugle.

Une courte interruption pendant la bascule est acceptée. Le verrou OS est libéré
à la mort du processus, mais une panne brutale de VM, un arrêt forcé du processus
ou un démon Docker bloqué nécessitent une récupération opérateur. Le délai santé
ne constitue pas un timeout des commandes Docker. Le rollback logiciel ne promet
pas la survie à ces pannes. Un premier déploiement échoué n'a pas de version à restaurer.

`Dockerfile` conserve `nginx:alpine` (hors périmètre) : le build n'est pas reproductible
bit à bit malgré la traçabilité commit + image ID + SHA256. Figer un digest validé
est une amélioration séparée ; aucune valeur de digest n'est inventée ici.
Le téléchargement initial de checkout et de l'image de base nécessite un accès
réseau GitHub / registre Docker (ou des miroirs administrés).

## Validation

Tests locaux sans dépendance Pester : syntaxe PowerShell et JS, absence de ressources
initiales distantes, contrat Docker/dist, machine à états de déploiement et verrou
réel avec Docker simulé. L'intégration Gitea/act_runner, SSH/SCP Windows et Docker
Linux doit être vérifiée sur une cible de recette avant autorisation de production.

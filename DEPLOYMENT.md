# Déploiement Gitea Actions vers VM-APP

Le workflow `.gitea/workflows/deploy.yml` construit puis transfère directement
l'image Docker depuis VM-DEVOPS vers VM-APP via OpenSSH, sans registre privé ni
artefact hébergé. Il se déclenche automatiquement sur push `main`, et manuellement
via `workflow_dispatch` sur `main` uniquement. Cible et port inchangés :

- image : `factoryhub_image:<SHA commit>` ;
- conteneur : `factoryhub_container` ;
- SSH : `adminprod@192.168.1.104`, port 22 ;
- dossier : `C:\Deploy\containers\factoryhub_container` ;
- port HTTP : `12000` vers le port `80` du conteneur Linux.

## Activation (à réaliser par un administrateur, après recette)

**Prérequis bloquant avant l'enregistrement du runner, l'ajout de secrets et
l'activation :** l'URL Gitea observée est actuellement `http://vm-devops:3000`.
Ce transport HTTP seul ne convient pas à un pipeline privilégié. Mettre en place
**HTTPS avec certificat valide et vérifié de bout en bout pour le runner, l'API,
le checkout et l'interface UI**, ou une protection de transport équivalente
explicitement approuvée par le responsable sécurité et documentée. Configurer
les URL Gitea/runner/remotes et les autorités de confiance Windows/Git/Node
correspondantes ; vérifier tous ces accès avant activation. Ne jamais utiliser
`sslVerify=false`, `GIT_SSL_NO_VERIFY`, une désactivation de vérification TLS
ou un contournement de certificat. L'épinglage de l'hôte **SSH cible ne protège
ni le code ni les secrets échangés avec Gitea en HTTP**.

1. **Couper Azure avant toute activation Gitea.** Les déclenchements YAML sont
   désactivés (`trigger: none`, `pr: none`) dans `azure-pipelines.yml`, conservé
   pour historique. Désactiver aussi les éventuels overrides, schedules et triggers
   UI Azure ; annuler/attendre les runs déjà en cours et interdire les lancements
   manuels de l'ancienne pipeline. Elle ne respecte pas le nouveau verrou.
2. Sur Gitea 1.27.3, activer Actions pour le dépôt. Enregistrer le runner Windows
   **VM-DEVOPS** avec le label **`windows:host`** ; le workflow utilise
   **`runs-on: windows`**. Le label n'est pas le nom de la machine. Ne pas y
   associer un runner Linux ou un conteneur Ubuntu. La version d'act_runner reste
   à vérifier en recette ; ne pas supposer `builtin:checkout` disponible.
3. Installer pour l'identité du service runner : **PowerShell 7** (`pwsh`), Git,
   Node.js compatible checkout v4 (Node 20), clients OpenSSH (`ssh`, `scp` avec
   option `-O`) et Docker CLI avec accès au démon **Linux** existant. Le compte
   doit pouvoir construire et sauvegarder les images. Le checkout épinglé est
   téléchargé depuis GitHub ; le build `--pull` exige l'accès au registre nginx.
4. Sur VM-APP : Windows OpenSSH Server, authentification **par clé**, Windows
   PowerShell **5.1** accessible via `powershell.exe`, Docker CLI/démon Linux
   fonctionnels pour `adminprod`. Préparer le dossier cible avec ACL limitées aux
   administrateurs et à l'identité de déploiement. Le compte SSH doit pouvoir y
   écrire et utiliser Docker sans interaction. Vérifier la politique d'exécution
   des scripts avec l'administrateur (ne pas désactiver globalement la sécurité).
5. Après validation du transport sécurisé ci-dessus, ajouter deux secrets de dépôt Gitea :
   - `DEPLOY_SSH_KEY` : clé privée OpenSSH dédiée, sans passphrase interactive ;
     installer la clé publique selon la configuration OpenSSH Windows du compte
     (`authorized_keys` ou `administrators_authorized_keys` avec ACL adaptées).
   - `DEPLOY_KNOWN_HOSTS` : ligne(s) `known_hosts` authentifiées pour
     `192.168.1.104` (port 22), vérifiées hors bande auprès de l'administrateur.
     Aucun `ssh-keyscan` non vérifié, aucune désactivation du contrôle d'hôte.
     Lors d'une rotation, vérifier la nouvelle empreinte avant de modifier ce secret.
6. Protéger `main` : revue obligatoire, pas de push direct non autorisé, contrôle
   des modifications de workflow/scripts. Runner dédié au seul dépôt de confiance,
   accès d'enregistrement et permissions Gitea minimaux ; **aucune exécution de PR,
   de fork ou de dépôt non fiable sur ce runner privilégié**, même dans un autre
   workflow. Un `if` YAML seul ne protège pas un runner contre du code hostile.
7. Valider en recette Gitea/runner, SSH/SCP, Docker, rollback et HTTP. Lancer le
   workflow manuel sur `main` seulement après autorisation de déploiement ; les
   push suivants déploient automatiquement. Les environnements Gitea ne sont pas
   utilisés comme barrière d'approbation.

Les valeurs cible sont explicites dans `scripts/ci/Publish-FactoryHub.ps1` et le
contrat conteneur/port dans `Deploy-Remote.ps1` : toute modification doit être
revue conjointement. Il n'y a plus de secret `SSH_PASSWORD`, ni de dépendance PuTTY.

## Transaction, intégrité et rollback

Le checkout est épinglé au commit de `actions/checkout` v4.2.2. Le script vérifie
que HEAD correspond au SHA Gitea, construit le tag commit puis exporte l'image.
Le Dockerfile actuel utilise encore `nginx:alpine` : pas de reproductibilité bit
à bit tant qu'un digest approuvé n'est pas figé (ADR `docs/adr/0001-…`).

La clé et `known_hosts` sont écrits dans un dossier temporaire Windows aux ACL
restreintes à l'identité runner **avant** l'écriture des secrets, puis supprimés
dans `finally`. Ils ne sont pas affichés ni injectés dans les commandes YAML.
Chaque transfert utilise un dossier cible unique `incoming-<UUID>` ; SSH exécute
des commandes PowerShell encodées, SCP utilise des chemins fixes sans espace.
Les connexions imposent `BatchMode`, un hôte strictement épinglé et un timeout de
connexion. Ne pas activer la trace PowerShell ou SSH verbeuse sur ce job.

La cible prend un verrou fichier OS exclusif `deploy.lock`, commun à tous les runs,
**jusqu'à la fin du rollback**. Un concurrent échoue sans arrêter de conteneur ;
un nouveau run manuel est possible après le run actif. Ne pas supprimer ce fichier
pour contourner le verrou : il peut rester présent sans être verrouillé.
Le workflow transmet aussi `github.run_number` par la variable d'environnement
`DEPLOY_SEQUENCE` au paramètre obligatoire `-Sequence` (entier 64 bits strictement
positif). Sous verrou, la cible compare ce numéro au watermark persistant
**`C:\Deploy\containers\factoryhub_container\deploy-sequence.txt`**. Une séquence
inférieure ou égale est rejetée **avant tout appel Docker, chargement ou mutation** :
un ancien build retardé ne peut donc pas remplacer une tentative plus récente.
Le fichier contient uniquement les chiffres d'un entier positif 64 bits ; vide,
invalide ou illisible, il bloque le déploiement sans réinitialisation automatique.
Son absence n'est autorisée qu'à la première activation contrôlée de cette cible.

Avant l'arrêt de l'ancien conteneur, vérification SHA256 de l'archive, démon Linux,
`docker load`, tag commit, image ID exact et présence du healthcheck. Si un ancien
conteneur existe, il doit déjà être `healthy`, sinon intervention opérateur.
Après ces préchecks et **avant tout renommage/arrêt**, le numéro accepté est écrit
dans un fichier temporaire avec écriture synchrone et `Flush(true)`, puis publié
par remplacement/renommage atomique sous le même verrou. Cette valeur reste
conservée même si le démarrage échoue ou si le rollback réussit/échoue.

**Tout réessai doit être un nouveau run/dispatch avec un numéro supérieur.** Ne pas
utiliser « rerun » : il conserve `run_number` et sera refusé une fois ce numéro
accepté. Un retour à une ancienne version applicative se fait par un **revert du
commit et un nouveau run**, pas par le relancement d'un ancien build. Conserver
un seul workflow de déploiement et sa numérotation stable. Renommer/recréer ce
workflow, changer de dépôt ou restaurer la cible impose une réconciliation du
watermark approuvée par un administrateur, triggers suspendus : ne jamais supprimer
ou abaisser ce fichier en aveugle pour débloquer un run ancien. Restaurer une VM
peut restaurer un watermark périmé ; vérifier l'historique Gitea et les tentatives
acceptées avant toute réactivation. Un watermark invalide exige cette même
intervention approuvée, pas une remise à zéro automatique.

L'ancien conteneur est renommé `factoryhub_container-previous-<UUID>` puis arrêté
(sa configuration et son image restent disponibles). Le nouveau démarre sur
`12000:80`. Succès seulement à l'état Docker **`healthy`**, attendu au maximum
90 secondes ; `unhealthy`, arrêt, absence de healthcheck, timeout ou échec de
`docker run` déclenchent la suppression du candidat et le redémarrage de l'ancien.
La santé du rollback est également contrôlée ; le job reste en échec même si le
rollback réussit. Un rollback échoué porte le message **`ROLLBACK FAILED`** et
exige une intervention immédiate. Au premier déploiement, aucun ancien service
n'est inventé : un candidat échoué est supprimé et le job échoue.

Aucune ancienne image fonctionnelle n'est supprimée. Les sauvegardes s'accumulent :
surveiller l'espace disque, nettoyer seulement après validation opérateur et en
conservant au moins la dernière sauvegarde connue saine. Les dossiers `incoming-*`
sont supprimés après exécution ; une coupure réseau peut laisser un dossier à
nettoyer manuellement après vérification d'absence de run actif.

### Récupération manuelle (après autorisation)

En cas de panne brutale de VM/processus ou de Docker bloqué, l'automatisme ne
garantit pas le rollback. La limite santé ne borne pas les commandes Docker
elles-mêmes. Suspendre d'abord les triggers/runner et vérifier qu'aucune transaction
n'est active ; ne jamais agir en concurrence avec `deploy.lock`.
Sur VM-APP, identifier la bonne sauvegarde dans `docker ps -a`, examiner ses logs
et `docker inspect`. Si le candidat occupe encore le nom/port, l'arrêter puis le
renommer pour diagnostic ; renommer la sauvegarde choisie en `factoryhub_container`,
la démarrer et attendre `healthy` avant de réactiver les déploiements. Conserver
son image et sa configuration ; ne pas lancer de prune. Vérifier aussi HTTP et
le premier affichage ci-dessous. Sans sauvegarde (première livraison), diagnostiquer
l'échec et relancer une version approuvée.

## Vérifications locales et recette

Depuis la racine, sans Docker ni réseau :

```powershell
pwsh -NoProfile -File tests/ci/Test-Repository.ps1
pwsh -NoProfile -File tests/ci/Test-Deploy.ps1
pwsh -NoProfile -File tests/ci/Test-Publish.ps1
# Compatibilité du script distant et des tests avec la cible :
powershell.exe -NoProfile -File tests/ci/Test-Repository.ps1
powershell.exe -NoProfile -File tests/ci/Test-Deploy.ps1
```

Les tests contrôlent la syntaxe PowerShell/JS (`node --check`), les ressources
initiales, le contrat Docker/dist et les transitions transactionnelles simulées
(dont rollback réussi/échoué, premier run, santé, intégrité, contention et libération
du verrou réel). Aucun Docker ni SSH n'est invoqué par ces tests.
Ils vérifient aussi l'ordre B(2) puis A(1) refusé sans toucher B, l'égalité refusée,
le nouveau run (3), le watermark vide/invalide et sa conservation après rollback.
Les tests transport (PowerShell 7) simulent les commandes natives et vérifient
les options SSH, ACL du dossier de secrets, encodage, isolation des transferts et
nettoyage sur succès/échec, validation et transmission de la séquence.
**Intégration non exécutée ici** : build Docker, service act_runner/Gitea, transport
SSH/SCP Windows, ACL effectives sous compte de service, santé nginx et rollback
réel. Tester ces points sur une cible de recette avant production, y compris
échec de démarrage, image unhealthy, deux déploiements concurrents et rotation SSH.

## Pare-feu

Le port entrant TCP `12000` doit être autorisé sur VM-APP :

```powershell
New-NetFirewallRule -DisplayName "FactoryHub HTTP 12000" -Direction Inbound -Protocol TCP -LocalPort 12000 -Action Allow
```

Après déploiement, FactoryHub est accessible à l’adresse `http://192.168.1.104:12000`.

## Vérifier le premier affichage

La page utilise les polices disponibles sur le poste, sans feuille Google Fonts
externe : un filtrage Internet ne doit pas bloquer son rendu initial. Les liens
vers les applications ne sont ouverts que sur action de l'utilisateur.

Après redéploiement, vérifier dans les outils réseau du navigateur, cache désactivé,
que le document et le logo sont chargés sans requête vers Google Fonts. Comparer
le premier affichage sur le même poste et le même réseau. Si le document HTML
lui-même tarde à arriver, examiner séparément l'accès à la VM et le serveur HTTP.

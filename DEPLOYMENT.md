# Déploiement Azure DevOps vers VM-APP

La pipeline s’exécute sur l’agent `VM-DEVOPS` du pool `Default`, puis copie et déploie FactoryHub à distance sur la VM Windows Server 2022 `192.168.1.104`.

## Configuration Azure DevOps

Créer deux variables dans la pipeline ou dans un groupe de variables :

- `vmAppUsername` : compte administrateur autorisé à se connecter à VM-APP ;
- `vmAppPassword` : mot de passe du compte, enregistré comme variable secrète.

## Préparation unique de VM-APP

1. Vérifier que Docker fonctionne en mode **conteneurs Linux**. Le Dockerfile utilise `nginx:alpine`, comme les autres interfaces du serveur qui reposent sur `/docker-entrypoint.sh`.
2. Configurer WinRM HTTPS sur VM-APP avec un certificat approuvé par VM-DEVOPS, contenant `192.168.1.104` dans ses noms alternatifs, puis autoriser le port `5986` depuis VM-DEVOPS.
3. Autoriser le partage de fichiers Windows entre VM-DEVOPS et VM-APP pour la copie distante.
4. Vérifier que le compte `vmAppUsername` peut utiliser Docker sur VM-APP.
5. Ouvrir le port HTTP de FactoryHub depuis une console PowerShell administrateur sur VM-APP :

   ```powershell
   New-NetFirewallRule -DisplayName "FactoryHub HTTP 12000" -Direction Inbound -Protocol TCP -LocalPort 12000 -Action Allow
   ```

## Fonctionnement

Chaque commit sur `main` déclenche la pipeline. Elle utilise `WindowsMachineFileCopy@2` pour copier les fichiers puis `PowerShellOnTargetMachines@3` pour exécuter le déploiement via WinRM HTTPS.

Elle construit l’image `factoryhub:<BuildId>` sur VM-APP, remplace le conteneur `factoryhub`, vérifie son état de santé et restaure automatiquement l’image précédente en cas d’échec.

Après déploiement, le portail est accessible à l’adresse `http://192.168.1.104:12000`.

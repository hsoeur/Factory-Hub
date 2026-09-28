# Déploiement Azure DevOps sur VM-APP

La pipeline `azure-pipelines.yml` s’exécute directement sur la VM Windows Server 2022 `192.168.1.104`. Elle construit une image Nginx contenant FactoryHub, démarre le conteneur `factoryhub` et publie le site sur le port `12000`.

## Préparation unique de VM-APP

1. Vérifier que Docker fonctionne en mode **conteneurs Linux**. Le Dockerfile utilise l’image `nginx:alpine`, comme les autres interfaces du serveur qui reposent sur `/docker-entrypoint.sh`.
2. Créer dans Azure DevOps un pool d’agents nommé `FactoryHub-Windows`.
3. Installer un agent Azure DevOps auto-hébergé de ce pool directement sur VM-APP.
4. Exécuter le service de l’agent avec un compte autorisé à utiliser Docker.
5. Ouvrir le port TCP entrant `12000` dans le pare-feu Windows, depuis une console administrateur :

   ```powershell
   New-NetFirewallRule -DisplayName "FactoryHub HTTP 12000" -Direction Inbound -Protocol TCP -LocalPort 12000 -Action Allow
   ```

6. Dans Azure DevOps, créer la pipeline à partir du fichier `azure-pipelines.yml` du dépôt.

## Fonctionnement

Chaque commit sur `main` déclenche un déploiement. La pipeline :

1. vérifie les fichiers du site et l’accès à Docker ;
2. construit l’image `factoryhub:<BuildId>` ;
3. remplace le conteneur `factoryhub` en conservant l’image précédente ;
4. attend que le contrôle de santé soit positif ;
5. restaure automatiquement l’image précédente si le nouveau conteneur échoue.

Après déploiement, FactoryHub est accessible à l’adresse `http://192.168.1.104:12000`.

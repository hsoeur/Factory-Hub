# Déploiement Azure DevOps

La pipeline `azure-pipelines.yml` déploie FactoryHub dans un conteneur Nginx sur la VM `192.168.1.104` et publie le site sur le port `12000`.

## Préparation unique dans Azure DevOps

1. Installer Docker sur la VM et autoriser le compte de déploiement à exécuter `docker`.
   Créer également le dossier distant et lui donner comme propriétaire ce compte :
   `sudo mkdir -p /opt/factoryhub/releases && sudo chown -R <utilisateur-ssh> /opt/factoryhub`.
2. Dans **Project settings → Service connections**, créer une connexion **SSH** nommée `factoryhub-vm-ssh` :
   - hôte : `192.168.1.104`
   - port SSH : `22`
   - authentification : clé SSH recommandée
3. Autoriser cette connexion pour la pipeline.
4. Utiliser un agent Azure DevOps du pool `Default` ayant accès au réseau `192.168.1.0/24`.
5. Créer la pipeline à partir du fichier `azure-pipelines.yml` du dépôt.

Chaque commit sur `main` déclenche le déploiement. La pipeline construit d’abord la nouvelle image, remplace le conteneur `factoryhub`, vérifie son état de santé et restaure l’image précédente si le démarrage échoue.

Une fois déployé, le portail est accessible à l’adresse `http://192.168.1.104:12000`.

# Déploiement Azure DevOps vers VM-APP

La pipeline utilise l’agent `VM-DEVOPS` du pool `Default`. Elle construit l’image Docker localement sur cet agent, la publie comme artefact Azure DevOps, puis la transfère sur VM-APP avec `pscp` et exécute les commandes Docker à distance avec `plink`.

## Variables

Les valeurs suivantes sont définies dans `azure-pipelines.yml` :

- image : `factoryhub_image` ;
- conteneur : `factoryhub_container` ;
- serveur : `192.168.1.104` ;
- utilisateur : `adminprod` ;
- dossier distant : `C:\Deploy\containers\factoryhub_container` ;
- port publié : `12000`.

Créer dans Azure DevOps une variable nommée `SSH_PASSWORD`, contenant le mot de passe SSH du compte `adminprod`, et la marquer comme secrète. Le mot de passe ne doit pas être inscrit dans le fichier YAML.

`plink.exe` et `pscp.exe` doivent être installés et accessibles dans le `PATH` du service de l’agent `VM-DEVOPS`.

## Pare-feu

Le port entrant TCP `12000` doit être autorisé sur VM-APP :

```powershell
New-NetFirewallRule -DisplayName "FactoryHub HTTP 12000" -Direction Inbound -Protocol TCP -LocalPort 12000 -Action Allow
```

Après déploiement, FactoryHub est accessible à l’adresse `http://192.168.1.104:12000`.

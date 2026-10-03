# Prospecto 1.3.14+44 — RC6 organisation & identité

## Accueil
- suppression de la répétition de l’identité du compte dans la carte centrale ;
- l’identité/espace reste visible une seule fois dans le sélecteur supérieur ;
- en Personnel, l’avatar du compte utilise la photo Firebase/Google ou les initiales ;
- en Entreprise, le sélecteur utilise le logo de l’entreprise ou ses initiales ;
- accueil Entreprise recentré sur Équipe & accès, Planning partagé et Performance terrain ;
- accès direct « Équipe & accès » pour OWNER/MANAGER.

## Paramètres
- l’administration Entreprise est sortie de la rubrique Préférences ;
- nouvelle section Entreprise : Direction/Pilotage, Membres & invitations, Identité & logo, Forfait ;
- ajout du changement de photo/icône du compte personnel depuis Paramètres ;
- l’entreprise conserve son écran Identité & logo existant.

## Membres
- la fenêtre « Inviter un membre » devient responsive ;
- menu de rôle en largeur adaptable ;
- aide e-mail sur deux lignes ;
- contenu scrollable pour petits écrans / Fold ;
- bouton « Identité » renommé « Identité & logo ».

## Backend
Aucun déploiement Firebase supplémentaire n’est nécessaire pour cette RC : les règles Storage actuelles autorisent déjà chaque utilisateur à écrire dans son propre dossier `users/{uid}/...` et l’upload de logo Entreprise existe déjà.

## Vérification
Après extraction à la racine de `C:\dev\prospecto` :

```powershell
.\verifier_prospecto.ps1
```

Puis seulement si le résultat est OK :

```powershell
flutter run
```

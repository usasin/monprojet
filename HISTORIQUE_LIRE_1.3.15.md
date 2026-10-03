# Prospecto 1.3.15+45 — Projet complet Entreprise

Cette archive contient les sources complètes Flutter (Android/iOS), les assets, les Cloud Functions, les règles Firebase, les tests et les scripts. Elle reprend les sources RC2 et les correctifs RC3 à RC7, puis intègre la refonte des rôles.

## Installer dans votre projet existant

1. Extrayez le ZIP dans un nouveau dossier, différent de `C:\dev\prospecto`.
2. Dans PowerShell, depuis le dossier extrait contenant ce fichier, lancez :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
.\deploy_entreprise.ps1
.\verifier_prospecto.ps1
flutter run
```

L’installateur sauvegarde les fichiers remplacés dans un dossier voisin et conserve les configurations Firebase, Google Maps, les profils locaux et les fichiers de signature existants. Il ne déploie rien automatiquement. Les scripts de déploiement déduisent le projet du fichier Firebase Android et refusent une incohérence avec `.firebaserc`.

Le déploiement Entreprise est nécessaire : les nouvelles fonctions d’invitation et les règles d’accès ne peuvent pas fonctionner avec l’ancien backend seul. Il faut mettre à jour les fonctions et les règles ensemble. Cette archive n’a pas été déployée sur votre Firebase et ne contient pas d’APK signé.

## Changements

- OWNER seul : invitation nominative obligatoire (prénom, nom, e-mail, rôle), révocation, rôles, rattachement à un responsable, identité et forfait.
- MANAGER : accueil du jour, commerciaux de son périmètre, planning, attribution des tournées/RDV, KPI semaine et détail des comptes rendus.
- REP : journée, création autonome de tournées, ajout de ses RDV, activité personnelle et tournées attribuées identifiées par leur auteur.
- Invitation : aperçu du destinataire avant connexion, e-mail Firebase vérifié, activation atomique et code consommé une seule fois. Les codes ne sont plus demandés aux membres déjà activés.
- Révocation : fin de l’accès, sortie de l’espace Entreprise, désactivation des invitations encore en attente de cette adresse, conservation des données historiques.
- Suppression de la règle récursive qui permettait aux membres de lire les données des collègues. Protection du champ de droit développeur contre les modifications depuis l’application.
- Accueils et paramètres organisés par rôle ; identité du compte visible ; préférence de notifications du compte.
- Fenêtres d’invitation et d’attribution défilantes ; contrôleurs de formulaire détenus par leurs widgets ; changement de rôle isolé dans le contrôleur d’onglets.

## Membres existants

L’OWNER ouvre **Équipe & accès**, puis le menu d’un commercial → **Rattacher à un responsable**. Les commerciaux sans responsable explicite restent suivis par l’OWNER. Aucun rattachement à un manager n’est inventé lors de la migration.

Les comptes déjà actifs conservent leur UID et leur accès ; ils n’ont pas besoin d’un nouveau code. Les anciens codes sans e-mail réservé doivent être remplacés par une invitation nominative. Les commerciaux existants peuvent créer leurs tournées même si leur ancien champ `routeAutonomy` vaut `false`.

Le répertoire de prospects Entreprise reste partagé comme dans le projet d’origine. Les tournées, RDV, rappels et comptes rendus sont isolés par commercial. Une tournée reste enregistrée par date selon le modèle existant ; une tournée attribuée garde ses étapes protégées.

## Vérifications

Voir `VERIFICATION_1.3.15.md` pour les résultats et les limites. Avant une publication, refaire le parcours sur le Fold réel avec trois comptes. La stack trace du crash `'_dependents.isEmpty'` n’a pas été fournie : les corrections de cycle de vie et les tests de fermeture des fenêtres ne prouvent pas, à eux seuls, la disparition du scénario exact sur l’appareil.

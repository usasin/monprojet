# Prospecto 1.3.16+46 — Accueils Entreprise simplifiés

Projet complet Flutter Android/iOS avec backend inclus.

## Installer
Extraire dans un nouveau dossier. Depuis ce dossier, dans PowerShell :
```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
flutter pub get
.\verifier_prospecto.ps1
flutter run
```
L’installateur sauvegarde les fichiers remplacés et préserve la configuration locale Firebase et les clés.

## Changements
- OWNER : Équipe & accès, Planning équipe, Activité du jour, Performance.
- MANAGER : Mes commerciaux, Planning équipe, Performance & reporting.
- Outils personnels regroupés dans Mon activité terrain pour OWNER et MANAGER ; tournées/RDV personnels ouverts sur le membre connecté.
- Paramètres accessibles depuis une icône en haut de l’accueil Entreprise.
- Suppression du deuxième bloc KPI sur l’accueil MANAGER. Statistiques du jour en grille compacte.
- Chaque accès de pilotage ouvre sa page sans les onglets répétitifs. Les anciens accès restent compatibles.
- OWNER : menu d’un responsable → Gérer son équipe → cocher ses commerciaux → Enregistrer. Cocher un commercial d’un autre responsable le transfère. Décocher un membre de cette équipe le remet sous le suivi de l’OWNER. Les changements sont appliqués individuellement via la fonction serveur existante ; une erreur indique une mise à jour partielle à vérifier.
- Liste Responsable limitée à ses commerciaux ; suppression du texte de présentation des droits.
- Prénom/nom prioritaires lorsqu’ils existent, e-mail sous le rôle dans la liste d’accès.
- Bouton Inviter placé dans le contenu pour ne plus masquer les invitations.
- Identité/logo retirés d’Équipe & accès et toujours accessibles dans Paramètres Entreprise.
- Tournées consultées pour un autre membre identifiées par son nom.

## Backend
Fonctions et règles identiques à 1.3.15+45. Si elles sont déjà déployées, aucun nouveau déploiement backend requis pour ce correctif. Le rattachement nécessite assignMemberManager, déjà déployée dans votre journal. Installer/recompiler l’application est nécessaire.

## Vérification de cette version
Syntaxe des 67 fichiers Dart vérifiée par Tree-sitter : aucune erreur de syntaxe. Sources backend et règles comparées à l’archive 1.3.15 : identiques. Intégrité ZIP vérifiée.
Flutter/Dart SDK absent de cet environnement : analyse Flutter, compilation et tests Flutter non exécutés pour 1.3.16. Les résultats de 1.3.15 restent des résultats historiques, pas une validation de ce correctif.
À vérifier sur Fold réel : accueil replié/déplié, navigation directe, activité personnelle, attribution/changement d’équipe puis connexion Responsable. Le crash antérieur _dependents.isEmpty reste à reproduire avec sa stack trace s’il revient.

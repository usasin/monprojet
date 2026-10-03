# Vérification Prospecto 1.5.0+50 — 3 octobre 2026

- Flutter 3.38.1 / Dart 3.10.0, dépendances résolues avec le verrou fourni.
- 72 tests Flutter réussis. Les nouveaux contrôles vérifient les calculs et la déduplication des prospects, les filtres d’équipe/période, les tournées complètes/partielles, les invitations expirées et RDV annulés, la lecture de 251 prospects et 251 opportunités, le refus des rôles non administrateurs et les requêtes devenues obsolètes.
- Seize cas d’affichage et d’interaction : largeurs 320/360/600/1100 px, texte normal ou agrandi à 1,8, thèmes clair et sombre. Les compteurs ouvrent les callbacks appropriés, aucun bouton de tournée personnelle dans cet accueil.
- Rendus Flutter de l’accueil inspectés avec Roboto et MaterialIcons réels. Données d’exemple isolées dans les tests ; aperçus inclus dans `apercus`.
- Analyse statique : aucune erreur et aucun avertissement dans les nouveaux fichiers Entreprise ; avertissements et informations historiques du projet présents.
- Compilation `flutter build bundle --debug --no-pub` réussie. Aucun APK signé ni build iOS produit.
- 19 fichiers backend, règles et configuration identiques à 1.4.2, qui conservait le backend 1.4.1. Tests Firebase non réexécutés pour cette mise à jour d’interface.
- Sources Solo Home/Reporting/Historique identiques à 1.4.2.
- Version et contrôle PowerShell mis à jour à 1.5.0+50. ZIP contrôlé : structure, présence des sources/natifs/backend et intégrité.
- Aucun test sur téléphone physique, aucune publication Play Store ou opération sur le projet distant réalisé ici.

Le retour Cloud Shell fourni confirme le backend 1.4.1 sur quiz-commercial. Installer une nouvelle compilation de l’application pour voir ce nouvel accueil.

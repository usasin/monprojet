# Vérification Prospecto 1.6.0+51 — 3 octobre 2026

- Flutter 3.38.1 / Dart 3.10.0 ; dépendances résolues avec pubspec.lock.
- 90 tests Flutter réussis : calculs et filtres, pagination au-delà de 200 prospects/affaires, périmètre Responsable, affichage conditionnel des montants et contrats, comparaison et navigation.
- Fiche contact et présentation des opportunités contrôlées aux largeurs 320/360/600 px, avec texte normal ou agrandi à 1,8. Barre du bas : cinq libellés sur une ligne et destinations cliquables. Les contrôles antérieurs de l’accueil couvrent aussi 1100 px et les thèmes clair/sombre.
- Rendus Flutter avec Roboto et MaterialIcons réels inspectés ; données de tests isolées, aperçus dans apercus.
- Analyse statique : aucune erreur ; avertissements et informations historiques du projet encore présents. Aucun nouvel avertissement dans les nouveaux fichiers sales.
- Compilation flutter build bundle --debug --no-pub réussie. Aucun APK signé ni build iOS produit.
- Backend TypeScript compilé. Neuf tests unitaires métier réussis et 21 tests Firebase Emulator réussis sur un projet demo local. Contrôles : accès propriétaire, configuration valide, refus des écritures directes, suppressions archivées, historique conservé, impossibilité de réactiver une opportunité supprimée, désactivation de l’invitation et de son lien, périmètre de lecture et pagination du Responsable. Aucun accès au projet de production pendant ces tests.
- Accueil Solo, Reporting et Historique conservés ; aucun retrait de leurs camemberts.
- Version, vérificateur et scripts mis à jour à 1.6.0+51. Archive vérifiée : intégrité CRC, structure, présence des sources Flutter/natives/backend/configurations et tests ; caches et dépendances non inclus.
- Pas de test sur téléphone physique, de publication Play Store ni de déploiement distant effectué ici. Déployer le backend 1.6.0 sur quiz-commercial puis installer une nouvelle compilation de l’application.

# Vérification Prospecto 1.4.2+49 — 3 octobre 2026

- Flutter 3.38.1 / Dart 3.10.0 : dépendances résolues avec le verrou fourni.
- 48 tests Flutter réussis, dont séparation Solo/Entreprise, comptage non chevauchant des visites, graphiques à 320/600/1100 px avec texte à 1,8, clics sur les légendes et absence de faux pourcentages sans données.
- Analyse statique : aucune erreur bloquante ; avertissements et informations historiques présents.
- Compilation Flutter build bundle --debug --no-pub réussie. Ce bundle n’est pas un APK signé ni un build iOS.
- Rendus des nouveaux graphiques inspectés avec une police Roboto réelle aux largeurs 320 et 600 px.
- Backend : 17 fichiers (configuration, règles, sources, scripts et sortie TypeScript) identiques à la version 1.4.1. Les tests Firebase déjà validés en 1.4.1 n’ont pas été réexécutés pour cette correction de présentation.
- Contrôle de version Windows mis à jour à 1.4.2+49.
- Pas de publication Play Store, de compilation iOS ou de test sur le téléphone réel effectué ici.

Le log Cloud Shell fourni confirme le backend 1.4.1 sur quiz-commercial. L’installation d’une nouvelle compilation 1.4.2+49 est nécessaire pour la correction visible.

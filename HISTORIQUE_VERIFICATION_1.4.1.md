# Vérifications Prospecto 1.4.1+48 — 3 octobre 2026

Exécuté sur les sources de cette archive :

- Flutter 3.38.1 / Dart 3.10.0, dépendances résolues et verrou actualisé pour ce SDK.
- Analyse Flutter : aucune erreur bloquante ; 596 avertissements/informations restent, principalement le code historique et des dépréciations. Commande avec `--no-fatal-warnings --no-fatal-infos` : ce résultat ne signifie pas zéro avertissement.
- Suite Flutter : **42 tests réussis**, dont les nouvelles vérifications des chemins de données et des brouillons Solo/Entreprise. Disposition des indicateurs et des tournées testée aux largeurs 320, 600 et 1100 avec texte agrandi à 1,8. Les actions Carte / Compte rendu / Modifier restent visibles dans les tournées dépliées.
- Modèle de vente Dart : **17 contrôles réussis** (périodes, montants, taux et stock).
- `flutter build bundle --debug --no-pub` : réussi. Le bundle Dart n’est ni un APK signé ni un build iOS.
- Backend TypeScript : compilation `npm run build` réussie.
- Validations commerciales serveur : **9 tests Node réussis**.
- Émulateur Firestore avec le projet local `demo-prospecto` : **14 tests réussis**. Isolation des rôles, vente Solo privée, refus d’accès entre comptes, refus d’écriture directe et d’historique modifié, révisions, correction justifiée, tentative identique sans doublon, attribution atomique d’équipe.
- Syntaxe Bash du déploiement et du script de test vérifiée.
- Archive : intégrité CRC et comparaison SHA-256 avec chaque fichier source inclus.

## Reproduire

```bash
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
dart test/sales_model_standalone.dart
flutter build bundle --debug
cd verification
bash tester_backend.sh
```

Le test backend refuse de fonctionner sans émulateur et projet `demo-`. Il nécessite Node et Java compatibles avec Firebase CLI. Aucune base de production n’a été utilisée dans les tests.

## Reste à réaliser

Déployer la fonction et les règles sur `quiz-commercial`, compiler Android/iOS avec les outils et clés habituels, puis tester sur le Fold réel (rotation, clavier, thèmes, changement d’espace et de compte, relances et signatures). La configuration du nom dans Google Auth et sa vérification par Google n’ont pas été effectuées. Aucun avis Google ne peut être supprimé depuis le code de l’application.

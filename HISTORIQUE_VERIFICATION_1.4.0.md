# Vérification Prospecto 1.4.0+47 — 2 octobre 2026

## Exécuté et réussi

- Flutter 3.38.1 / Dart 3.10.0 : résolution des dépendances, verrou compatible conservé dans pubspec.lock.
- Analyse Flutter : 0 erreur bloquante ; 589 avertissements/informations de style, imports inutilisés et dépréciations restent dans le projet. Commande : `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`. Ceci ne signifie pas une analyse sans avertissements.
- Suite Flutter complète : 37 tests réussis, incluant les tests existants de configuration, modèles et dialogues. Trois tests de disposition des indicateurs aux largeurs 320, 600 et 1100 avec texte agrandi à 1,8 ; interaction vérifiée.
- Compilation Dart de l’application : `flutter build bundle --debug --no-pub` réussie. Ce bundle n’est pas un APK installable ou un build iOS.
- Modèle commercial Dart : 17 contrôles, dont bornes temporelles, stock vs résultats, absence de taux sans clôture, montants en centimes, montant absent/zero distinct.
- Backend TypeScript : `npm run build` réussi.
- Validations serveur : 9 tests Node réussis (étapes, intérêt, signature, montant, perte, prochaine action, révisions, corrections).
- Émulateur Firestore local `demo-prospecto` : 11 tests d’intégration réussis. Identité issue de l’authentification, isolation responsable/commercial, refus d’écriture directe et d’accès révoqué, historique immuable, correction justifiée, conflit, nouvelle tentative idempotente, transfert atomique d’équipe et absence de mutation partielle.
- Syntaxe des scripts Bash de déploiement et de vérification validée.
- Archive complète vérifiée par lecture CRC et comparaison SHA-256 des fichiers avec les sources préparées.

## Reproduire

```bash
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build bundle --debug
 dart test/sales_model_standalone.dart
cd functions
npm ci
npm run build
node --test scripts/test-sales-logic.cjs
cd ../verification
bash tester_backend.sh
```

Le test d’intégration exige Java compatible avec Firebase CLI 14 (Java 17 utilisé ici ; Java 21 conseillé pour les outils futurs), Node et les dépendances verrouillées dans verification. Il refuse de fonctionner sans émulateur et projet `demo-`. Aucun test ne cible les données de production.

## Encore à valider dans votre environnement

- Déployer les deux nouvelles fonctions et les règles avec `deployer_cloud_shell.sh`.
- Compiler avec votre SDK Android et votre clé de publication ; construire iOS sur macOS si utilisé.
- Fold réel replié/déplié, rotation, clavier, grands caractères, thèmes et raccourcis contextuels.
- Connecter un administrateur, deux responsables et leurs commerciaux : recherche, attribution/transfert, accès après changement, création/closing et lecture des résultats.
- Créer une opportunité chaude avec relance, signer une offre avec/sans montant, perdre une affaire, corriger avec motif, vérifier les ratios.
- Couper le réseau, éditer puis quitter/revenir : le brouillon local est repris ; aucun contrat non publié n’apparaît dans les résultats. Reconnecter et publier ; tester une modification simultanée et le chargement explicite de la version enregistrée.
- Migration fonctionnelle : les anciennes notes et comptes rendus restent des rapports de visite et ne deviennent jamais des ventes automatiquement.

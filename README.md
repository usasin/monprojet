# Prospecto 1.3.12+42

Version projet Android `com.ainego.ai_prospect_gps`, candidate `1.3.12+42`, incluant les optimisations de performance précédentes sans retrait des fonctionnalités métier.

Cette version comprend le splash animé, le choix Personnel/Entreprise, la signature visuelle CIP, les espaces entreprise, les rôles, les invitations, les prospects partagés et le raccordement Stripe/Firebase pour les offres 3, 10 et 25 utilisateurs.

Depuis `1.3.12+42`, l'espace Entreprise dispose d'un accueil réellement adapté au rôle : Direction pour OWNER, Opérations pour MANAGER et Ma journée pour REP. Les tableaux de bord, priorités et raccourcis changent selon la mission du compte connecté au lieu de reproduire l'interface Solo.

## Démarrage local

```powershell
cd C:\dev\prospecto
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

## Backend entreprise et Stripe

Lancez le script interactif de configuration :

```powershell
.\configurer_stripe.ps1
```

## Build Google Play

La clé Maps est fournie par la variable `PROSPECTO_MAPS_ANDROID_KEY` ou le
fichier Gradle utilisateur. La clé de signature et `android/key.properties`
restent locaux et exclus de Git. `configure_production.ps1` garde la clé Maps
dans la session PowerShell sans l'écrire dans le dépôt.

```powershell
.\build_release.ps1
```

Le fichier AAB sera créé dans :

```text
build\app\outputs\bundle\release\app-release.aab
```


## Mode ADMIN TEST
Pour tester Premium sans achat, utiliser `build_admin_test.ps1`. Le build Play Store force `ADMIN_TEST_MODE=false`. Pour les modes entreprise complets, utiliser la custom claim `prospectoDeveloper` via `activer_mode_developpeur.sh`.

## Publicités iOS

Les identifiants Android ne sont jamais utilisés sur iOS. Les identifiants
publics créés dans AdMob pour Prospecto iOS sont intégrés :

- Application : `ca-app-pub-1360261396564293~5907234032`
- Bannière FREE : `ca-app-pub-1360261396564293/9926370092`
- Interstitiel : `ca-app-pub-1360261396564293/4594152361`

Ils peuvent être remplacés dans l'environnement par `ADMOB_IOS_APP_ID`,
`ADMOB_IOS_BANNER_ID` et `ADMOB_IOS_INTERSTITIAL_ID`.
Lancer `bash build_ios_release.sh` sur macOS avec Xcode et la signature
Apple configurée. Le script refuse les identifiants manquants, de test ou les
identifiants Android connus, et génère la configuration Xcode locale ignorée
par Git. Codemagic utilise ce même script.

En debug, les identifiants officiels de test iOS sont utilisés. En production,
les blocs iOS ci-dessus sont utilisés. Le consentement
UMP, la bannière FREE, l'interstitiel après sauvegarde avec délai de 30 minutes
et l'absence de publicités Premium/ADMIN TEST sont conservés. Aucune annonce
à l'ouverture n'est activée. Les déclarations SKAdNetwork sont incluses.

L'application a été créée dans AdMob comme non encore publiée. Après sa
publication Apple, associer sa fiche App Store (ID `6747984215`) dans AdMob
et terminer la vérification demandée avant une diffusion complète.

Références : https://developers.google.com/admob/ios/quick-start et
https://developers.google.com/admob/ios/test-ads.

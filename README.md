# Prospecto 1.3.11+41

Version Android publiée `com.ainego.ai_prospect_gps`, incluant les optimisations de performance 1.3.9 sans retrait des fonctionnalités métier.

Cette version comprend le splash animé, le choix Personnel/Entreprise, la signature visuelle CIP, les espaces entreprise, les rôles, les invitations, les prospects partagés et le raccordement Stripe/Firebase pour les offres 3, 10 et 25 utilisateurs.

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

Fournissez la clé Maps via `PROSPECTO_MAPS_ANDROID_KEY` dans l'environnement
de compilation ou dans votre fichier Gradle utilisateur non versionné.
Conservez `android/key.properties` et la clé de signature uniquement en local
ou dans les secrets de CI. Le script `configure_production.ps1` conserve la
clé Maps dans la session PowerShell, sans l'écrire dans le dépôt.
Les configurations Firebase déjà présentes dans le dépôt sont conservées.
Les fichiers `config/prod.json` et `config/admin_test.json` ne contiennent
que des indicateurs de compilation, aucun secret.

```powershell
.\build_release.ps1
```

Le fichier AAB sera créé dans :

```text
build\app\outputs\bundle\release\app-release.aab
```


## Mode ADMIN TEST
Pour tester Premium sans achat, utiliser `build_admin_test.ps1`. Le build Play Store force `ADMIN_TEST_MODE=false`. Pour les modes entreprise complets, utiliser la custom claim `prospectoDeveloper` via `activer_mode_developpeur.sh`.

# Version actuelle : Prospecto 1.6.0+51

Consulter **LIRE_EN_PREMIER_1.6.0.md** pour les fiches visuelles, les réglages métier, les suppressions administrateur, la comparaison et le nouvel accueil Responsable. Déployer le backend 1.6.0 puis compiler cette application. Les notes ci-dessous sont historiques.

# Mise à jour Entreprise 1.3.15+45

Commencez par **LIRE_EN_PREMIER_1.3.15.md**. Le ZIP contient le projet complet corrigé. Les anciennes notes RC conservées ci-dessous et dans le dossier décrivent les versions précédentes.

# Prospecto 1.3.14+44

Version projet Android `com.ainego.ai_prospect_gps`, candidate `1.3.14+44`, incluant les optimisations de performance précédentes sans retrait des fonctionnalités métier.

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

Suivez `CONFIGURATION_STRIPE.md`, puis lancez :

```powershell
.\configurer_stripe.ps1
```

## Build Google Play

```powershell
.\build_release.ps1
```

Le fichier AAB sera créé dans :

```text
build\app\outputs\bundle\release\app-release.aab
```


## Mode ADMIN TEST
Pour tester Premium sans achat, utiliser `build_admin_test.ps1`. Le build Play Store force `ADMIN_TEST_MODE=false`. Pour les modes entreprise complets, utiliser la custom claim `prospectoDeveloper` via `activer_mode_developpeur.sh`.
## Identité de compte explicite (1.3.13+43)

Prospecto affiche désormais clairement le compte Firebase actuellement connecté (nom, e-mail et méthode de connexion) dans les paramètres, l’accès Entreprise et la barre d’espace. En Entreprise, l’identité personnelle est séparée du rôle métier (OWNER / MANAGER / REP). Une action **Changer de compte** libère aussi la session Google locale afin d’éviter une reconnexion ambiguë au même compte.



## Garde-fou de publication 1.3.14+44
`build_release.ps1` exécute automatiquement `verifier_prospecto.ps1 -Production` avant de créer l'AAB. Le contrôle bloque la publication si le package, Firebase, AdMob, Maps, la signature, le mode ADMIN, `flutter analyze` ou `flutter test` ne sont pas conformes.

Le changement de compte purge maintenant les caches publicitaires liés à l'ancien UID et retire le token FCM du compte quitté avant la déconnexion. Les statistiques d'équipe et le planning chargent les requêtes indépendantes en parallèle par lots bornés.

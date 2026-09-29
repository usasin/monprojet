# Prospecto 1.3.8 (38) — Publicités mieux placées

## Objectif
Conserver la publicité comme avantage différenciant de l'abonnement Premium, sans interrompre le travail du commercial.

## Changements
- Suppression des publicités plein écran au lancement de l'application.
- Suppression des publicités plein écran lors du retour dans Prospecto (notamment après Google Maps).
- Suppression de l'interstitiel automatique à l'ouverture de l'accueil.
- Conservation du bandeau publicitaire pour les comptes FREE.
- Interstitiel autorisé uniquement à une pause naturelle : retour à l'accueil après la sauvegarde d'une nouvelle tournée gratuite.
- Cooldown interstitiel persistant de 30 minutes.
- Le bandeau FREE indique désormais clairement « Version gratuite · avec publicités » et renvoie vers Premium.
- Premium reste entièrement sans publicité.
- Cache court du statut Premium dans AdService pour éviter des lectures Firebase répétées à chaque tentative d'affichage.
- Mise à jour immédiate du cache publicitaire après synchronisation/activation Premium.

## Parcours visé
FREE : découverte → recherche → première tournée → publicité légère / rappel Premium → limite gratuite → paywall.

PREMIUM : aucune publicité et aucune interruption liée à AdMob.

## AdMob production confirmé
- ID application : `ca-app-pub-1360261396564293~6577474458`
- App Open : `ca-app-pub-1360261396564293/5583440067` (conservé dans la configuration mais non affiché dans le parcours 1.3.8)
- Bannière : `ca-app-pub-1360261396564293/1162631714`
- Interstitiel : `ca-app-pub-1360261396564293/5482834887`
- `config/prod.json` active explicitement les blocs de production uniquement sur le build release Play Store.
- `build_release.ps1` bloque maintenant le build si l'ID application AdMob n'est pas celui de Prospecto.

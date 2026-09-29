# Prospecto 1.3.10+40 — Mode ADMIN TEST

## Objectif
Permettre au propriétaire de tester Prospecto sans acheter l'abonnement, tout en empêchant qu'un build public donne les droits Premium gratuitement.

## Mode ADMIN TEST local
Le flag `ADMIN_TEST_MODE=true` :
- active Premium côté application ;
- supprime toutes les limites FREE ;
- désactive les publicités via la logique Premium existante ;
- affiche la Console développeur ;
- ajoute un ruban `ADMIN TEST` visible dans toute l'application.

Créer l'APK de test sous Windows :

```powershell
.\build_admin_test.ps1
```

ou directement :

```powershell
flutter build apk --release --dart-define-from-file=config/admin_test.json
```

## Sécurité du Play Store
`config/prod.json` contient explicitement `ADMIN_TEST_MODE=false` et `build_release.ps1` arrête le build si le mode admin est activé.

Le build Play Store reste :

```powershell
.\build_release.ps1
```

## Test complet des modes Entreprise
Le flag local ne contourne volontairement pas les Cloud Functions / règles Firebase. Pour créer de vraies entreprises de test, changer entre Essentiel, Équipe et Business et tester les rôles OWNER / MANAGER / REP sans Stripe, attribuer la custom claim sécurisée au compte de test :

```bash
bash activer_mode_developpeur.sh votre-adresse@email.fr
```

Puis se déconnecter/reconnecter dans Prospecto. Le retrait reste disponible avec `retirer_mode_developpeur.sh`.

Cette séparation empêche qu'un utilisateur modifie l'application pour s'accorder des droits entreprise côté serveur.

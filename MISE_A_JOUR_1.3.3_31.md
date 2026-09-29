# Prospecto 1.3.3+31 — anglais et recherche internationale

## Ce qui change

- Interface disponible en français et en anglais.
- Sélection automatique de l’anglais sur un téléphone configuré en anglais.
- Changement manuel de langue dans **Paramètres > Langue**.
- Conservation intégrale des animations, du style CIP, de Google Play Billing personnel et de Stripe Entreprise.
- Recherche d’adresses mondiale : le géocodage n’est plus limité à la France.
- Prise en charge des recherches saisies en anglais : `hairdresser`, `pharmacy`, `company`, `construction`, etc.
- Format d’adresse amélioré pour le Royaume-Uni, les États-Unis et les autres pays : ville, État/région, code postal et pays.
- Champ d’adresse clarifié : saisir l’adresse complète, la ville et le pays pour éviter les ambiguïtés.

## Vérifications intégrées

- Test de configuration pour une adresse au Royaume-Uni.
- Test de configuration pour une adresse aux États-Unis.
- Test de configuration pour une adresse en France sans verrou national.
- Contrôle des fichiers de traduction français et anglais.
- Contrôle de l’identité Android `com.ainego.ai_prospect_gps`.
- Contrôle du projet Firebase `quiz-commercial`.
- Contrôle du maintien des fonctions Stripe et des abonnements Google Play.

## Important sur les résultats OSM

Prospecto interroge OpenStreetMap autour des coordonnées obtenues. La recherche est internationale, mais le nombre et la qualité des établissements dépendent des informations réellement renseignées dans OpenStreetMap pour la zone concernée. Une entreprise absente ou sans nom dans OSM ne pourra pas être affichée.

## Commandes avant publication

```powershell
cd C:\dev\prospecto
.\verifier_prospecto.ps1
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

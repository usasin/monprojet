# Prospecto — recherche internationale, test Flutter (sans build Codemagic)

## Principe métier conservé
Adresse de prospection (ville, rue, pays) -> geocodage Nominatim -> rayon exact
(500 m, 1 km, 2 km, 5 km, 10 km) -> catégorie(s) -> établissements ->
sélection -> optimisation de tournée en un clic -> enregistrement/dispatch hebdomadaire.

L'interface existante de tournée et la répartition hebdomadaire ne sont pas modifiées.

## Sources
- **Tous pays :** OSM/Overpass. Filtres CHR/HORECA, GMS, parapharmacie,
  entreprises TPE/PME, grands comptes (catégories OSM sans preuve d'effectif),
  zones d'activités, logistique, restaurants, coiffure, B2B, etc.
- **France métropolitaine :** Annuaire officiel des entreprises, uniquement
  si Nominatim identifie le pays FR ; SIRET/NAF et filtre par activité.
  La recherche « grands comptes » peut classer les résultats par taille lorsque
  l'API retourne cette information. Le rayon public ne dépasse pas 10 km dans
  l'interface, même si l'API française accepte davantage.
- Les informations (nom, SIRET, téléphone, mail, site, horaires, réseaux)
  ne sont disponibles que si une source les a effectivement fournies.
- Le cache est actuellement **local au processus mobile**, non partagé sur
  Cloudflare ; aucun abonnement Google Places et aucune clé payante activés.

## Contrôles gratuits conseillés
Dans le dossier du ZIP après extraction :
```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
cd functions
npm ci
npm run build
```
Puis tester `flutter run` sur un **émulateur Android** pour ne pas remplacer
par erreur l'application commerciale installée sur un téléphone utilisateur.

## Matrice de démonstration
1. Marseille : « restaurant », rayon 1 km -> résultats OSM et/ou Annuaire FR.
2. Marseille : « CHR, GMS », rayon 2 km -> sélection multi-secteurs.
3. Marseille : « parapharmacie », rayon 2 km -> données selon les sources.
4. Zone industrielle (France) : « zone d’activités », rayon 5/10 km ->
   bureaux, artisans, établissements avec nom quand les données le permettent.
5. Londres, Espagne, Maroc, Émirats : « HORECA » ou « supermarket » ->
   OSM international, pas de filtrage NAF français.
6. Enregistrer plusieurs prospects -> « Optimiser la tournée » -> vérifier
   ordre et persistance -> dispatch hebdomadaire inchangé.
7. Répéter une recherche : cache ; couper réseau : message d'erreur et
   aucun spinner infini une fois les délais écoulés.
8. Console développeur : trois interrupteurs ; **pour les enregistrer**,
   déployer en amont les fonctions Firebase sécurisées
   `getProspectSearchConfig` et `setProspectSearchConfig`, après
   validation TypeScript et des règles d'accès. Si elles ne sont pas encore
   déployées, la recherche fonctionne avec ses réglages par défaut,
   mais les interrupteurs ne peuvent pas être enregistrés.

## Limites connues
- Les données cartographiques gratuites sont incomplètes ; la catégorie
  « parapharmacie » inclut certains commerces apparentés, pas une garantie
  de qualification exacte.
- À l'international, les distinctions TPE/PME/grand compte n'ont pas de
  taille certifiée dans OpenStreetMap.
- Une recherche dense de 10 km peut être plafonnée par Overpass et par
  les quotas de l'Annuaire : ce n'est pas encore une base exhaustive de
  milliers d'établissements.
- Flutter/Dart et fonctions TypeScript n'ont **pas** été exécutés dans
  l'environnement de préparation ; les tests ci-dessus sont obligatoires.
- Aucun changement dans `main`, aucun IPA, aucun déploiement Firebase,
  aucune publication Play Store effectués pendant la préparation.

## Codemagic et iOS
Le YAML de la branche reprend le workflow `prospecto-ios` sans étape de
restauration. Cette branche expérimentale **ne doit pas être lancée
directement dans Codemagic** sans retrouver et vérifier le dernier build
réussi avec sa branche, son commit, son signing et les checks gratuits.

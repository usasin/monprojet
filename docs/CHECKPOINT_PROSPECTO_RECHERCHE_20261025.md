# CHECKPOINT — ÉTAT ACTUEL DU PROJET : Prospecto recherche

- **App :** Prospecto Android/iOS.
- **Branche de préparation :** `prospecto-search-resilience-naf-admin-20261025` (isolée de `main`).
- **Commit de départ :** `ee74bd1eda16f7aedbef60c96b126f8eb50883b4` ; commit courant : tête de branche.
- **Version :** source de départ `1.6.0+51` ; dernier IPA iOS traité par Apple : `1.6.0 (53)`.
- **Dernier build :** build 53 accepté pour TestFlight ; état vert Codemagic / dernier Android non consultables dans cette intervention.
- **Workflow :** `prospecto-ios` ; le `codemagic.yaml` contrôlé ne contient aucune étape Restore/ZIP/TAR.
- **Source réellement compilée :** fichiers Flutter présents dans la branche choisie avant `flutter analyze`, pas de remplacement par Restore dans le YAML examiné ; branche Codemagic effective à confirmer avant build.
- **Fichiers modifiés :** `osm_search_service.dart`, `select_prospects_page.dart`, `developer_console_screen.dart`, `models/prospect.dart`, `functions/src/index.ts`.
- **Fichiers ajoutés :** `prospect_search_config_service.dart`, `french_registry_service.dart`, `prospect_search_engine.dart`, `test/prospect_search_sources_test.dart`.
- **Modification :** sources OSM et API officielle française combinées, NAF/APE, limitation d'attente, cache mémoire, enrichissement des fiches, trois interrupteurs sécurisés dans console développeur. Pas de fausse information ni de faux résultats de démo.
- **Checks déjà passés :** présence fichiers, dépendances HTTP/Cloud Functions existantes, raccordement UI/serveur, identité du workflow et absence de Restore, équilibre statique des délimiteurs et contrôle des exports. **Flutter/Dart et TypeScript non exécutés** (outils/build dépendances non disponibles ici).
- **Ce qui fonctionne :** sources GitHub historiques inchangées sur `main`, clients et tournées existants non écrasés.
- **Problème restant :** exécuter `flutter analyze`, `flutter test`, `npm run build` dans `functions`, tests réseau réellement ciblés (restaurant/coiffeur), vérifier les règles/quotas de l'API, déployer les deux nouvelles Cloud Functions seulement après validation, puis produire une version distribuable depuis le dernier build vert.
- **Prochaine action exacte :** vérifier le dernier build Codemagic et son commit/branche, puis lancer les contrôles gratuits et la validation fonctionnelle, sans lancer d'IPA prématurément.
- **Ne pas modifier :** Bundle ID, signing/certificat/provisioning, Firebase plist/projet, AdMob, abonnements, autorisations commerciales, tournées/dispatch ni workflow iOS.
- **État livraison :** code **sur branche isolée uniquement**, **non déployé**, aucun nouveau build Codemagic.

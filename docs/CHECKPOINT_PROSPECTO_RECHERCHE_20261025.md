# CHECKPOINT — ÉTAT ACTUEL DU PROJET (Prospecto recherche)

- **App :** Prospecto Android/iOS (internationale).
- **Branche :** `prospecto-search-resilience-naf-admin-20261025`, isolée de `main`.
- **Commit :** HEAD de branche ; base `ee74bd1eda16f7aedbef60c96b126f8eb50883b4`.
- **Version :** `1.6.0+51` dans `pubspec.yaml` de ce ZIP expérimental. Dernier IPA connu soumis Apple : `1.6.0 (53)`, NON reconstruit.
- **Dernier build CodeMagic :** 53 traité par TestFlight ; dernier vert exact à recouper avant toute compilation. Aucun nouveau build effectué.
- **Workflow :** `prospecto-ios` ; aucun script Restore dans `codemagic.yaml` de cette branche.
- **Source réellement compilé après Restore :** aucun Restore dans ce YAML ; fichiers Flutter de la branche sélectionnée juste avant `flutter analyze`. Vérifier la branche/commit choisis sur Codemagic.
- **Fichiers modifiés :** `lib/services/osm_search_service.dart`, `lib/pages/select_prospects_page.dart`, `lib/pages/developer_console_screen.dart`, `lib/models/prospect.dart`, `functions/src/index.ts`.
- **Fichiers ajoutés :** `lib/services/{french_registry_service,prospect_search_engine,prospect_search_config_service}.dart`, `test/prospect_search_sources_test.dart`, `docs/TEST_RECHERCHE_FLUTTER_INTERNATIONALE.md`.
- **Modification :** géocodage international d'adresse conservé, rayon 0,5/1/2/5/10 km, CHR/HORECA, GMS, parapharmacie, logistique, zones d'activités, TPE/PME et grands comptes. OSM mondial + Annuaire/NAF seulement pour adresse FR, multi-secteurs, cache et délais bornés, enrichissement contacts SIRET/NAF, trois interrupteurs développeur sécurisés. Optimisation en un clic et dispatch hebdomadaire intacts.
- **Checks passés :** 22 contrôles statiques de présence/raccordement/flux effectués via GitHub ; source et workflow vérifiés ; branche 27 commits au-dessus de `main` initial. **Flutter analyze/test, npm build et tests réseaux non exécutés ici.**
- **Ce qui fonctionne :** `main` et la version publiée inchangés. Le ZIP GitHub contient le projet Flutter et les tests.
- **Problème restant :** prouver compilabilité sur Flutter et TS, qualité des réponses API réelles et comportements des interrupteurs avec Cloud Functions déployées.
- **Prochaine action exacte :** télécharger le ZIP de branche ou du SHA ; sur PC lancer `flutter pub get`, `flutter analyze`, `flutter test`, `npm ci && npm run build` dans functions ; tester sur **émulateur** et vérifier restaurant, CHR, GMS, Londres/France, tournées et admin. Ensuite seulement envisager les 2 nouvelles Cloud Functions et 1 build contrôlé depuis dernier vert.
- **À ne pas modifier :** Bundle ID, certificat, provisioning, Firebase plist/projet, AdMob, abonnements, workflow, règles commerciales, dispatch, optimisation et version publiée.

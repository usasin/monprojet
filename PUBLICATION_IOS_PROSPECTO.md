# Publication iOS Prospecto — configuration permanente

## Références à conserver

- Dépôt : `usasin/monprojet`, branche principale `main`.
- Application Codemagic PROSPECTO : `682f0569d93d8cf42aa33629`.
- Workflow YAML : `prospecto-ios`. GitHub conserve le code ; Codemagic teste, signe et envoie l'IPA à Apple. Ne pas ajouter de workflow GitHub Actions pour publier.
- Bundle : `com.ainego.aiProspectGps` ; équipe Apple : `G6T4NT9XZ9` ; identifiant App Store : `6747984215`.
- Intégration Apple existante : `Codemagic-Prospecto`.
- Certificat partagé existant : `ios_distribution_all_apps_2026`, expiration 13 septembre 2027. Ne pas recréer de certificat.
- Profil Codemagic permanent : `prospecto_app_store_shared_2026` ; nom Apple : `Prospecto App Store shared cert 2026` ; expiration 13 septembre 2027.
- Les anciens certificats/profils expirés le 5 juillet 2026 ne doivent pas être utilisés pour Prospecto.
- Firebase : projet `quiz-commercial` ; le fichier `GoogleService-Info.plist` doit figurer dans les ressources Runner et dans l'IPA.
- Flutter 3.44.8 ; Xcode 26 ou ultérieur ; machine Mac mini M2.

## Avant une publication

1. Comparer la dernière livraison et le commit GitHub ; vérifier la version réelle avant tout lancement. Ne pas repartir d'une ancienne archive ou d'un ancien build.
2. Lancer `tools/verify_ios_source.py`. Vérifier le numéro de version, Firebase, le bundle, les permissions et les identifiants AdMob iOS de production.
3. Lancer un seul build sur le commit vérifié. Les scripts du workflow réutilisent la signature existante, déterminent un numéro de build non utilisé, exécutent l'analyse et tous les tests avant l'archive.
4. `tools/verify_ios_ipa.py` vérifie le contenu réel de l'IPA, le profil, le SDK et la signature avant l'envoi Apple.
5. En cas d'échec, lire l'étape et le message exacts, corriger et vérifier le correctif avant de relancer. Ne pas multiplier les builds identiques.
6. Le workflow envoie l'IPA à App Store Connect. `submit_to_testflight: false` évite la soumission automatique à la revue bêta externe ; la disponibilité interne reste à vérifier dans TestFlight après le traitement Apple. La soumission App Store est désactivée.
7. Tester ensuite sur iPhone les connexions, les modes Solo/Entreprise, les autorisations, les opportunités, les invitations, les publicités et les achats. Les tests automatisés ne constituent pas un test sur téléphone réel.

## Livraison 1.6.0+51 du 3 octobre 2026

La livraison complète Entreprise a remplacé la version GitHub 1.3.12+42. Le commit de compilation contrôlé est `678c6e2af3a26dad619d883489c48f43584f2e5b`, conservé sur `prospecto-ios-1.6.0-51`. Le profil permanent a ensuite été enregistré dans Codemagic et configuré sur `main`.

- Précontrôle natif réussi ; 93 tests Flutter réussis dans Codemagic ; compilation TypeScript et 9 tests unitaires backend réussis.
- Build Codemagic : `6ac14ce37394575b200ac837`. IPA produite et vérifiée (bundle, version, Firebase inclus, SDK `iphoneos26.5`, signature et profil exacts).
- Envoi App Store Connect réussi sans erreur le 3 octobre 2026 ; reçu Apple `bbfe41cf-1564-4ccc-9172-a689269f10d9`. La disponibilité TestFlight et les tests sur iPhone restent à confirmer.
- IPA : 61 351 354 octets ; SHA-256 `c55436b5bd9282a4946cae536a342109a903d1af1698e9c58f7a4b3264b64e36`. Conserver cette IPA pour réutiliser la compilation.
- Avertissement Apple non bloquant : à partir d'avril 2027, la cible minimale iOS devra passer de 14 à 15. Aucun nouveau build n'est nécessaire pour cet avertissement sur l'envoi accepté du 3 octobre 2026.
- Les fonctions `saveSalesOpportunity`, `updateEnterpriseDisplaySettings`, `deleteEnterpriseRecord`, `revokeOrgInvite`, ainsi que les règles et index Firestore de cette livraison doivent être déployés sur `quiz-commercial` si ce n'est pas déjà fait. Le script `deployer_cloud_shell.sh quiz-commercial` prépare le déploiement ; il nécessite une session Google autorisée. Le 3 octobre, ce déploiement n'est pas encore confirmé.

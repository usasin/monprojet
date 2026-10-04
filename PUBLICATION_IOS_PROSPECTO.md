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
- Déploiement Firebase confirmé par la capture Cloud Shell fournie le 3 octobre 2026 (horloge affichée : 23 h 38) : `saveSalesOpportunity`, `updateEnterpriseDisplaySettings`, `deleteEnterpriseRecord` et `revokeOrgInvite` ont été mises à jour avec succès en `europe-west1` sur `quiz-commercial`. Les règles Firestore ont été compilées et publiées ; les index ont été déployés sur la base `(default)`. Les deux étapes affichent `Deploy complete!`, puis le script confirme « Backend 1.6.0 déployé sur quiz-commercial ». Ne pas répéter ce déploiement pour cette livraison sans nouvelle modification ou erreur constatée.

## Préparation App Store du 3 octobre 2026

- Connexion App Store Connect vérifiée. La fiche a été enregistrée en version `1.6.0` avec le build `51` (`bbfe41cf-1564-4ccc-9172-a689269f10d9`) ; la description française reflète les fonctions Solo et Entreprise actuelles.
- État observé après enregistrement : `Prepare for Submission`. Aucune nouvelle soumission à App Review n'a été effectuée.
- Le dossier de refus du build `23` mentionne un crash sur Map, une erreur Load dans Plan, des captures iPad contenant un cadre d'iPhone, des questions sur le modèle économique et une demande d'explication sur App Tracking Transparency.
- Les trois captures iPad actuellement présentes contiennent encore des visuels marketing avec un cadre d'iPhone. Les remplacer par de véritables captures de la version actuelle sur iPad ; vérifier également les captures iPhone.
- Contrôle du code du build 51 : `PurchaseDelivery.deliver` transmet toutes les transactions à `verifyGooglePlayPurchase`. Il manque une validation Apple pour les transactions iOS ; ne pas présenter les abonnements iOS comme vérifiés ou fonctionnels avant correction et essais.
- Aucun appel explicite à App Tracking Transparency n'a été trouvé dans le code Dart ; le consentement publicitaire utilise Google UMP. Vérifier les déclarations de confidentialité et le comportement réel avant de répondre à Apple.
- Les essais réels iPhone/iPad (connexion, Map, chargement du planning, achats et restauration) ainsi que la vérification du compte de démonstration restent à confirmer. Conserver le certificat et le profil permanents existants ; relancer Codemagic uniquement si une correction du binaire est nécessaire.

## Corrections 1.6.0+52 préparées le 4 octobre 2026

- Validation séparée des achats Apple et Google Play ; transactions Apple signées vérifiées avec la bibliothèque officielle Apple 3.1.0 et la racine publique Apple Root CA G3, contrôles OCSP activés. Liaison de l'achat au compte Prospecto par un UUID opaque ; expiration, remboursement et notifications serveur traités côté Firebase. Aucun droit Premium accordé à partir d'un décodage JWS non vérifié.
- Demande App Tracking Transparency native avant l'initialisation publicitaire iOS ; demandes non personnalisées quand l'autorisation est refusée. Cible minimale iOS 15 pour StoreKit 2.
- Captures automatiques des vrais écrans Entreprise, Portefeuille et Fiche prospect sur simulateurs iPhone Pro Max et iPad 13 pouces, avec données de démonstration isolées. Les dimensions sont contrôlées ; aucune capture Android n'est transformée en capture iPad. Ces captures sont préparées, pas encore produites.
- Vérifications locales réussies : compilation TypeScript, 16 tests Apple + 9 tests commerciaux, précontrôle iOS, syntaxe Python et shell. Les tests Flutter, les captures natives et la compilation iOS de ces corrections restent à exécuter dans Codemagic. Ne pas déclarer le build 52 envoyé ou validé avant le résultat réel.
- Déployer uniquement le nouveau backend d'achats avec `bash deployer_achats_apple_cloud_shell.sh quiz-commercial` depuis une session Google autorisée, puis relever l'URL HTTPS réelle d'`appStoreNotifications` et la configurer pour les notifications Apple V2 Production et Sandbox. Ce nouveau déploiement n'est pas confirmé. Le déploiement Entreprise du build 51 reste acquis.
- La page Subscriptions observée le 3 octobre ne contenait aucun produit Apple. Créer et vérifier le groupe Premium, les produits `premium_monthly` et `premium_yearly`, leurs durées, métadonnées et prix convenus avant les essais Sandbox. Références tarifaires retrouvées : 3,99 €/mois et 29,99 €/an ; ne pas affirmer leur activation dans App Store Connect avant vérification.
- Garder le build 51 sur la fiche tant qu'un nouveau build contrôlé n'a pas été envoyé. Remplacer ensuite les anciennes captures iPhone/iPad, vérifier compte de démonstration, confidentialité et parcours Map/Planning, et soumettre explicitement à App Review.
- Reprise du 4 octobre : les sessions du navigateur précédent ne sont plus présentes. Reconnexion Codemagic nécessaire ; App Store Connect redirige vers une page de connexion vide avec `authResult=FAILED`. Ne pas répéter les builds ni recréer les certificats pour résoudre une déconnexion.

### Contrôle Codemagic du 4 octobre

- Reconnexion Codemagic confirmée ; quota gratuit affiché avant lancement : 20 minutes utilisées sur 500. La signature permanente a été réutilisée avec succès.
- Build `6ac1de447394575b200ae26e`, commit `e9149263d448602fec570741499c47d4b601c28c` : précontrôle natif, résolution Apple/signature, installation des dépendances et analyse Dart réussis. 96 tests Flutter réussis, un test échoué ; arrêt avant les captures et l'archive, après 3 min 38 s. Aucune IPA 52 envoyée.
- Le test en échec exigeait une chaîne de code exacte dans WorkspaceBadge. Il a été remplacé par un test du rendu réel de l'e-mail et du rôle avec un compte de démonstration, compatible avec l'injection utilisée pour les captures.
- Autre correction avant relance : sur iOS, l'écran Abonnements dirige les achats personnels vers StoreKit et propose uniquement l'accès à l'espace d'entreprise existant par code ; les prix, liens et boutons de paiement Stripe ne sont plus affichés sur iOS. Les offres Entreprise Android restent disponibles. Deux tests vérifient l'affichage iOS et les actions. Référence de la revue : https://developer.apple.com/app-store/review/guidelines/ , sections 3.1.3 et 3.1.3(c).
- App Store Connect affiche toujours une connexion vide ; Cloud Shell affiche « Site Unavailable / Unable to access this site » dans ce navigateur. Le déploiement du nouveau backend et la configuration Apple ne sont pas confirmés.

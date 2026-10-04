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
- Captures automatiques des vrais écrans Entreprise, Portefeuille, Fiche prospect et Accès Premium sur simulateurs iPhone Pro Max et iPad 13 pouces, avec données de démonstration isolées. Les dimensions sont contrôlées ; aucune capture Android n'est transformée en capture iPad. Ces captures sont préparées, pas encore produites.
- Vérifications locales réussies : compilation TypeScript, 16 tests Apple + 9 tests commerciaux, précontrôle iOS, syntaxe Python et shell. Les tests Flutter, les captures natives et la compilation iOS de ces corrections restent à exécuter dans Codemagic. Ne pas déclarer le build 52 envoyé ou validé avant le résultat réel.
- Déployer uniquement le nouveau backend d'achats avec `bash deployer_achats_apple_cloud_shell.sh quiz-commercial` depuis une session Google autorisée, puis relever l'URL HTTPS réelle d'`appStoreNotifications` et la configurer pour les notifications Apple V2 Production et Sandbox. Ce nouveau déploiement n'est pas confirmé. Le déploiement Entreprise du build 51 reste acquis.
- Groupe Apple Premium et deux produits créés le 4 octobre : voir l’état actuel ci-dessous. Leur création ne prouve pas le fonctionnement des achats sur appareil.
- Garder le build 51 sur la fiche tant qu'un nouveau build contrôlé n'a pas été envoyé. Remplacer ensuite les anciennes captures iPhone/iPad, vérifier compte de démonstration, confidentialité et parcours Map/Planning, et soumettre explicitement à App Review.
- Lors des reprises, les connexions Apple et Google peuvent expirer. Les reconnexions du 4 octobre sont confirmées. Une déconnexion ne nécessite aucun nouveau certificat ni build.

### Contrôle Codemagic du 4 octobre

- Reconnexion Codemagic confirmée ; quota gratuit affiché avant lancement : 20 minutes utilisées sur 500. La signature permanente a été réutilisée avec succès.
- Build `6ac1de447394575b200ae26e`, commit `e9149263d448602fec570741499c47d4b601c28c` : précontrôle natif, résolution Apple/signature, installation des dépendances et analyse Dart réussis. 96 tests Flutter réussis, un test échoué ; arrêt avant les captures et l'archive, après 3 min 38 s. Aucune IPA 52 envoyée.
- Le test en échec exigeait une chaîne de code exacte dans WorkspaceBadge. Il a été remplacé par un test du rendu réel de l'e-mail et du rôle avec un compte de démonstration, compatible avec l'injection utilisée pour les captures.
- Autre correction avant relance : sur iOS, l'écran Abonnements dirige les achats personnels vers StoreKit et propose uniquement l'accès à l'espace d'entreprise existant par code ; les prix, liens et boutons de paiement Stripe ne sont plus affichés sur iOS. Les offres Entreprise Android restent disponibles. Deux tests vérifient l'affichage iOS et les actions. Référence de la revue : https://developer.apple.com/app-store/review/guidelines/ , sections 3.1.3 et 3.1.3(c).
- La connexion Apple a ensuite été rétablie. Cloud Shell affiche toujours « Site Unavailable / Unable to access this site » dans ce navigateur ; ne pas présenter le serveur d’achats comme déployé.


## État de reprise — 4 octobre 2026, 10 h 08 UTC

### Builds contrôlés, sans répétition à l’identique

| Index | Build Codemagic | Commit | Résultat constaté |
| --- | --- | --- | --- |
| 4 | `6ac1e1007394575b200ae2d4` | `17db` | Arrêt rapide sur le chargement asynchrone des traductions dans les tests widgets. |
| 5 | `6ac1e2ac7394575b200ae315` | `7e7` | Arrêt rapide sur le nettoyage de la plateforme de test et un bouton hors écran. |
| 6 | `6ac1e5027394575b200ae36b` | `e10743906c439644aa7e6cbe1e66c81f0961236c` | Tests ordinaires réussis ; capture native arrêtée sur les traductions non chargées. Aucune IPA 52. |
| 7 | `6ac1ebc37394575b200ae497` | `290ffecf59c05da49af5cc9298349329937af8d9` | Échec après 32 min 4 s : quatrième capture cherchait EnterpriseWorkspace, masqué par la fiche prospect (`Bad state: No element`, ligne 84). Aucune IPA 52. |
| 8 | `6ac21ffd7394575b200aef18` | `9efa8efd699359b4889089e339f20952d168bead` | Annulé après 21 min 9 s, avant l’archive. Analyse et 101 tests réussis, dont les quatre navigations iPhone/iPad. Le contrôle visuel des artefacts du build 7 a révélé une première capture noire « Test starting… ». Attente du rendu natif et contrôle des pixels ajoutés avant relance. |

Le parcours de capture est partagé entre les tests widgets rapides et l’intégration native. Le navigateur racine est conservé par une clé ; aucune recherche d’un écran masqué après ouverture de la fiche. Le code de capture reste isolé de la version de production.

Quota observé pendant le build 8 : 86/500 minutes gratuites utilisées, avant décompte du build en cours ; solde courant 0 USD. Renouvellement le 1er novembre 2026. Le build 8 a été annulé. Ne pas considérer ses tests réussis comme une validation des pixels natifs.

### Configuration Apple enregistrée

- Groupe **Prospecto Premium**, identifiant `22438689`, français et anglais (États-Unis). Les deux abonnements sont au même niveau de service **1**.
- Mensuel : produit `premium_monthly`, Apple ID `6818945571`, durée un mois, prix de base France 3,99 €.
- Annuel : produit `premium_yearly`, Apple ID `6818946151`, durée un an payé en une fois, prix de base France 29,99 €. L’option d’engagement annuel payé mensuellement n’a pas été activée.
- Disponibilité dans 175 pays/régions actuels, prix locaux automatiques ; familles désactivées, achats multisièges non autorisés, achats App Store uniquement.
- Noms et descriptions FR/EN enregistrés. Notes de revue mensuelles enregistrées lors de la session précédente ; notes annuelles enregistrées pendant cette reprise. Captures de revue encore à ajouter ; produits et groupe non soumis.
- Fiche iOS 1.6.0 : build 51 conservé jusqu’à disponibilité vérifiée de la nouvelle IPA. État Prepare for Submission ; ancienne revue rejetée pour le build 23. Aucune nouvelle soumission.
- Confidentialité : 15 types de données complétés et publiés. URL Apple enregistrée : `https://github.com/usasin/monprojet/blob/main/docs/PRIVACY.md`. La politique à jour est publiée sur main par le commit de documentation `ee74bd1eda16f7aedbef60c96b126f8eb50883b4` ; l’ancienne page Drive n’a pas pu être remplacée, son accès en écriture étant refusé.
- Assistance `https://digitalsolutionsai.com/contact/`, marketing `https://digitalsolutionsai.com/applications/prospecto/`, copyright 2026 Digital Solutions AI ; description Solo/Entreprise et explications commerciales/ATT enregistrées.
- Streamlined Purchasing reste activé. Edit ne présente pas de dialogue dans le navigateur. Apple exige que le dernier binaire approuvé contienne les APIs StoreKit nécessaires avant désactivation (documentation officielle : `https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-streamlined-purchasing`). Aucun achat promu, code promotionnel ou offre de retour n’a été configuré pendant cette préparation ; ne pas activer ces parcours sans prendre en charge les achats commencés hors application et leur liaison au compte.

### Blocages à lever avant soumission

1. Lancer une compilation sur le correctif de rendu natif, puis attendre son résultat exact ; vérifier dimensions et contenu des quatre captures natives par famille, puis remplacer les anciens visuels iPhone/iPad. Utiliser l’écran natif Accès Premium pour les captures de revue des abonnements.
2. Vérifier l’envoi Apple et le traitement du nouveau build ; sélectionner ce build dans la fiche 1.6.0.
3. Firebase a été relu après reconnexion : 33 fonctions, pages 1 et 2 contrôlées. `getApplePurchaseAccount`, `verifyApplePurchase` et `appStoreNotifications` restent absentes. Le serveur des achats Apple n’est pas déployé. Cloud Shell embarqué est inaccessible dans ce navigateur. Une commande clone/pin du commit `9efa8efd699359b4889089e339f20952d168bead`, puis `deployer_achats_apple_cloud_shell.sh quiz-commercial`, a été fournie pour le Cloud Shell du téléphone. Ne pas répéter les quatre fonctions Entreprise déjà déployées.
4. Relever l’URL réelle d’appStoreNotifications après déploiement, et configurer les notifications Apple V2 Production et Sandbox.
5. Valider compte de revue, connexion, Map/Planning, achat Sandbox et restauration sur iPhone. Aucun essai réel sur appareil n’est confirmé.
6. Ajouter les deux abonnements, leur groupe et la version à la même soumission de revue Apple, puis soumettre quand les points bloquants sont résolus. Aucun achat ou abonnement ne doit être présenté comme fonctionnel sur la seule base des tests unitaires.


### Contrôle visuel natif et contrat payant

- Artefacts du build 7 téléchargés et inspectés : trois PNG iPhone, 1320 × 2868. Le portefeuille et la fiche prospect affichent l’interface actuelle ; la vue Entreprise affiche encore la surface de démarrage du test. Ces fichiers ne doivent pas être téléversés ensemble dans Apple.
- Le contrôle natif ajouté attend une seconde après le dessin, contrôle les pixels clairs de la fixture, et retente au maximum trois fois. Même nom de fichier conservé ; seules quatre images finales sont attendues. Vérification sur les artefacts réels : première image rejetée (0,5 % de pixels clairs), deux suivantes acceptées (98,1 %). Aucun fichier de démarrage ne doit être publié.
- Business Apple vérifié : Free Apps Agreement Active (27 août 2026–27 août 2027), conformité DSA Active, **Paid Apps Agreement New**. Apple demande la mise à jour de l’entité légale avant signature. Le contrat payant n’a pas été signé. L’utilisateur doit valider lui-même ses informations et la signature avant commercialisation des abonnements.

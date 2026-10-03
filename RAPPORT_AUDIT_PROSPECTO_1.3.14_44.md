# Audit de stabilisation — Prospecto 1.3.14+44

## Base contrôlée
- Source : Prospecto 1.3.13+43.
- Package Android : `com.ainego.ai_prospect_gps`.
- Firebase : `quiz-commercial`.
- Cible Android : SDK 36.

## Corrections appliquées pendant l'audit
1. Isolation du cache Premium/AdMob par UID pour éviter qu'un statut du compte précédent survive à un changement de compte.
2. Retrait du token FCM du compte quitté avant déconnexion pour éviter des notifications destinées à l'ancienne session.
3. Centralisation du nettoyage de session Google/Firebase, espace de travail et caches.
4. Chargement Performance équipe par lots parallèles bornés ; planning tournées/RDV en parallèle.
5. Traductions FR/EN manquantes complétées.
6. Ajout d'un `.gitignore` racine protégeant keystore, `key.properties`, comptes de service et fichiers locaux.
7. Suppression du fichier Maps historique contenant une clé en clair ; la clé Maps passe par Gradle/variable d'environnement.
8. Ajout d'un garde-fou de build : `verifier_prospecto.ps1` contrôle version, package, Firebase, SDK, AdMob, Maps, signature et modes prod/admin puis exécute `flutter analyze` et `flutter test`.
9. `build_release.ps1` appelle automatiquement le vérificateur avant de créer l'AAB.

## Contrôles statiques réalisés ici
- Tous les imports Dart relatifs pointent vers un fichier existant.
- JSON FR/EN, prod/admin et `.firebaserc` valides.
- Package, projet Firebase et version cohérents.
- Aucun appel App Open Ad restant dans le code métier.
- Interstitiel appelé uniquement à la pause naturelle après une tournée gratuite.
- Règles Firestore Entreprise : suppression d'un prospect partagé réservée OWNER/MANAGER.
- Archive source assainie : aucun keystore, `key.properties`, secret Stripe, webhook Stripe ou clé privée.

## Point nécessitant le PC Flutter
L'environnement d'audit ne contient pas le SDK Flutter. La compilation réelle, l'analyse Flutter et les tests Flutter ne peuvent donc pas être exécutés ici. Ils sont désormais obligatoires et automatisés par `build_release.ps1` sur le PC de publication.

## Point runtime à revalider
Un ancien journal de test montrait des erreurs de layout `RenderBox was not laid out` puis `setState() or markNeedsBuild() called during build`. Le journal ne contient pas le début de la stack trace permettant d'identifier le widget. La checklist terrain inclut donc un test Android 16 plié/déplié avant production.

## Éléments non modifiés volontairement
- Pas de mise à niveau massive des dépendances : trop risquée juste avant publication.
- Pas de remplacement immédiat des API OSM publiques : caches, timeouts et fallback restent actifs ; une API avec SLA peut être étudiée après mesure réelle.
- Quotas FREE toujours pilotés côté client pour l'UX ; un durcissement serveur complet est recommandé à moyen terme contre les clients modifiés.
- Le build ADMIN conserve le même package Android que la production ; un vrai APK staging côte à côte nécessiterait une application Firebase Android dédiée et ses empreintes/signatures.

## Décision de publication
La source est prête comme release candidate. Publication uniquement après :
1. `build_release.ps1` terminé sans erreur ;
2. une passe de la checklist terrain ;
3. validation AdMob côté console si l'application y apparaît encore comme non validée / examen requis.

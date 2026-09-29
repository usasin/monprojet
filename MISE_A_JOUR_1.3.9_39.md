# Prospecto 1.3.9 (39) — Performance & fiabilité, sans retrait fonctionnel

## Objectif
Réduire les ralentissements signalés sur Android sans modifier le parcours métier, les quotas FREE/Premium, les données prospect, les tournées, le reporting ou les fonctions entreprise.

## Recherche prospects / OpenStreetMap
- Connexion HTTP réutilisée entre les recherches pour éviter de recréer une connexion réseau à chaque appel.
- Cache géocodage partagé (TTL 1 h, borné à 80 entrées).
- Cache recherches proches partagé (TTL 5 min, borné à 40 entrées).
- Déduplication des requêtes identiques en cours : deux clics ou écrans ne lancent plus deux appels identiques.
- Repli court sur un résultat récent en cas de panne temporaire d'un miroir OSM.
- Mise en quarantaine temporaire d'un endpoint Overpass après timeout, HTTP 429 ou erreur 5xx ; les recherches suivantes commencent par un miroir sain.
- Timeout Overpass réduit et timeout serveur explicite pour éviter plusieurs dizaines de secondes d'attente sur un miroir bloqué.
- Clauses Overpass dédupliquées sans retirer de catégorie ni de filtre existant.
- Calcul de distance mémorisé pendant le tri des résultats.
- Rayon strict 500 m / 1 km / 2 km, recherche internationale et catégories existantes inchangés.

## Écran de recherche
- Protection renforcée contre les réponses réseau obsolètes.
- Une ancienne recherche ne peut plus écraser la nouvelle ni arrêter son indicateur de chargement.
- Conservation des prospects déjà sélectionnés lors d'une nouvelle recherche.
- Recherche des prospects sélectionnés manquants optimisée avec un Set au lieu d'un scan O(n²).
- Le fond animé est figé uniquement pendant les chargements lourds, puis reprend automatiquement ; le design reste identique hors chargement.

## Firebase / droits Premium
- UsageMeter devient un singleton de session : tous les écrans partagent le même état au lieu de recréer un compteur indépendant.
- Synchronisation Firestore dédupliquée et cache court de 45 secondes pour éviter les lectures identiques en rafale.
- Les achats/restaurations forcent toujours une vraie synchronisation serveur immédiatement après validation.
- Les règles FREE (1 tournée / 3 prospects) et Premium restent inchangées.

## Firestore
- Lecture de grandes listes de prospects par vagues de 3 requêtes `whereIn` maximum en parallèle.
- Ordre d'origine conservé avec une table d'index O(n) au lieu de `indexOf` répété.
- Sauvegarde d'une tournée : appartenance aux IDs sélectionnés via Set, sans changer les documents écrits.

## Publicité
La stratégie 1.3.8 est conservée : bannière FREE, interstitiel uniquement à une pause naturelle, aucun plein écran au lancement/retour de Google Maps, Premium sans publicité.

## Non modifié volontairement
- Authentification et comptes invités/connectés.
- Données Firestore et structure des collections.
- Plans et reporting.
- Mode entreprise OWNER / MANAGER / REP.
- Tournée intelligente et ordre des visites.
- Paiement et produits Play Store.
- Identifiants AdMob de production.
- Traductions FR/EN.

## Validation
Un test de régression source `test/performance_regression_config_test.dart` a été ajouté pour vérifier la présence des protections de performance. Un build Flutter réel reste à exécuter dans l'environnement de build habituel avant publication.

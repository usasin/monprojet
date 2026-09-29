# Prospecto 1.3.12 (42) — Expérience métier par rôle

Cette version transforme l’espace Entreprise pour que OWNER, MANAGER et REP n’atterrissent plus sur une interface générique identique.

## Accueil Entreprise nouvelle génération

- Accueil entièrement différent du mode Solo.
- Identification immédiate de l’entreprise et du rôle connecté.
- OWNER : cockpit Direction centré sur l’équipe, les accès, le planning et la performance.
- MANAGER : cockpit Opérations centré sur le terrain, les tournées, les commerciaux et l’exécution.
- REP : cockpit Ma journée centré sur ses visites, son planning, le reporting et les relances.
- Priorité contextuelle calculée à partir de l’activité réelle du jour, sans prétendre à une IA fictive.
- Indicateurs du jour : commerciaux actifs, visites prévues, visites reportées, rendez-vous et résultats utiles selon le rôle.
- Chargement des indicateurs par groupes de commerciaux afin d’éviter un pic de requêtes réseau sur les grosses équipes.

## Navigation et clarté

- Le gros accueil Solo n’est plus réutilisé en Entreprise.
- Le badge d’espace affiche maintenant le nom de l’entreprise ET le rôle, même en mode compact.
- Le cockpit équipe accepte une ouverture directe sur l’onglet demandé depuis l’accueil.
- Onglets modernisés : Direction/Aujourd’hui, Planning, Équipe & accès/Commerciaux, Performance.
- Les fonctions secondaires restent accessibles sans mélanger les missions des rôles.

## Sécurité des données partagées

- Un REP peut continuer à créer et mettre à jour les prospects partagés nécessaires à son travail.
- La suppression d’un prospect partagé est désormais réservée à OWNER et MANAGER côté règles Firestore.
- Le bouton Supprimer est masqué pour les commerciaux dans le reporting Entreprise.
- Le mode Solo conserve le comportement existant sur ses propres prospects.

## Internationalisation

- Ajout des traductions FR/EN des nouveaux écrans et actions métier.
- Ajout de traductions dynamiques pour les salutations et les indicateurs de reporting du jour.

## Tests de régression ajoutés

- Présence des trois expériences OWNER / MANAGER / REP.
- Navigation directe vers les onglets du cockpit.
- Protection de suppression des prospects partagés.
- Vérification des traductions critiques du nouvel accueil.

## Version

- `1.3.12+42`

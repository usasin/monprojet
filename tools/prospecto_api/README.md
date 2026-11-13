# Prospecto — API de votre annuaire B2B, sans énergie

Cette API lit **vos propres packs SQLite publics vérifiés**. Elle n'appelle ni
l'API Recherche d'entreprises, ni Overpass, ni une API d'énergie pour répondre.
Le code et le déploiement sont portables. Les données restent issues de sources
publiques à actualiser, et l'hébergement doit rester disponible.

**État au 6 novembre 2026 : non déployé.** L'extrait de validation contient
**50 établissements réels de Paris**, sans garantie de couverture complète.
Il ne constitue pas un annuaire national. Le disque D: a échoué à la vérification
des octets après écriture ; ses bases et archives n'entrent pas dans ce paquet.
Reporter l'énergie ne répare pas ce support : les 4,69 Go d'archives prévues
concernent déjà uniquement le socle SIRENE et son géocodage.

## Essai local indépendant

Python 3.11 ou plus récent, sans dépendance pour la préparation et les tests :

```powershell
python -m unittest discover -s tests -v
python -m prospecto_api prepare --catalog sample_paris/catalog.json --data data
python -m prospecto_api serve-local --data data --port 59851
```

Ouvrir `http://127.0.0.1:59851/health`, puis
`http://127.0.0.1:59851/v1/search?lat=48.86&lon=2.33&radius_m=2000&activities=restaurant&page_size=100`.
Cet essai retourne 19 restaurants dans l'extrait réel, avec les distances.
Le serveur d'aperçu reste limité à cet ordinateur ; il n'est pas un hébergement.

## Contrat HTTP

Seuls GET et HEAD sont acceptés. Aucune route d'écriture ou d'administration
publique. Les réponses contiennent les champs publics de l'établissement,
SIRET, SIREN, NAF et version, adresse, coordonnées, tranche d'effectif, taille,
provenance et distance. Pas de coordonnées commerciales inventées.

| Route | Contenu |
|---|---|
| `/health`, `/v1/status` | Version, date, départements réellement disponibles et nombre d'établissements |
| `/v1/territories` | Référentiel 101 départements/18 régions, disponibilité explicite |
| `/v1/activities` | Activités, synonymes et NAF complémentaires pris en charge |
| `/v1/search` | Résultats, pagination, couverture et notice |
| `/v1/catalog` | Catalogue compatible Flutter et liens directs des packs |
| `/v1/packs/{id}/{sha256}.sqlite.gz` | Archive publique vérifiée, HEAD, cache et requête Range simple |

Recherche : `department=75` (plusieurs séparés par virgule, 10 maximum),
`region=11`, `activities=restaurant,grossiste boissons`, `naf=56.10A`,
`q=nom ou adresse ou SIRET ou SIREN`, `lat`, `lon`, `radius_m` (100–50000),
`page` et `page_size` (1–100). Les activités se combinent par OU ; lieu,
territoire, texte et filtre NAF se combinent par ET. Les alias coiffure/garage/
boulangerie sont limités à NAF Rev.2. Un code NAF explicite recherche le code
fourni ; consultez la version NAF retournée. Maximum 12 activités.

Limite interactive 2000 résultats, budget SQL 4 s ; affiner au-delà. Le client
mobile charge au plus 500 résultats et signale cette limite. Une couverture
partielle ou un département indisponible ne signifie jamais absence d'entreprise.
Erreur d'entrée 400, méthode 405, débit 429, publication indisponible 503.
La limite interne est par adresse vue par le processus : derrière le proxy,
elle s'applique donc aussi globalement. Nginx ajoute une limite par IP publique.
Cette première version n'inclut ni SLA ni garantie de capacité nationale mesurée.

## Mise à jour des packs

L'importateur indépendant existant produit `catalog.json` et les `.sqlite.gz`.
Transférer **la publication publique finale**, jamais `import-work.sqlite` ou
une base de données de l'application. Puis :

```sh
python -m prospecto_api prepare --catalog /srv/prospecto/incoming/catalog.json --data /srv/prospecto/data
```

La préparation vérifie les empreintes, tailles, intégrité SQLite, relations,
comptages, départements et schéma. Les tables privées, bases de travail, données
fictives et observations énergétiques sont refusées. Les sources restent intactes.
Une publication est immuable ; utiliser une nouvelle version à chaque mise à jour.
Le pointeur `current.json` change uniquement après validation totale. Recharger
ensuite l'API pour qu'elle lise cette nouvelle version ; elle ne recharge pas à
chaque requête. Garder l'ancienne version pendant la transition et les téléchargements.
Les packs régionaux sont téléchargeables, la recherche lit les départementaux
une seule fois pour éviter de compter une entreprise deux fois.

Pour revenir à une publication connue : remplacer atomiquement `current.json`
par une copie de l'ancien pointeur puis redémarrer le service ; conserver les
empreintes et sauvegardes des publications sur un stockage fiable distinct.
Aucune suppression automatique de vos archives n'est effectuée.

## Déploiement sur votre serveur permanent

Le conteneur et le modèle Nginx sont fournis pour un serveur Linux. Docker et
Nginx ne sont pas installés sur le poste actuel : leur lancement en hébergement
et le test TLS public restent à effectuer une fois le serveur choisi. La suite
Python teste l'API via HTTP réel et l'interface de déchargement Nginx, pas Nginx lui-même.

1. Copier ce code et la publication vérifiée sur le serveur. Préparer les données
   avec Python 3.11+ ; l'utilisateur 10001 et Nginx doivent pouvoir les lire.
2. Dans `deploy`, définir `PROSPECTO_HOST_DATA=/srv/prospecto/data`, puis
   `docker compose up -d --build`. Le port est lié à **127.0.0.1** ; ne pas le
   rendre public. Données montées en lecture seule, utilisateur non administrateur.
3. Adapter `nginx.conf.example` : domaine réel, certificats TLS existants,
   chemin réel des données. Installer ce fichier dans la configuration Nginx,
   vérifier avec `nginx -t`, puis recharger Nginx. Ouvrir 443 sur le serveur.
   Le préfixe interne décharge les gros fichiers sur Nginx ; ne pas le rendre
   accessible directement ni exposer les fichiers SQLite.
4. Vérifier depuis une connexion extérieure `/health`, le catalogue, une
   recherche, puis l'empreinte de l'archive téléchargée. Tester l'installation
   sur téléphone et couper le PC personnel pendant ce test.
5. Construire Flutter avec `--dart-define=PROSPECTO_DIRECTORY_API_URL=https://votre-domaine`.
   Cette URL HTTPS doit être réelle ; aucun localhost ou domaine de démonstration
   ne doit être livré comme serveur de production. L'application récupère alors
   le catalogue automatiquement et télécharge directement les départements.

Après une nouvelle préparation : `docker compose restart api`. Les workers
vérifient les empreintes de la publication au démarrage ; cette durée dépend du
volume national et devra être mesurée. Prévoir le stockage de la base, des
archives, d'une publication précédente et du travail d'import ; ne pas confondre
le plafond de travail de 80 Go avec le volume que chaque téléphone télécharge.
La capacité et le coût seront dimensionnés sur les données réellement publiées.

Tant que l'URL n'est pas configurée, la version actuelle de l'application garde
sa recherche publique en ligne existante ; elle ne possède pas encore votre
service national hébergé. Une fois votre API configurée, aucune panne de cette
API n'entraîne un appel caché à un annuaire tiers. Le géocodage d'une adresse et
le fond de carte utilisent encore les services déjà présents dans l'application.

## Sources et choix techniques

L'extrait reprend les licences et provenance de son catalogue :
[SIRENE / INSEE](https://www.insee.fr/fr/information/3591226),
[Licence Ouverte 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/).
Il n'autorise pas à publier des données privées issues du CRM.

[Gunicorn recommande un proxy de déploiement](https://gunicorn.org/deploy/).
[Nginx décrit X-Accel-Redirect](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ignore_headers).
Le conteneur utilise l'[image Python officielle](https://hub.docker.com/_/python).
Les versions de dépendances sont fixées dans `requirements.txt` ; le tag de
l'image doit être remplacé par son digest approuvé lors du déploiement réel.

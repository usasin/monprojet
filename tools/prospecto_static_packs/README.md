# Prospecto : packs téléchargeables, sans serveur API

Le téléphone récupère `current.json`, puis le catalogue de version, puis le pack
choisi. Les recherches locales utilisent SQLite sur le téléphone. Votre PC
personnel peut être éteint une fois les fichiers diffusés en ligne.

La distribution proposée utilise les fichiers de versions GitHub : aucun compte
Oracle ni VPS ne sera créé. Il s'agit d'un service tiers de distribution de
fichiers, avec ses conditions et sa disponibilité ; aucun service API Prospecto
ne doit rester démarré pour répondre aux téléchargements.
[Documentation GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

## Préparer une livraison mensuelle

Après l'import des fichiers publics par l'importateur existant :

```powershell
python static_packs.py --catalog chemin/vers/catalog.json --output livraison-nouvelle-version --repository proprietaire/depot
```

Le catalogue et ses gzip doivent être dans le même dossier. Le programme ne
télécharge ni ne publie rien. Il reprend le validateur hors ligne situé dans le
dossier voisin `prospecto_api` (`prospecto-api` dans la copie de travail).
L'API correspondante n'est jamais lancée.

Les archives, bases SQLite, relations, territoires, comptages, licences et
empreintes sont contrôlés avant de produire les fichiers. Les données fictives,
bases de travail, schémas privés et observations énergétiques sont refusés.
Chaque pack respecte les limites mobiles de 512 Mio compressés et 2 Gio installés.
La vérification s'effectue territoire par territoire avec une réserve de 4 Gio.
Les sources restent inchangées ; un dossier de livraison existant est conservé.

Le dossier préparé contient :

- `repo/` : catalogue courant, catalogues de version et attribution des sources ;
- `assets/` : uniquement les archives publiques à ajouter à la version GitHub ;
- `publication.json` : compte exact, tailles, empreintes et état `published: false`.

Publier les archives de version avant de mettre à jour le catalogue courant.
Conserver les anciennes versions pendant les téléchargements déjà commencés.
Les dépôts et fichiers publiés seront publics : l'accord de publication doit
porter sur la livraison précise, sans inclure le code privé de l'app ou du CRM.

## Application

Configurer une fois le lien HTTPS du catalogue lors de la construction :

```text
--dart-define=PROSPECTO_DIRECTORY_CATALOG_URL=https://raw.githubusercontent.com/proprietaire/depot/main/current.json
```

Ce lien doit avoir été publié et vérifié avant de distribuer un APK. Aucun lien
fictif ou dépôt inexistant ne doit être présenté comme un téléchargement actif.
Les URL des archives de version peuvent utiliser les redirections HTTPS signées
de GitHub. Le mobile refuse les retours en HTTP, identifiants dans l'URL, boucles,
chaînes trop longues, tailles incorrectes et empreintes non conformes. Une mise
à jour incorrecte n'active pas le pack et conserve la version locale précédente.

## État actuel

La livraison de validation contient **50 établissements publics réels à Paris**.
Sa couverture est partielle ; elle ne représente ni Paris entier ni la France
entière. Aucun fichier n'a encore été publié. L'import national reste arrêté
suite aux différences d'octets écrits puis relus sur D:. Le disque C: a environ
18 Gio libres au 7 novembre 2026 ; le traitement national plafonné à 80 Go n'y a
pas été déplacé. L'énergie reste écartée.

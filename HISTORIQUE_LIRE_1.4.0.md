# Prospecto 1.4.0+47 — Navigation par métier et suivi des ventes

Projet complet Android/iOS et backend Firebase. Nouvelle compilation de l’application ET déploiement du backend nécessaires. Aucun accès à votre Cloud Shell ni déploiement de production effectué ici.

## Navigation

| Rôle | 4 espaces principaux | Périmètre |
|---|---|---|
| Administrateur | Entreprise · Équipes · Planning · Résultats | Toute l’entreprise |
| Responsable | Mon équipe · Commerciaux · Planning · Résultats | Ses commerciaux rattachés |
| Commercial | Aujourd’hui · Prospects · Tournées · Résultats | Ses visites et opportunités |

« Mon activité terrain » retiré des accueils Administrateur et Responsable. Paramètres par l’engrenage. Navigation latérale sur les grands écrans, barre inférieure sur téléphone. Les écrans de pilotage intégrés n’ajoutent pas une deuxième série d’onglets.

Équipes : recherche nom/e-mail, filtres par rôle, groupes par responsable, 50 membres rendus par page. Menu d’un responsable → Gérer son équipe. Sélection recherchable avec liste construite à la demande, 100 commerciaux maximum par opération ; changements atomiques. Cocher un membre d’un autre responsable le transfère. Un membre décoché passe dans Sans responsable et reste visible à l’administrateur. Le forfait et la propriété restent administratifs.

Prospects : véritable portefeuille partagé de l’entreprise avec suivi personnel ; recherche nom/adresse/activité, filtres Chauds / À relancer / Signés. À relancer sélectionne les opportunités avec une action Relancer datée ; les indicateurs Actions en retard couvrent tous les types d’action. Tournées : calendrier, ajout d’une tournée, carte et rapport dans le contexte de la tournée. Une fiche prospect permet de préparer une visite sans confondre recherche de prospects et portefeuille.

## Ventes et résultats

Le résultat d’une visite (présent, absent, RDV…) reste séparé du cycle de vente. Une fiche peut contenir plusieurs opportunités indépendantes : À qualifier, Qualifiée, Proposition envoyée, Négociation, Contrat signé, Perdue. Intérêt Froid / Tiède / Chaud, prochaine action Appeler / Visiter / Envoyer une proposition / Relancer et date/heure.

Pour signer : offre et date de signature obligatoires, référence du contrat facultative, montant HT en euros facultatif. Pour perdre : motif obligatoire. La note « valider contrat » dans un ancien rapport ne devient pas une vente. Les anciennes données ne sont pas converties en signatures fictives. La signature est une déclaration de résultat commercial : cette version n’intègre pas de signature électronique ni de vérification documentaire.

Résultats Aujourd’hui / semaine / mois : contrats gagnés et perdus dans la période, taux gagné/(gagné+perdu), montant HT signé déclaré, nombre de contrats sans montant. Aucun taux si aucune affaire clôturée. Affaires ouvertes, chaudes, en retard ou stagnantes sont un stock actuel, explicitement distinct des résultats de la période. Synthèses par commercial et, pour l’administrateur, par responsable selon les rattachements ACTUELS ; un transfert emporte le périmètre des anciennes ventes sans réécrire leur auteur.

Priorités explicables : échéances dépassées, affaires chaudes sans prochaine action, opportunités sans modification depuis 14 jours. Préparer mes visites prioritaires propose d’abord les échéances dépassées, puis les affaires chaudes, déduplique les prospects, présélectionne 8 visites (modifiable, maximum 50). Le commercial choisit les visites utiles et confirme la date ; aucune promesse de prévision IA ni d’itinéraire optimal n’est faite.

Brouillons conservés localement sur l’appareil par compte/entreprise. Ils ne comptent pas dans les KPI. Publication serveur nécessaire pour une vente. Historique immuable des révisions, motif pour corriger un résultat clôturé, contrôle de version en cas de conflit, nouvel envoi identique sans double vente. Le bouton Charger la version enregistrée permet de sortir d’un conflit après confirmation de remplacement du brouillon.

## Déployer depuis Cloud Shell

Extraire cette archive dans un nouveau dossier. Votre projet confirmé est `quiz-commercial`.

```bash
cd /chemin/Prospecto_1.4.0_47
bash deployer_cloud_shell.sh quiz-commercial
```

Le script utilise /tmp pour les dépendances et le cache npm afin de ménager le disque personnel Cloud Shell. Connexion Firebase requise ; si besoin : `npx --yes firebase-tools login --no-localhost`. Il déploie seulement les deux nouvelles fonctions puis les règles Firestore. Les autres fonctions déjà déployées restent présentes. Aucun index supplémentaire requis.

## Installer et compiler l’application

Dans un nouveau dossier sous Windows :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
flutter pub get
.\verifier_prospecto.ps1
flutter run
```

L’installateur sauvegarde les fichiers remplacés et préserve la configuration locale Firebase et les clés. Ou travailler directement dans le nouveau dossier extrait. Conserver vos fichiers Firebase et votre signature de publication. Compiler avec votre SDK Android/iOS habituel. Version Play Store : 47.

## Limites connues

Pas de déploiement de production, de build APK signé ni de validation sur votre Fold réel dans cet environnement. Opportunités chargées par pages, 4 commerciaux en parallèle ; très grands volumes justifieront ultérieurement des agrégats serveur et une recherche indexée. Le portefeuille lit toutes les pages lorsqu’un filtre/recherche le nécessite afin de ne pas donner de résultats faussement complets. Le fonctionnement hors connexion porte sur les brouillons locaux, pas sur une publication de contrat. Les vues ventes demandent une connexion et signalent les erreurs.

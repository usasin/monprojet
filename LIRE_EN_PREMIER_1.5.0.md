# Prospecto 1.5.0+50 — Accueil Administrateur visuel

L’accueil Administrateur reprend la maquette approuvée : fond pastel bleu/vert/pêche, portefeuille coloré, deux camemberts côte à côte sur téléphone standard, bandeau d’activité, alertes compactes. L’affichage s’adapte au Fold/tablette et au texte agrandi. Les illustrations dans `apercus` sont des rendus Flutter avec des données d’exemple ; aucun chiffre de démonstration n’est injecté dans l’application.

## Ce qui est réalisé

- Portefeuille de tous les prospects partagés de l’entreprise, y compris les anciennes fiches et les pages au-delà de 200 entrées.
- Nouveaux sur la période, à qualifier, chauds, à relancer : chaque compteur ouvre les fiches correspondantes, sans compter deux fois un prospect ayant plusieurs affaires.
- Contrats signés/perdus, montant HT déclaré et taux de gain sur la période ; accès en consultation aux affaires et à leur historique.
- Visites réalisées/restantes, nombre de tournées réalisées/prévues, RDV et commerciaux actifs ; accès aux tournées, à leurs étapes et aux fiches prospects.
- Relances en retard et invitations en attente, uniquement lorsqu’il y en a.
- Filtres Aujourd’hui/Semaine/Mois et Toutes les équipes/Responsable/Commercial. Tirer vers le bas pour actualiser ; revenir à Entreprise actualise aussi la vue.
- Cinq onglets Administrateur : Entreprise · Prospects · Équipes · Planning · Résultats. Aucun menu identique répété dans l’accueil et aucun bouton de tournée personnelle pour l’administrateur.

Les chiffres de l’accueil et les listes ouvertes depuis ses compteurs partagent le filtre choisi. L’onglet Résultats conserve ses propres filtres détaillés. Le répertoire Administrateur est en consultation : le travail terrain et la saisie commerciale restent dans les espaces concernés.

## Solo et autres rôles

L’accueil Solo, Reporting, Historique et leurs camemberts de la version 1.4.2 sont conservés. Responsable et Commercial gardent leurs écrans et droits actuels. Les données personnelles et celles des autres entreprises ne sont pas mélangées. Les règles Firebase restent la protection côté serveur.

## Calculs

Le portefeuille est le stock actuel ; les nouveaux, ventes et activités sont liés à la période. Une visite réalisée possède un compte rendu ; une tournée réalisée a un compte rendu pour chaque étape. Les affaires ouvertes sont exclues du taux de gain. Un montant inconnu est signalé, il n’est pas inventé. Un commercial actif a un accès actif et une activité sur la période. Le rattachement d’un prospect à une équipe utilise son créateur et les commerciaux de ses affaires. Les invitations concernent toute l’entreprise. Sans données, les anneaux sont neutres et aucun succès fictif n’est affiché. Une erreur de lecture affiche Réessayer plutôt que des zéros trompeurs.

## Installation

Le backend 1.4.1 déjà déployé sur `quiz-commercial` convient. Les fonctions et règles sont identiques : aucun nouveau déploiement Cloud Shell n’est nécessaire. L’interface change lorsque vous compilez et installez cette application 1.5.0+50.

Extraire le ZIP dans un nouveau dossier, ouvrir PowerShell dans `Prospecto_1.5.0_50`, puis :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
.\verifier_prospecto.ps1
flutter run
```

Le script sauvegarde les sources remplacées et conserve vos configurations Firebase, Maps, AdMob et signature locales. Adapter uniquement le chemin Destination à votre dossier habituel. Une première installation peut utiliser directement le dossier extrait avec ses configurations habituelles.

Pour produire votre APK de test :

```powershell
flutter build apk --debug
```

Pour publier, utiliser votre signature et votre profil de production habituels. Ce ZIP est le projet complet Flutter/Android/iOS/Firebase, pas un APK signé. iOS nécessite macOS ou votre CI habituelle.

## Vérification sur vos comptes

Administrateur : choisir un filtre, ouvrir les compteurs, consulter les prospects, contrats et étapes de tournée ; vérifier aussi la navigation des cinq onglets. Commercial : enregistrer un compte rendu, puis actualiser l’accueil Administrateur. Solo : ouvrir Reporting et Historique et vérifier leurs camemberts habituels. Vérifier thème clair/sombre et écran Fold fermé/ouvert.

Consulter `VERIFICATION_1.5.0.md` pour les contrôles exécutés. Le nom des messages Google reste documenté dans `CORRIGER_NOM_GOOGLE.md`.

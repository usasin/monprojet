# Prospecto 1.4.2+49 — Solo conservé, Reporting visible, Entreprise graphique

## Solo

L’accueil Solo reprend ses cartes, son fond bleu/vert/pêche et ses accès directs :
Créer ma tournée · Mes prospects · Carte · Reporting · Historique · Mes relances · Paramètres.
Il n’utilise plus l’accueil à quatre onglets de l’Entreprise.

- Créer ma tournée garde la recherche et la sélection de prospects pour préparer une tournée.
- Mes prospects ouvre les fiches enregistrées, avec les filtres Chauds, À relancer et Signés. Le doublon de destination est corrigé.
- Reporting garde le choix de date, les comptes rendus par prospect, les contacts, notes, reprogrammation et sauvegarde. Un camembert Présent / Absent / RDV / À renseigner suit la saisie du jour.
- Historique garde ses camemberts globaux et par date et ses fiches de visites terminées.
- Contrats & résultats est un accès complémentaire dans Reporting : signé/perdu, montant HT et taux de gain. Le suivi des contrats reste accessible dans les fiches prospects et par Suivi / contrat du compte rendu.

## Entreprise

Les espaces Administrateur, Responsable et Commercial gardent leurs droits et leur navigation par rôle.
Les vues d’activité ajoutent des camemberts Réalisées / Restantes et Présent / Absent / RDV.
Les résultats commerciaux affichent Signés / Perdus sur la période et l’avancement actuel des opportunités.
Les légendes commerciales ouvrent les affaires correspondantes. Les explications de calcul sont repliables.
L’accès Reporting est explicite dans l’accueil du Commercial.

Un compte rendu finalisé reste distinct d’un contrat signé. Le taux de gain exclut les affaires ouvertes.
Aucune donnée historique n’est convertie en vente.

## Installation de l’application

Le backend 1.4.1 et les règles Firestore ont déjà été déployés avec succès sur quiz-commercial.
Cette correction ne modifie ni les fonctions ni les règles : aucun nouveau déploiement Cloud Shell n’est requis.
Il faut compiler et installer l’application 1.4.2+49 pour voir l’accueil et les graphiques corrigés.

Sur Windows, extraire ce ZIP dans un nouveau dossier, puis lancer depuis ce dossier :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
.\verifier_prospecto.ps1
flutter run
```

Le script sauvegarde les sources remplacées et conserve les configurations et la signature locales.
Pour publier, utiliser la signature et le profil de production habituels. iOS nécessite macOS/CodeMagic.
Le projet complet contient Flutter, Android, iOS et les sources Firebase ; les caches de compilation et les clés privées ne sont pas inclus.

## À vérifier sur le téléphone

- Personnel : Reporting et Historique visibles dans les cartes de l’accueil ; chacun ouvre son écran habituel.
- Créer ma tournée : recherche, sélection, enregistrement ; Mes prospects : fiches et suivi.
- Modifier le statut d’une visite dans Reporting : le camembert se met à jour ; la sauvegarde du compte rendu reste nécessaire.
- Signer une affaire dans une fiche : vérifier les camemberts et les montants dans Contrats & résultats.
- Entreprise : petits/grands écrans, texte agrandi, thème clair/sombre, filtres de période et de commercial.

Le réglage du nom dans les messages de connexion Google reste documenté dans CORRIGER_NOM_GOOGLE.md.

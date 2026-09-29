# Mode développeur Prospecto — version 1.3.6+34

Le mode développeur est protégé par une **custom claim Firebase** nommée `prospectoDeveloper`.
Il n'est pas activable depuis le téléphone par un utilisateur normal.

## Ce qu'il permet

- Premium personnel complet sans achat Google Play ;
- aucune publicité pour le compte développeur ;
- création de codes d'activation de test ;
- création d'une entreprise de test par le parcours normal ;
- test des forfaits Essentiel (3 places), Équipe (10 places) et Business (25 places) ;
- changement de forfait instantané sans Stripe ;
- invitations, rôles, prospects partagés, tournées, rappels et reporting ;
- suppression complète de l'entreprise de test pour recommencer.

Les entreprises réelles et leurs abonnements Stripe ne peuvent pas être modifiés depuis cette console.

## Activation dans Google Cloud Shell

Depuis la racine du projet :

```bash
bash activer_mode_developpeur.sh votre-adresse@email.fr
```

Le script :

1. compile les Cloud Functions ;
2. accorde la custom claim au compte indiqué ;
3. déploie uniquement les quatre fonctions nécessaires.

Ensuite, déconnectez puis reconnectez le compte dans Prospecto.
La rubrique **Développement → Console développeur** apparaît dans Paramètres.

## Retrait

```bash
bash retirer_mode_developpeur.sh votre-adresse@email.fr
```

## Sécurité

- la custom claim est vérifiée dans l'application et dans chaque Cloud Function ;
- les codes développeur sont liés au UID du développeur ;
- seule une organisation marquée `developerTest: true` peut changer de forfait ou être supprimée sans paiement ;
- une entreprise Stripe réelle ne peut pas être convertie en entreprise de test.

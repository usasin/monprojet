# Prospecto 1.3.2+30

Cette archive est la version Android à utiliser pour la prochaine mise à jour Google Play.

## Abonnements conservés

- **Personnel Premium** : achat intégré Google Play inchangé (`premium_monthly` / `premium_yearly`).
- **Entreprise** : Stripe automatique, avec code d’activation après paiement.

## Offres Entreprise

- Essentiel : 19,90 €/mois — 3 utilisateurs au total.
- Équipe : 39,90 €/mois — 10 utilisateurs au total.
- Business : 79,90 €/mois — 25 utilisateurs au total.

Les trois offres donnent les mêmes fonctions Entreprise V1. Seul le nombre de places change.

## Page Tarifs revue

La page distingue désormais clairement :

- la pastille bleue **Personnel**, gérée par Google Play ;
- la pastille verte **Entreprise**, gérée par Stripe ;
- le fonctionnement du code d’activation automatique ;
- le fait que les salariés rejoignent l’entreprise gratuitement avec un code d’invitation.

Aucun lien de paiement Stripe externe n’est ajouté dans l’application Android. Les liens de paiement restent sur le site Prospecto ou sont transmis commercialement, afin de ne pas mélanger le paiement Google Play du particulier et la souscription Entreprise.

## Backend

Le backend Stripe déployé reste compatible avec cette version. Aucune modification des trois fonctions Stripe n’a été faite dans cette archive.

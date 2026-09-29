# Prospecto 1.3.7+35 — Pilotage de l'équipe

Cette mise à jour ajoute le pilotage opérationnel des équipes commerciales sans modifier l'abonnement personnel Google Play ni l'automatisation Stripe Entreprise.

## Affichage selon le rôle

### Administrateur principal

- accueil : **Direction de l’entreprise** ;
- accès complet à l'identité, au forfait, aux rôles et aux membres ;
- consultation des calendriers, tournées, rendez-vous, reportings et statistiques ;
- attribution de tournées et ajout de rendez-vous ;
- activation ou désactivation de l'autonomie de chaque commercial ;
- accès aux données historiques des commerciaux dont l'accès est inactif.

### Responsable commercial

- accueil : **Pilotage commercial** ;
- gestion opérationnelle des commerciaux ;
- attribution et remplacement d'une tournée ;
- ajout et annulation d'un rendez-vous dans le calendrier d'un commercial ;
- contrôle de l'autonomie des tournées ;
- consultation des calendriers, reportings et statistiques ;
- aucun accès au transfert de propriété ni aux décisions réservées à l'administrateur principal.

### Commercial

- accueil : **Mon activité commerciale** ;
- consultation de son propre calendrier ;
- réalisation des tournées attribuées et saisie des reportings ;
- création de ses propres tournées uniquement lorsque l'autonomie est activée ;
- impossibilité de supprimer ou de réorganiser une tournée verrouillée par son responsable ;
- accès aux prospects partagés de l'entreprise.

## Protections intégrées

- une tournée attribuée est verrouillée ; le commercial peut la réaliser et compléter ses reportings, mais pas en modifier les prospects ;
- lorsqu'une tournée est remplacée, seuls les reportings correspondant encore aux prospects conservés sont gardés ;
- un rendez-vous en conflit avec un autre créneau déclenche un avertissement et demande une confirmation explicite ;
- seules les personnes ayant le rôle Administrateur principal ou Responsable commercial peuvent piloter l'équipe ;
- l'attribution est limitée aux commerciaux actifs ;
- toutes les actions sensibles sont inscrites dans l'historique et les commerciaux reçoivent une notification Firebase lorsqu'elle est disponible ;
- les calendriers et résultats historiques des commerciaux inactifs restent consultables par les responsables.

## Écrans ajoutés

- vue entreprise ou vue commerciale ;
- planning hebdomadaire de l'équipe ;
- liste des commerciaux et contrôle de l'autonomie ;
- fiche individuelle avec prochaines activités et résultats ;
- statistiques consolidées des 30 derniers jours ;
- espace commercial personnel adapté à son niveau d'autonomie.

## Identité conservée

- package Android : `com.ainego.ai_prospect_gps` ;
- Firebase : `quiz-commercial` ;
- version : `1.3.7+35` ;
- abonnement personnel Google Play conservé ;
- trois forfaits Stripe Entreprise conservés ;
- mode développeur conservé.

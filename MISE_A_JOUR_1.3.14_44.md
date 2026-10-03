# Prospecto 1.3.14+44 — Release candidate auditée

## Objectif
Cette passe ne rajoute pas de fonctionnalité métier majeure. Elle sécurise et fiabilise tout ce qui a été construit avant la prochaine publication.

## Session et changement de compte
- purge du cache Premium/AdMob lorsqu'un UID change ;
- retrait du token FCM de l'ancien compte avant déconnexion ;
- centralisation de la déconnexion Google/Firebase et du nettoyage de l'espace actif ;
- conservation de l'identité visible (nom, e-mail, espace et rôle) introduite en 1.3.13.

## Entreprise et performance
- statistiques des commerciaux chargées par groupes bornés au lieu de 25 lectures séquentielles ;
- planning : tournées et rendez-vous sont demandés en parallèle ;
- aucune modification des permissions OWNER / MANAGER / REP ;
- suppression des prospects partagés toujours réservée à OWNER/MANAGER.

## Publication sécurisée
- nouveau `verifier_prospecto.ps1` ;
- contrôle version, package Android, Firebase, targetSdk, AdMob, Maps et profil ADMIN ;
- `flutter analyze` + `flutter test` obligatoires avant le build ;
- `build_release.ps1` bloque la création de l'AAB si un contrôle échoue ;
- `.gitignore` racine protège les keystores, mots de passe, fichiers locaux et comptes de service.

## Internationalisation
Ajout des traductions manquantes repérées sur l'autonomie commerciale, le pilotage manager et l'indication de publicité du mode gratuit.

## Version
`1.3.14+44`

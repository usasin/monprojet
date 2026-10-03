# RC7 — correction du test de séparation Paramètres / Entreprise

Le code de `settings_screen.dart` contient bien une section `Entreprise` séparée de `Préférences`.
Le test RC6 cherchait à tort la chaîne exacte `title: 'Membres & invitations'`, alors que le titre est conditionnel selon le rôle (`orgProv.canManageTeam ? 'Membres & invitations' : 'Mon entreprise'`).

RC7 modifie uniquement le test pour vérifier la présence réelle du libellé sans imposer une syntaxe Dart incompatible avec cette logique conditionnelle.
Aucun comportement applicatif n'est modifié.

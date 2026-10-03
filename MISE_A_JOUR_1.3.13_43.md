# Prospecto 1.3.13 (43) — Identité de compte et session claire

## Pourquoi cette mise à jour

La session Firebase reste volontairement connectée entre deux ouvertures, mais l'utilisateur ne voyait pas clairement quel compte était actif. Dans l'espace Entreprise, cela créait aussi une confusion entre l'identité de connexion et le rôle métier.

## Changements

- Affichage permanent du compte connecté dans la barre d'espace de l'accueil : e-mail ou session invitée.
- En Entreprise, affichage conjoint **Entreprise + rôle + compte connecté**.
- Nouvelle carte **Compte connecté** dans Paramètres avec nom, e-mail, méthode de connexion, espace actif et badge développeur le cas échéant.
- Nouvelle action **Changer de compte** qui ferme Firebase et libère aussi la session Google locale avant de revenir à l'écran de connexion.
- La déconnexion classique libère également la session Google locale.
- L'écran **Espace entreprise** affiche l'identité active avant toute création ou adhésion et permet de changer de compte immédiatement.
- Le cockpit OWNER / MANAGER / REP affiche explicitement l'e-mail du compte en plus du rôle.
- Le splash indique brièvement le compte restauré lorsque Firebase reprend une session existante.
- Traductions FR/EN ajoutées.

## Séparation importante

- **Identité Firebase** : la personne réellement connectée (nom/e-mail).
- **Espace de travail** : Personnel ou Entreprise.
- **Rôle entreprise** : OWNER, MANAGER ou REP.
- **Droit développeur** : claim `prospectoDeveloper`, affichée séparément.

Version : `1.3.13+43`.

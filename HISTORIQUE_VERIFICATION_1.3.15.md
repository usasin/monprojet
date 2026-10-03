# Vérification du projet 1.3.15+45

Contrôles exécutés le 1er octobre 2026 sur les sources livrées.

| Contrôle | Résultat |
|---|---|
| Compilation TypeScript des Cloud Functions | Réussie |
| Analyse statique Flutter | 0 erreur ; 58 avertissements et 501 informations (notamment API dépréciées et code inutilisé) |
| Suite Flutter | 34 tests réussis |
| Tests Firebase sur émulateur local | 12 scénarios réussis |
| Invitation sur écran étroit et large, avec clavier | Tests widgets réussis |
| Attribution de tournée sur viewport 740 × 600 avec clavier de 280 px | Test widget réussi, sans exception de débordement |
| Ouverture/fermeture répétée du dialogue d’invitation | Test widget réussi |

Les scénarios Firebase vérifient : droits de lecture par commercial, périmètre du responsable, autonomie malgré un ancien champ à false, refus d’administration au responsable, champs obligatoires d’invitation, aperçu du destinataire, mauvais e-mail, e-mail non vérifié, double activation simultanée, impossibilité de changer son rôle via un autre code, attribution au bon périmètre, RDV créé par le commercial, et révocation avec historique conservé.

Outils : Flutter 3.47.5 / Dart 3.13.4 ; compilation TypeScript ; Firestore Emulator 1.19.8. Les journaux utiles sont dans `verification/`.

## Limites précises

- Aucun déploiement sur le Firebase réel n’a été effectué.
- Aucun APK/AAB de production signé ni build iOS n’a été créé. Les certificats et clés de signature doivent rester ceux du projet local.
- Les tests de mise en page utilisent des dimensions simulées ; ils ne remplacent pas la recette sur le Samsung Fold réel.
- La stack trace de l’assertion `'_dependents.isEmpty'` n’est pas disponible. Les correctifs de durée de vie des contrôleurs, la préparation différée après montage et le renouvellement du contrôleur d’onglets sont testés partiellement, mais le crash exact rapporté doit être rejoué sur l’appareil avant publication.
- Le script PowerShell d’installation a été relu mais pas exécuté sous Windows dans cet environnement.

## Rejouer les contrôles

```powershell
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
npm ci --prefix functions
npm run build --prefix functions
```

Pour les tests Firebase locaux, avec Java 17+ et Node installés, depuis la racine :

```powershell
npm ci --prefix qa
$env:GCLOUD_PROJECT = "demo-prospecto"
$env:GOOGLE_CLOUD_PROJECT = "demo-prospecto"
.\qa\node_modules\.bin\firebase.cmd emulators:exec --only firestore --project demo-prospecto --config firebase.emulators.json "node qa/enterprise.integration.cjs"
```

Le test refuse de démarrer sans émulateur ou sans identifiant de projet de démonstration.

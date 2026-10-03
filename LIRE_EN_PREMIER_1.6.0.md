# Prospecto 1.6.0+51 — Fiches et pilotage Entreprise

## Nouveautés

- Fiche prospect en cartes : identité, activité et rôle du contact, téléphone, e-mail, site, adresse, suivi commercial, notes et repères, selon les informations enregistrées.
- Opportunité en consultation : identité, statut, avancement, commercial, prochaine action, notes et historique. La saisie conserve ses droits et ses contrôles habituels.
- Administration : suppression confirmée des prospects, opportunités et invitations. Le serveur réserve ces opérations à un administrateur actif de la même entreprise.
- Dans la roue des paramètres Administrateur, « Indicateurs entreprise » permet de cocher Contrats signés et/ou Chiffre d’affaires. Au moins un indicateur reste coché. Les préférences s’appliquent à toute l’entreprise ; les montants enregistrés sont conservés. Lorsque Chiffre d’affaires est décoché, aucun montant ni champ de montant n’apparaît dans les fiches d’opportunité, l’accueil, les résultats ou les comparaisons de l’entreprise.
- Comparer les équipes depuis l’accueil Administrateur : cartes de prospects, visites et résultats sur le périmètre et la période choisis. Aucun classement fictif ; les volumes et taux conservent leurs propres dénominateurs.
- Responsable commercial : accueil « Mon équipe », portefeuille de son périmètre, commerciaux rattachés, planning et résultats. Comparaison entre ses commerciaux. Les données commerciales des autres équipes ne sont pas chargées.
- Barre du bas : cinq libellés sur une ligne. L’accueil conserve le portefeuille à quatre cases et les graphiques colorés. Le mode Solo conserve son accueil, Reporting, Historique et ses camemberts.

## Suppressions

Une invitation supprimée est désactivée, ainsi que son lien d’acceptation. Une opportunité supprimée sort du suivi et des indicateurs ; le serveur conserve sa trace et son historique. Un prospect supprimé est retiré du répertoire et archivé côté serveur ; les opportunités et comptes rendus déjà enregistrés sont conservés. La confirmation précise ces effets. Les autres rôles ne peuvent pas effectuer ces suppressions.

Un montant inconnu n’est pas présenté comme 0 €. Sans activité, les graphiques restent neutres. Les aperçus inclus utilisent uniquement des données d’exemple des tests.

## 1. Déployer le backend sur quiz-commercial

Cette version nécessite un nouveau déploiement pour les réglages et suppressions. Importer le ZIP dans le dossier personnel Cloud Shell, puis copier :

```bash
(
set -e
PROSPECTO_DIR="$(mktemp -d /tmp/prospecto-160.XXXXXX)"
unzip -q "$HOME/Prospecto_1.6.0_51_PROJET_COMPLET_ENTREPRISE.zip" -d "$PROSPECTO_DIR"
cd "$PROSPECTO_DIR/Prospecto_1.6.0_51"
bash deployer_cloud_shell.sh quiz-commercial
)
```

Le script installe et compile les fonctions dans /tmp, déploie saveSalesOpportunity, updateEnterpriseDisplaySettings, deleteEnterpriseRecord et revokeOrgInvite, puis les règles et index Firestore. Il ne supprime pas les autres fonctions.

## 2. Installer et compiler l’application

Extraire le ZIP dans un nouveau dossier. Depuis PowerShell ouvert dans Prospecto_1.6.0_51 :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
flutter pub get
.\verifier_prospecto.ps1
flutter run
```

Adapter Destination à votre dossier habituel. Le script conserve vos configurations locales et sauvegarde les sources remplacées. Le déploiement backend seul ne modifie pas l’interface : installer la nouvelle compilation.

Pour un APK de test : `flutter build apk --debug`. Pour Google Play : utiliser `build_release.ps1` et votre signature habituelle. Ce ZIP contient les sources complètes Flutter, Android, iOS et Firebase ; ce n’est pas un APK signé. iOS nécessite macOS ou votre CI.

## Vérifier sur vos comptes

Administrateur : ouvrir une fiche depuis le portefeuille, consulter son opportunité et son historique, essayer les réglages d’indicateurs et la comparaison. Tester une suppression avec une fiche de test et une invitation de test. Responsable : vérifier uniquement ses commerciaux et leur activité. Commercial : vérifier la saisie et l’actualisation de la direction. Solo : vérifier Reporting et Historique habituels. Vérifier clair/sombre et Fold fermé/ouvert sur votre appareil.

Voir VERIFICATION_1.6.0.md pour les contrôles exécutés ici.

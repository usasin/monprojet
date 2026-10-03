# Prospecto 1.4.1+48 — Solo et Entreprise harmonisés

Projet complet Flutter Android/iOS avec sources Firebase. Installer une nouvelle compilation de l’application et redéployer la fonction `saveSalesOpportunity` et les règles Firestore. Le backend 1.4.0 déjà déployé n’est pas remplacé en bloc.

## Ce qui change

- Solo : Aujourd’hui · Prospects · Tournées · Résultats. Quatre destinations distinctes, avec paramètres dans l’engrenage. L’accueil affiche l’activité du jour et les indicateurs de vente.
- Prospects ouvre le portefeuille enregistré : recherche, Chauds, À relancer, Signés, fiche contact et opportunités. Créer une tournée ouvre la recherche/sélection de visites depuis le + de Tournées. Les deux boutons n’ouvrent plus la même page.
- Tournées ouvre les plans enregistrés par date. Carte, compte rendu et modification utilisent la date sélectionnée. Historique des visites et rappels restent accessibles dans ce contexte.
- Suivi Solo : intérêt froid/tiède/chaud, prochaine action datée, étapes de vente, contrat signé/perdu, montant HT facultatif, taux de gain. Accessible dans le portefeuille et depuis « Suivi / contrat » dans un compte rendu. Plusieurs opportunités possibles pour un même prospect.
- Solo privé sous `/users/{uid}/opportunities` ; Entreprise sous `/apps/prospecto/orgs/{orgId}/memberData/{uid}/opportunities`. Un même compte peut utiliser les deux sans mélange des données ou des brouillons.
- Le serveur contrôle la signature, les montants, les révisions et les conflits. Historique immuable, correction justifiée, tentative identique sans double vente.
- Entreprise : fond bleu/vert/pêche identique à la famille visuelle Solo, cartes claires arrondies, indicateurs colorés, libellés courts. Les explications sur le taux de gain sont repliables dans Résultats. Aucun outil terrain ajouté aux rôles d’administration.
- Historique : suppression de la note arbitraire sur 10. « Rapports finalisés » remplace « Clôtures » pour distinguer comptes rendus et contrats. Toucher un prospect de l’historique permet d’ouvrir sa fiche de suivi en Solo/Commercial.
- Changer de compte Google utilise `signOut`, sans révoquer l’autorisation avec `disconnect`. Les avis de sécurité envoyés par Google ne sont pas contrôlés par Prospecto.

Les comptes rendus historiques ne sont jamais convertis en contrats signés. Les ventes existantes en Entreprise restent à leur emplacement. Les quotas de tournée, le Premium et les publicités restent régis par les services existants. Le libellé « Annonce test » d’une compilation de développement n’est pas un message de Prospecto envoyé aux contacts.

## Déployer dans Cloud Shell

Importer ce ZIP dans Cloud Shell, puis coller :

```bash
(
set -e
PROSPECTO_DIR="$(mktemp -d /tmp/prospecto-141.XXXXXX)"
unzip -q "$HOME/Prospecto_1.4.1_48_PROJET_COMPLET_SOLO_ENTREPRISE.zip" -d "$PROSPECTO_DIR"
cd "$PROSPECTO_DIR/Prospecto_1.4.1_48"
bash deployer_cloud_shell.sh quiz-commercial
)
```

Le script copie uniquement les sources nécessaires dans `/tmp`, installe les dépendances, compile et déploie seulement `saveSalesOpportunity`, puis les règles Firestore. `assignManagerTeam`, les autres fonctions, les index et les règles Storage déjà déployés ne sont pas modifiés. Ne pas accepter de suppression d’anciennes fonctions si un outil la propose.

## Installer sur Windows

Extraire le ZIP dans un nouveau dossier. Pour reprendre la configuration locale existante avec sauvegarde :

```powershell
.\installer_mise_a_jour.ps1 -Destination "C:\dev\prospecto"
cd C:\dev\prospecto
flutter pub get
.\verifier_prospecto.ps1
flutter run
```

Le script conserve la configuration Firebase, les fichiers de signature et les clés locales. Pour publier, utiliser le SDK Android et la signature habituels ; iOS nécessite macOS/CodeMagic. Version : 1.4.1, build 48.

## Connexion Google : nom technique restant à corriger

`project-163745254135` correspond au numéro de `quiz-commercial` dans le fichier Firebase Android fourni. Le nom affiché relève de Google Auth Platform, il ne peut pas être changé en modifiant uniquement ce ZIP.

Consulter **CORRIGER_NOM_GOOGLE.md**. Aucun réglage de marque Google n’a été modifié à distance. Google peut continuer à envoyer un avis lors d’une première ou nouvelle autorisation ; la suppression de ces avis n’est pas promise.

## Vérifier sur téléphone

- Solo : les quatre onglets, création de tournée, portefeuille, carte et rapport à la bonne date.
- Créer une affaire chaude avec relance, enregistrer un contrat signé, vérifier le montant et le taux, puis corriger avec motif.
- Même compte : passer Personnel → Entreprise → Personnel et constater les portefeuilles, brouillons et contrats distincts.
- Administrateur/Responsable : accès d’équipe et apparence claire/sombre, listes, claviers, Fold replié/déplié et texte agrandi.
- Changement de compte Google : le sélecteur doit rester disponible sans retrait systématique du consentement.

Pas de test sur votre Fold réel, de build APK signé ou de build iOS réalisé ici. Les brouillons locaux ne deviennent des résultats qu’après publication serveur. Les résultats de la période restent distincts du stock d’affaires ouvertes.

# Afficher Prospecto dans la connexion Google

La configuration Android fournie confirme : projet `quiz-commercial`, numéro `163745254135`. Le nom générique de l’e-mail correspond à ce projet. La correction du code évite une révocation à chaque changement de compte, mais elle ne renomme pas l’application chez Google.

1. Ouvrir https://console.cloud.google.com/auth/branding?project=quiz-commercial avec un compte autorisé sur ce projet.
2. Dans Google Auth Platform → Branding / Marque : vérifier le nom et saisir **Prospecto** ; renseigner l’adresse de support surveillée et les liens réels du site, de confidentialité et des conditions.
3. Vérifier l’appartenance du domaine, les liens de confidentialité et les coordonnées avant de soumettre. Ne pas inventer un lien manquant.
4. Vérifier Audience et Clients : garder les clients OAuth existants d’Android/iOS/Web et leurs identifiants. Une nouvelle clé ou un nouveau projet ne sont pas nécessaires pour cette correction de marque.

Le réglage de marque est commun au projet Google. Si plusieurs applications utilisent ses clients OAuth, retenir un nom qui les représente (par exemple Digital Solutions AI) au lieu de renommer aveuglément tout le projet au nom d’une seule application.
5. Soumettre la marque à la vérification proposée par Google. La documentation indique que le nom/logo visibles à la connexion dépendent de cette vérification. Un simple changement du nom de projet Cloud ne remplace pas cette étape.
6. Après validation, essayer une autorisation avec un compte de test et vérifier ce que Google affiche. Les notifications de sécurité Google peuvent continuer : Prospecto ne peut pas les désactiver.

À réaliser dans la console : aucun accès à ce réglage et aucune soumission de marque effectués dans ce correctif.

Sources officielles consultées le 3 octobre 2026 :
- https://support.google.com/cloud/answer/15549049?hl=en
- https://developer.android.com/identity/authorization

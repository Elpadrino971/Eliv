# Prochaine version — liste « après le concert DJ Wilson »

Décidé avec le propriétaire le 1er octobre 2026. À attaquer le lundi 5 octobre.

## 1. Pack « place + pièces cadeaux » (site, paiement par carte)
- Page de paiement Stripe : la place + une **option additionnelle cochable**
  (ex. « + 200 pièces pour envoyer des cadeaux pendant le live », +2 €).
- Admin, sur le concert : bloc « Pack cadeaux » (nombre de pièces, prix, interrupteur).
- Après paiement : pièces créditées sur le compte lié à l'e-mail ; si le compte
  n'existe pas encore, créditées à sa création (même mécanique que les places).
- Mention « pièces non remboursables » sur la page.
- Dans l'app, les pièces par carte sont interdites par Apple : le pack y passerait
  en achat intégré (commission 30 %). Le proposer d'abord sur le site.
- **Refaire un paiement test réel complet ensuite** (achat + remboursement).

## 2. Page profil artiste (app, nouvelle version)
1. Carrousel de photos en haut (remplace la photo unique).
2. Nom + bouton « Suivre » + nombre d'abonnés.
3. Bouton **Bio** : l'histoire de l'artiste + liens officiels (site, Instagram,
   YouTube, TikTok, Spotify).
4. Onglets : **Concerts** (à venir + replays), **Vidéos** (clips),
   **Coulisses** (nouvelle section studio / reportages).
- Serveur : plusieurs photos par artiste ; catégorie « coulisses » pour les
  vidéos (admin + page Médias de l'artiste).

## 2 bis. Photos dans le feed (demande d'un collaborateur)
- Un post du feed peut être une **photo** ou un **carrousel de photos** (plusieurs
  images dans un seul post, légende commune), en plus des vidéos.
- Serveur : type `photo` sur `feed_clips`, images hébergées par nous, glisser-déposer
  de plusieurs photos dans la page Médias de l'artiste (légende en une fois).
- Web (/web/) : affichage immédiat, sans mise à jour d'app.
- App : nécessite une nouvelle version. L'API ne servira les photos qu'aux
  clients qui les demandent (sinon l'ancienne app tenterait de lire une image
  comme une vidéo).
- En attendant : transformer les photos en petite vidéo diaporama (CapCut) et
  l'envoyer par la page Médias, ça marche dans toutes les versions.

## 3. Autres
- Mode visiteur déjà dans la 1.2.0 (19) Android ; l'ajouter à la prochaine iOS.
- Sections DJ / musicien / artiste / sport : branche `feat/departements`.
- Retirer `RC_ALLOW_SANDBOX=1` dès que les validations Apple et Google sont tombées.
- Stripe : finir la vérification d'identité (virements) ; branding de la page de
  paiement (Entreprise → Image de marque : `#0A1226`, `#E6C76A`, logo `icon-512.png`).
- Sauvegarder la clé d'importation Android (fichier .jks + mot de passe) à deux endroits.
- Invités du concert DJ Wilson (Jocelyne Labylle, Dominique Lorté, Jean-Michel
  Jean-Louis) : ajouter leurs comptes artiste, puis 🎤 Invités sur le concert.

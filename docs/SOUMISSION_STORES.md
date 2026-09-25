# VybzzZ — Soumission App Store et Google Play

Version à soumettre : **1.1.2+15** (précédente en ligne : 1.1.1+14, du 7 septembre 2026).
Branche : `release/app-all`. Ne jamais builder l'app depuis `feat/vibe-crm`.

---

## 1. Ce que cette version apporte

Dix-neuf correctifs depuis la dernière soumission :

- Compilation Android réparée (conflit de cible Java/Kotlin entre greffons).
- Connexion Google sans Firebase Auth, avec la raison d'échec affichée.
- Écrans de présentation au premier lancement supprimés.
- Ouverture et connexion directes sur le Live + Feed.
- Feuille d'aide quand on tente de se connecter sans compte existant.
- Plus de demande de notifications avant d'avoir un compte.
- Marque écrite « VybzzZ » dans tous les textes visibles.
- Saisie du code de vérification réparée sur Android.
- Bouton « Créer un compte » remonté sous « Se connecter ».
- Manifeste de confidentialité iOS ajouté.
- Achat d'abonnement : l'application ne se fige plus (le voile de chargement
  était impossible à refermer, y compris juste après un débit Apple réussi).
- Croix de sortie et onglets toujours visibles sur l'écran Live.
- Bouton de bascule fan / artiste rendu réactif : il affiche le mode réel.
- Flèche de retour masquée quand il n'y a rien derrière (écran Événements).
- Blocage et signalement d'un compte, avec la liste des comptes bloqués et
  le déblocage depuis les réglages (exigence App Store 1.2).
- Écran d'achat d'abonnement retiré du menu ; « Gérer mon abonnement », et
  donc la restauration d'achat exigée par la règle 3.1.1, reste accessible.
- L'application n'annonce plus un abonnement activé quand le store n'a rien
  confirmé : elle affiche « achat en cours de confirmation ».
- Bannière « Boutique de points » retirée : sur Android elle confirmait un
  achat qui ne créditait aucun point.
- Anglais codé en dur supprimé des écrans (les dialogues affichaient
  « Success », « Warning » et « Continue » quelle que soit la langue).
- Textes d'autorisation iOS réécrits, permissions Android bornées, et
  trafic en clair désormais bloqué en production.

---

## 2. À FAIRE AVANT DE BUILDER

### 2.1 Connexion Google — BLOQUANT sur Android

`android/app/google-services.json` contient `"oauth_client": []`. Aucune empreinte
SHA-1 n'est enregistrée dans Firebase : **le bouton Google échoue pour tout le
monde**, y compris depuis le Play Store.

Trois empreintes à enregistrer dans Firebase (projet `vybzzz-app`, application
Android `com.app.vybzz`, « Ajouter une empreinte ») :

```bash
# clé d'upload (mot de passe demandé — ne jamais le transmettre à qui que ce soit)
keytool -list -v -keystore android/app/upload-keystore.jks | grep -E "Alias|SHA1"
# clé de debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1
```

Troisième empreinte : Play Console → Configuration → Intégrité de l'application →
« Certificat de clé de signature d'application » → SHA-1. Sans elle, la version
distribuée par Google ne pourra pas se connecter, même si ton build local marche.

Puis retélécharger `google-services.json` et remplacer le fichier. Vérifier :

```bash
python3 -c "import json;d=json.load(open('android/app/google-services.json'));print([len(c['oauth_client']) for c in d['client']])"
# attendu : [1, 1] ou plus — surtout pas [0, 0]
```

Détail complet : `docs/GOOGLE_SIGNIN.md`.

### 2.2 Manifeste de confidentialité iOS

`ios/Runner/PrivacyInfo.xcprivacy` est créé et référencé dans le projet Xcode.
Sans lui, App Store Connect renvoie l'avertissement ITMS-91053 puis refuse.

Vérification après `flutter build ipa` : le fichier doit être présent dans le
bundle. Si Xcode ne le voit pas, l'ajouter à la main (glisser le fichier dans le
groupe Runner, cocher la cible Runner).

### 2.3 Trafic réseau — à tester sur un appareil

`android:usesCleartextTraffic="true"` autorisait tout le trafic en HTTP non
chiffré, jetons de session compris. Remplacé par un fichier de configuration
réseau qui chiffre tout, sauf les adresses de développement local.

L'API, Mux et les images sont déjà en HTTPS. **Faire un live complet sur un
appareil réel avant de soumettre** : si le module de diffusion utilisait une
adresse en clair quelque part, c'est là que ça se verrait.

### 2.4 Fiche des stores

- **Politique de confidentialité** : `https://vybzzz.online/confidentialite.html`
- **CGU** : `https://vybzzz.online/cgu.html`
- **Assistance** : `https://vybzzz.online/faq.html`
- **Contact** : `contact@vybzzz.online` (réception active depuis le 24 septembre)

---

## 3. Conformité App Store 1.2 — contenu publié par les utilisateurs

Apple exige quatre garde-fous. État actuel :

| Exigence | État |
|---|---|
| Filtrage automatique du contenu choquant | Sightengine sur images, vidéos, textes, + mots interdits |
| Signalement d'un contenu | `POST /api/report-event` vers `content_reports`, visible dans l'admin |
| **Blocage d'un compte abusif** | Fait : menu « … » sur un profil (Signaler / Bloquer) + liste des comptes bloqués dans les réglages |
| Contact public | `contact@vybzzz.online`, affiché sur le site |

Routes de blocage (toutes authentifiées) : `POST /api/block-user`,
`POST /api/unblock-user`, `GET /api/blocked-users`. Un compte bloqué
disparaît du feed et du chat des lives. Côté app : menu « … » sur la fiche
d'un artiste (Signaler avec six motifs / Bloquer), et Réglages →
« Comptes bloqués » pour débloquer soi-même, sans passer par le support.

Autres points Apple déjà couverts : suppression de compte depuis l'app
(règle 5.1.1v), aucun SDK de suivi publicitaire donc aucune fenêtre ATT requise.

---

## 4. Build

```bash
cd ~/Downloads/Vybzzz-V12026-version-couplee
git checkout release/app-all && git pull origin release/app-all
grep '^version:' pubspec.yaml            # attendu : version: 1.1.2+15
grep -n "mainIP = " lib/Global/api.dart  # attendu : https://api.vybzzz.online
flutter clean && flutter pub get && flutter analyze

# Android
test -f android/key.properties && echo "keystore OK" || echo "STOP : key.properties manquant"
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | head -5

# iOS
cd ios && pod install --repo-update && cd ..
flutter build ipa --release --export-method app-store
```

Upload : Play Console → Test interne d'abord, puis Production.
Transporter ou Xcode → TestFlight, puis soumission.

---

## 5. À tester sur un vrai appareil avant d'envoyer

- Créer un compte, recevoir le code par e-mail, le saisir case par case sur Android.
- Utiliser le bouton « Valider mon compte en un clic » depuis l'e-mail.
- Se connecter avec Google (après l'étape 2.1, sinon ce test échouera).
- Tenter de se connecter sans compte : la feuille d'aide doit proposer d'en créer un.
- Acheter des Arena Points en bac à sable, envoyer un cadeau.
- Regarder un live, écrire dans le chat.
- Supprimer son compte, puis vérifier qu'on ne peut plus se connecter.
- Bloquer un compte depuis le menu « … » : il disparaît du feed et du chat.
- Le débloquer depuis Réglages → « Comptes bloqués » : il réapparaît.
- Basculer fan → artiste → fan : le libellé du bouton doit suivre le mode réel.
- Vérifier qu'aucune entrée « Acheter un abonnement » ne reste dans le Profil
  ni dans les Réglages, et que « Gérer mon abonnement » s'ouvre bien.
- Vérifier qu'aucune bannière « Boutique de points » ne reste dans le
  portefeuille, et recharger des points par les cartes du haut.
- Lancer un live complet : image, son, chat, et son routé vers un casque
  Bluetooth (valide la nouvelle configuration réseau).
- Lire les demandes d'autorisation iOS : elles doivent nommer précisément
  l'usage, pas dire « this app needs… ».
- Écrire au support depuis l'app, puis vérifier que le ticket apparaît dans
  l'admin (Support & contenu → Support) et que la réponse revient dans l'app.
- Ouvrir l'historique du portefeuille : il ne doit plus être vide si des
  cadeaux ou des billets existent.

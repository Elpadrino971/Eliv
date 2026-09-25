# VybzzZ — Soumission App Store et Google Play

Version à soumettre : **1.1.2+15**.

Versions actuellement en ligne — elles ne sont pas alignées :

| Store | En production |
|---|---|
| Google Play | **1.0.7 (code 8)** — très en retard |
| App Store | 1.1.1 (build 14) |

Le code de version 15 est bien supérieur à 8, Play l'acceptera sans conflit.
L'écart explique aussi l'alerte « Problèmes liés au SDK » du 20 août : elle
porte sur la 1.0.7, construite avec des bibliothèques bien plus anciennes que
celles du code actuel.
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

### 2.1 Connexion Google — état au 25 septembre 2026

`android/app/google-services.json` contenait `"oauth_client": []` : aucune
empreinte de signature déclarée, donc le bouton Google échouait pour tout le
monde. **Une empreinte est maintenant enregistrée** pour `com.app.vybzz` :

```
E0:A3:66:FC:D9:CF:A8:0D:41:EF:ED:46:F5:CA:B9:2D:2A:6A:00:E6
```

**Reste à confirmer de quelle clé elle provient.** Play Console → Test et
versions → Intégrité de l'application affiche deux certificats :

| Certificat | Rôle |
|---|---|
| Clé de signature d'application | Celui de Google. **C'est le sien qui répare la connexion pour les téléchargements Play Store.** |
| Clé d'importation | Le tien, celui qui signe l'AAB avant envoi |

Si l'empreinte ci-dessus correspond au **second** et pas au premier, la
connexion Google reste cassée en production : ajouter alors celle du premier.

Empreinte de debug, à ajouter aussi (sinon la connexion échoue quand on teste
depuis Android Studio, ce qui fait croire à tort que le correctif ne marche
pas) :

```bash
keytool -J-Duser.language=en -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android | grep -iE "SHA1:"
```

Ne rien ajouter sur l'application `com.vybzzz.app` : c'est un doublon au nom
inversé, que rien n'utilise.

Après chaque ajout, retélécharger `google-services.json` (attendre une minute :
la propagation n'est pas instantanée) et vérifier :

```bash
python3 scripts/verifier-google-services.py android/app/google-services.json <SHA-1 attendues>
```

Détail complet : `docs/GOOGLE_SIGNIN.md`.

**Attention côté iOS.** Renseigner l'ID App Store dans Firebase a changé le
client OAuth iOS (`…gkcfj2vg…` → `…c5us844q…`). Le schéma d'URL de
`ios/Runner/Info.plist` a été réaligné (commit `1882bc1`), sinon la connexion
Google partait sans jamais revenir dans l'application. Toute modification
future dans la console Firebase impose de re-télécharger **les deux** fichiers
de configuration, pas seulement celui d'Android.

### 2.2 Clé de signature Android — BLOQUANT

`android/key.properties` et `upload-keystore.jks` sont absents du dossier de
travail. Sans eux, `flutter build appbundle --release` signe le bundle avec la
clé de **debug** — silencieusement — et Play Console le refuse à l'import.

Deux keystores existent ailleurs sur la machine :
`~/Desktop/JUin 2026/apple-lock/android/app/upload-keystore.jks`
`~/Downloads/Vybzzz/upload-keystore.jks`

Identifier le bon : son SHA-1 doit correspondre au **certificat de clé
d'importation** affiché dans Play Console > Intégrité de l'application. Le
copier ensuite dans `android/app/upload-keystore.jks`, et recréer
`android/key.properties` (fichier ignoré par git) :

```properties
storePassword=…
keyPassword=…
keyAlias=…
storeFile=upload-keystore.jks
```

Si aucun des deux ne correspond : Play Console > Intégrité de l'application >
« Demander la réinitialisation de la clé d'importation ». Google détient la
vraie clé de signature, l'application n'est donc pas perdue — compter un à
deux jours de délai.

Garder une sauvegarde du keystore ailleurs que sur un seul disque.

### 2.3 Manifeste de confidentialité iOS

`ios/Runner/PrivacyInfo.xcprivacy` est créé et référencé dans le projet Xcode.
Sans lui, App Store Connect renvoie l'avertissement ITMS-91053 puis refuse.

Vérification après `flutter build ipa` : le fichier doit être présent dans le
bundle. Si Xcode ne le voit pas, l'ajouter à la main (glisser le fichier dans le
groupe Runner, cocher la cible Runner).

### 2.4 Trafic réseau — à tester sur un appareil

`android:usesCleartextTraffic="true"` autorisait tout le trafic en HTTP non
chiffré, jetons de session compris. Remplacé par un fichier de configuration
réseau qui chiffre tout, sauf les adresses de développement local.

L'API, Mux et les images sont déjà en HTTPS. **Faire un live complet sur un
appareil réel avant de soumettre** : si le module de diffusion utilisait une
adresse en clair quelque part, c'est là que ça se verrait.

### 2.5 Fiche des stores

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

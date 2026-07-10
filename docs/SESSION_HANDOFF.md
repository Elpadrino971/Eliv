# VybzzZ — État du projet (handoff de session)

Document de reprise pragmatique. Ne revient pas sur ce qui est déjà validé —
juste l'essentiel pour continuer sans perdre de temps.

## 1. Cartographie du projet

| Élément | Où |
|---|---|
| Code (app + backend) | GitHub `elpadrino971/vybzzz-v12026` |
| **Branche active à utiliser** | **`version-couplee`** |
| Version Apple gelée (ne jamais toucher) | branche `apple-validated` + tag `apple-validated-v1` |
| VPS (backend + site) | `187.77.235.252` (SSH root) |
| Code backend sur le VPS | `/opt/vybzzz` (clone git, branche `version-couplee`) |
| Données persistantes (DB + uploads) | `/opt/vybzzz-data` (volume Docker, survit aux rebuilds) |
| Site marketing (Founders) | `https://vybzzz.online` → `/opt/vybzzz/site` |
| API + admin | `https://api.vybzzz.online` (admin sur `/admin`) |
| Backend d'Hammad (référence, séparé) | `vybzzz.fryandeatfood.com` — PHP/Laravel, sa propre DB, ne pas confondre avec le nôtre |

### Branches à ignorer / obsolètes
`main`, `version-finale`, `apple-dev-test` : étapes intermédiaires, superseded par `version-couplee`.

## 2. Dev local (Mac)

- Projet cloné dans **`~/Developer/vybzz-couplee`** (PAS sur le Bureau : iCloud pollue les fichiers de build → erreurs `detritus`/codesign. PAS sur le disque `jordan` : verrous de fichiers Xcode instables → `database is locked`, doublons `nanopb`)
- iPhone de test : « iPhone de JS », ID `00008130-00040C3634A2001C`
- **Toujours câble USB**, jamais Wi-Fi (le Wi-Fi lâche → « Lost connection to device »)
- **Désactiver le verrouillage auto** de l'iPhone pendant le dev (Réglages → Affichage → Verrouillage auto → Jamais), sinon iOS tue l'installation en cours (SIGKILL)
- Bundle IDs : `com.app.vybzz` (Release/App Store) et `com.app.vybzz.dev` (Debug, « VybzzZ Dev », coexiste avec l'App Store)
- Signature : Team « Jean-Sébastien LOUIS-GUSTAVE » (compte perso)

### Build qui marche à chaque fois
```bash
cd ~/Developer/vybzz-couplee
git pull origin version-couplee
flutter clean
xattr -cr /opt/homebrew/share/flutter
xattr -cr ~/.pub-cache
flutter pub get
cd ios && pod install && cd ..
flutter run -d 00008130-00040C3634A2001C
```

## 3. Redéploiement backend (VPS)

```bash
cd /opt/vybzzz
git pull origin version-couplee
cd backend
docker build -t vybzzz-backend .
docker stop vybzzz && docker rm vybzzz
docker run -d --name vybzzz --restart unless-stopped \
  -p 127.0.0.1:8002:8002 \
  -v /opt/vybzzz-data:/data \
  -v /opt/vybzzz-data/storage:/app/storage \
  -e JWT_SECRET=667278658e065d67fe555e27082deffe63573f5bb5ed46e2c998df42b1604c6c \
  -e VYBZZZ_DB=/data/vybzzz.sqlite \
  -e PUBLIC_BASE_URL=https://api.vybzzz.online \
  -e PORT=8002 \
  vybzzz-backend
```
⚠️ `JWT_SECRET` a été partagé en clair dans le chat — à changer un jour (régénérer + relancer le conteneur avec la nouvelle valeur).

## 4. Comptes de test

| Rôle | Identifiants | Où se connecter |
|---|---|---|
| Admin backend | `admin@vybzzz.com` / `admin123` | `api.vybzzz.online/admin` (site web, PAS l'app) |
| Artiste démo (Beyoncé) | `artist2@vybzzz.com` / `password` | Dans l'app iPhone |
| Autres artistes démo | `artist1@vybzzz.com` … `artist5@vybzzz.com` / `password` | Dans l'app |
| Fan démo | `demo@vybzzz.com` / `password` | Dans l'app |

⚠️ Mots de passe de démo (seed) à changer avant toute mise en prod réelle.

## 5. Ce qui a été construit/corrigé cette session

**Backend / Admin**
- Upload de photos (avatar, cover événement, image abonnement) — bug `EXDEV` corrigé (copyFile+unlink, pas rename)
- Colonne `artist_name` exposée/éditable dans l'admin (affichage prioritaire nom d'artiste)
- Concerts : fuseau horaire par événement (saisie locale → conversion UTC automatique), calendrier natif dans l'admin
- Concerts : fenêtre de replay/teaser de **60 jours** après la fin (coupe l'accès vidéo passé ce délai)
- **Bug majeur corrigé** : `/api/subscription/get` lisait une table morte (`settings`) au lieu de la vraie table `subscriptions` gérée par l'admin → écran Abonnements toujours vide
- Abonnements : ajout des colonnes `commission` (%) et `badge` (texte/ruban)
- Abonnements : un seul palier « Founder » actif affiché à la fois (le moins cher parmi les actifs), bascule **manuelle** en désactivant le palier courant dans l'admin (pas de vrai suivi des ventes pour l'instant)

**App Flutter**
- Bouton (`my_button.dart`) : débordement de texte corrigé (impactait le bouton paiement)
- Titres de section tronqués (« ARTISTES EN VEDE... ») corrigés (FittedBox)
- Carrousel accueil : support vidéo Mux avec fondu enchaîné (avant : image fixe uniquement)
- Carte « En direct » : image de secours, cache le badge genre vide, ajoute le compteur de spectateurs
- Avatars artistes : callback d'erreur mort remplacé par le widget image partagé (cache + fallback fonctionnels)
- OTP : minuteur buggé (sauts 45→22→55) réécrit avec un `Timer` unique
- Connexion : boutons Google/Apple sur iOS étaient décoratifs (aucune action) → branchés sur les vrais flux
- Cloche notification : n'avait aucune action → ouvre l'écran de notifications existant
- Abonnements : en-tête « VYBZZZ LIVE » + cartes plus lumineuses

## 6. Limites connues / TODO (honnête, non résolu)

- **RevenueCat** (Growth/Elite/Starter, vrais prix IAP) : système séparé de notre table `subscriptions`, aucun accès/connecteur RevenueCat disponible. Le projet RevenueCat est **partagé** avec l'app d'Hammad — modifier les prix là-bas impacterait aussi son app en prod.
- **Pas de vrai suivi des achats** : `/subscription/buy` est un stub qui n'enregistre rien → `seats_remaining` toujours égal à `seats_total`, bascule de palier Founder manuelle uniquement.
- **Pas d'entonnoir de conversion / capture d'intérêt prospects** dans l'app (existe seulement sur le site `vybzzz.online`).
- Badge « mode artiste » demandé par l'utilisateur — jamais clarifié (question posée, sans réponse).
- Bug de paiement Stripe mentionné une fois, jamais diagnostiqué (connecteur Stripe non autorisé).
- Test du **vrai live ZegoCloud** (artiste diffuse / spectateur regarde) : procédure donnée (laisser le champ Mux Playback ID vide sur l'event pour déclencher le vrai live et non un replay), mais pas confirmé testé de bout en bout.
- 404 `beyonce.jpg` / `burna.jpg` : images de démo (seed) qui n'existent pas vraiment sur le serveur — cosmétique, sans impact.
- Avertissements `objc[...] Class ... implemented in both ZegoExpressEngine/ZegoConnection` : doublons connus du SDK Zego, inoffensifs.

## 7. Sécurité — à faire à tête reposée

- Changer le mot de passe root du VPS (tapé par erreur dans le terminal une fois)
- Régénérer `JWT_SECRET` et le mot de passe admin (`admin123`)
- Ne jamais recoller de token/mot de passe dans le chat

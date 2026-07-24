# VybzzZ — Contexte projet (handoff)

> Ce fichier permet de reprendre le projet dans une **nouvelle conversation** avec
> tout le contexte. Dernière mise à jour : session **audit sécu + fix replay**.

---

## 0. ⚡ Session « béton » (audit sécu + fix replay) — À LIRE EN PREMIER

> Travail livré sur la branche `claude/test-concert-payments-replay-xr9mh0`
> (partie de `version-couplee`). À merger dans `version-couplee` puis redéployer
> le backend (cf. §2). **Ces changements sont backend-only, ne touchent pas au
> flux client** — pensés pour ne rien casser le jour d'une soumission.

### ✅ Corrigé dans cette session (backend)
1. **Crédit de points cassé (échec silencieux)** — le webhook RevenueCat crédite
   via `WHERE revenuecat_product_id = ?`, mais le seed des 5 packs laissait cette
   colonne NULL → achat réussi, argent pris, **0 point crédité**. Fix `db.js` :
   back-fill idempotent du mapping (`vybzz_points_100/500/1100/2400/6500`) sur les
   packs canoniques, sans jamais écraser une valeur admin.
   👉 **Après déploiement**, vérifier sur le VPS :
   `docker exec vybzzz node -e "const{db}=require('/app/src/db');console.log(db.prepare('SELECT id,name,points,revenuecat_product_id FROM packages').all())"`
2. **Replay jamais rattaché à l'event (bug P0)** — `createLiveStream` (Mux) posait
   `passthrough` seulement au niveau racine, jamais dans `new_asset_settings`. Mux
   ne recopie PAS le passthrough racine sur l'asset → le webhook `video.asset.ready`
   recevait `passthrough=null` → l'event n'était jamais mis à jour (le concert
   s'enregistre mais **le replay n'apparaît jamais**). Fix `services/mux.js` +
   fallback par `live_stream_id` dans `mux.routes.js`.
3. **Vol de points / billets gratuits / revenu artiste falsifié** — `event-gift`,
   `buy-ticket`, `event-comment`, `follow`, `unfollow` prenaient l'identité via
   `req.user?.id || b.user_id`. Sans token, un attaquant mettait n'importe quel
   `user_id` dans le corps → débit des points d'autrui, billet gratuit, wallet
   artiste gonflé. Fix `events.routes.js` : **identité = JWT uniquement** (le
   client loggé envoie déjà le Bearer partout, cf. `api_services.dart`).
4. **Fuite d'OTP + PII** — `serializeUser` exposait `otp_code` sur des routes
   publiques (`/get-user`, `/featured-artists`…). Fix `helpers.js` : OTP retiré.
5. **Secret JWT faible** — garde-fou au boot (`auth.js`) : **refus de démarrer en
   `NODE_ENV=production`** si `JWT_SECRET` manque/placeholder/<32c ; avertissement
   sinon. (Le `docker run` actuel ne fixe pas `NODE_ENV` → aucun risque de blocage ;
   pour activer l'enforcement, ajouter `-e NODE_ENV=production`.)
6. **Secret RevenueCat committé** — retiré de `backend/.env.example` (était en clair).

### 🔴 Actions REQUISES (ne peuvent pas être auto-corrigées sans risque)
- **Roter le secret webhook RevenueCat** : la valeur qui était dans `.env.example`
  (`bbfe95e4…fd58`) est compromise (historique git public). Dans RevenueCat →
  Integrations → Webhooks → régénérer le secret, puis mettre à jour
  `REVENUECAT_WEBHOOK_AUTH` dans `/opt/vybzzz/backend/.env` (les deux doivent
  matcher, sinon la recharge est rejetée). Purger l'historique git (`git filter-repo`).
- **Confirmer que `JWT_SECRET` (prod) est une vraie chaîne aléatoire ≥32c** avant
  d'activer `NODE_ENV=production`.
- **Vérif reçu serveur (durcissement futur)** : `buy-ticket` et le webhook RC
  créditent sur confiance (pas de validation du reçu Apple/RevenueCat côté serveur).
  OK pour tester, à durcir avant montée en charge.
- **OTP démo** : `otp_code` est codé en dur `'1234'` (sign-up + forget). Le flux
  reset-password ne vérifie pas de vrai 2e facteur. À remplacer par un OTP
  aléatoire + envoi SMS/email avant une vraie prod ouverte au public.
- **Webhooks fail-open si secret absent** (RevenueCat/Mux/Stripe : `if (secret)`).
  Non modifié ici pour ne pas risquer de casser la recharge/replay le jour J —
  à passer en fail-closed une fois les 3 secrets confirmés présents en prod.
- **Uploads non restreints** (`app.js` multer `upload.any()` sans limite de type/
  taille) : risque XSS stocké (`.html`/`.svg` servis) + DoS disque. À whitelister.

### 📱 Guide de test paiements en sandbox (device requis — À FAIRE par toi)
Pré-requis : build `flutter run --release -d "iPhone de JS"` (bundle `com.app.vybzz`),
connecté avec un **compte sandbox testeur** App Store, en tant que **fan** (pas
l'artiste qui a créé le concert). Produits IAP en état « Prêt à soumettre ».
1. **Billet** : ouvrir le concert 49,99 € → acheter → pop-up sandbox → succès.
   Vérifier l'accès au concert. Côté serveur, une ligne `tickets` doit apparaître
   (`price_paid=49.99`). Le billet **ne dépend pas** du webhook.
2. **Recharge** : portefeuille → acheter un pack (ex. 4,99 € / 500 pts) → succès.
   Le crédit passe par le **webhook RevenueCat** (asynchrone, quelques secondes).
   Vérifier `users.points` augmenté. Logs : `docker logs vybzzz --tail 30` doit
   montrer `[revenuecat webhook] +500 points -> user X`.
   ⚠️ Si 0 point : vérifier (a) le mapping packs (§0.1), (b) que RevenueCat envoie
   bien le header `Authorization: Bearer <REVENUECAT_WEBHOOK_AUTH>`.
3. **Tip** : envoyer un cadeau pendant un live → points débités, wallet artiste crédité.

### 🎥 Guide de test replay (live réel — À FAIRE par toi)
Après le fix P0 + déploiement :
1. Lancer un live. Sur le **dashboard Mux**, confirmer que le live stream passe
   **`active`** (⚠️ `addPublishCdnUrl` renvoyant `errorCode 0` ne prouve PAS que
   la vidéo arrive à Mux — c'est le point le plus à risque, cf. §0 « à vérifier »).
2. Admin « Lives en direct » → le lecteur HLS doit afficher la vidéo pendant le live.
3. Arrêter le live → attendre l'asset Mux → le **replay** doit apparaître dans
   l'app (l'event reçoit `mux_playback_id` + `video_reel` via le webhook).
- **À vérifier côté ZegoCloud** (non confirmable par le code) : que la republication
  CDN tierce (`addPublishCdnUrl`) est **activée** sur le projet Zego, et que le
  `streamId` relayé (`${eventId}_${userId}_main`) correspond bien au flux réellement
  publié par le UIKit (à confirmer dans les logs Zego pendant le live).

### 🐛 Autres findings replay (mineurs, non bloquants — voir historique)
- Replay VOD affiché avec le badge « EN DIRECT » et sans boucle (`live_router.dart`
  base `isLive` sur « a un reel Mux » au lieu de `event.status=='live'`).
- Shorts : `video.asset.ready kind:'shorts'` non géré par le webhook (playback id
  jamais sauvé) — hors chemin concert.
- Deux sources d'expiration du replay divergentes (`replay_expires_at` en base vs
  recalcul dans `serializeEvent`) — à unifier.

---

## 0bis. 🗺️ Roadmap post-soumission (chantiers identifiés, non bloquants pour la review)

> Priorisés. Aucun n'affecte le binaire soumis à Apple sauf mention « app ».
> Détails/ancrages issus de l'audit de la session « béton ».

### P1 — Split des commissions AUTOMATIQUE (backend only, moyen)
- **État actuel** : aucun split. L'artiste touche **100 %** des billets et des cadeaux.
  - Billet (`events.routes.js` /buy-ticket) : ne crédite pas le wallet artiste ;
    le revenu est un `SUM(price_paid)` lu au dashboard (à 100 %).
  - Cadeau (/event-gift) : crédite **la totalité** des points au wallet artiste.
- **Le taux existe** : `subscriptions.commission` = part artiste (Starter 50 /
  Growth 60 / Elite 70 / Founder 60). Souvent `NULL` (seed sans valeur) → prévoir
  un défaut **60**. Résolution : `users → user_subscriptions → subscriptions.commission`
  (JOIN déjà présent dans `helpers.js`).
- **À faire** : resolver `resolveArtistCommission(artistId)` + l'appliquer aux 2
  points de crédit (billet + cadeau, déjà dans des transactions atomiques) +
  table `platform_earnings` (part plateforme) + **snapshot du taux** par vente
  (colonnes `tickets.commission_rate/artist_share`) pour ne pas re-tarifer le
  passé. **Piège** : le revenu billet est un `SUM(price_paid)` lu à ~5 endroits
  (`misc.routes.js:379`, `admin.routes.js:84/426/681/693`) → choisir un modèle
  (crédit-à-la-vente vs calcul-à-la-lecture) et aligner TOUS les points de lecture,
  sinon double comptage.
- **Motivation** (fondateur) : compta/impôts justes — ne pas apparaître avec un CA
  de « milliers d'€ » alors que la part réelle plateforme = quelques centaines.
- **Urgence** : à activer **avant la 1ʳᵉ vente réelle** (aucune vente pendant la
  review Apple → largement le temps). Backend-only → déployable à chaud.

### P2 — Bug perte de données : collision `events.video_reel`
- La colonne sert **à la fois** au teaser vidéo uploadé ET à l'URL du replay Mux.
  Le webhook Mux (`mux.routes.js`) **écrase** le teaser par l'URL HLS du replay, et
  `replayExpired` (`helpers.js`) le met à `null` à l'expiration → **le teaser
  uploadé est détruit**.
- **Fix** : colonne dédiée `promo_video` (ou `teaser_url`) séparée du replay ;
  webhook + `replayExpired` ne touchent QUE le replay ; exposer les deux dans
  `serializeEvent` + `event_model.dart`. (migration `db.js` + `events.routes.js`
  + `mux.routes.js` + `helpers.js` + modèle Dart).

### P3 — Vidéo uploadée dans « Pour toi » (app + backend, petit-moyen)
- **Décision produit** : la vidéo uploadée à la création d'event va dans le feed
  **« Pour toi »** (avec lien vers le concert pour inciter à l'achat) ; on
  **abandonne** le teaser autoplay dans le scroll des concerts (plus simple, et
  évite le bug P2).
- **État** : « Pour toi » (`vybz_live_screen.dart` + `event_controller.dart:63-90`)
  lit surtout les `feed_clips` admin ; le teaser d'event n'apparaît qu'en fallback
  supprimé dès qu'un clip admin existe. Le seul endroit qui joue déjà le teaser =
  `HomeBannerCard` (events `is_banner`, autoplay/mute/loop) → template réutilisable.
- **À faire** : à la création d'event, ranger la vidéo dans le feed « Pour toi »
  (idéalement via `feed_clips` avec `event_id` → dodge la collision P2), et rendre
  l'item cliquable vers le concert. Infra vidéo déjà là (`video_player`).

### Autres finitions (cf. §6)
- Payout/retrait artiste (aujourd'hui des stubs) — à brancher avec le split P1.
- Android (produits Google Play + clé RevenueCat Google).
- Vignettes cadeaux 404.

---

## 1. C'est quoi VybzzZ

App mobile de **concerts live** : des artistes diffusent des concerts en direct,
les fans achètent un **billet** pour y accéder, envoient des **tips/cadeaux**
pendant le live, et peuvent revoir le concert en **replay** après.

- **App** : Flutter (dossier `lib/`), iOS d'abord (Android prévu ensuite).
- **Backend** : Node.js / Express + SQLite (dossier `backend/`).
- **Branche de dev** : **`version-couplee`** (tout se commit/push dessus).

---

## 2. Architecture & déploiement

### Backend (VPS Hostinger)
- IP : `187.77.235.252` (Ubuntu 24.04), accès `ssh root@187.77.235.252`.
- Domaine API : `https://api.vybzzz.online` (nginx + Let's Encrypt HTTPS).
- Tourne en **Docker** (`/opt/vybzzz`), reverse-proxy **nginx**.
- Base SQLite persistée via volume `-v /opt/vybzzz-data:/data`.
- Uploads (images/covers) persistés via `-v /opt/vybzzz-storage:/app/storage`.
- `.env` VPS : `/opt/vybzzz/backend/.env` (secrets — NE PAS coller dans le chat).

**Commande de redéploiement complète** (après un push) :
```bash
cd /opt/vybzzz && git pull origin version-couplee
cd backend && docker build -t vybzzz-backend .
docker stop vybzzz && docker rm vybzzz
docker run -d --name vybzzz --restart always -p 127.0.0.1:8002:8002 \
  --env-file /opt/vybzzz/backend/.env -e VYBZZZ_DB=/data/vybzzz.sqlite \
  -v /opt/vybzzz-data:/data -v /opt/vybzzz-storage:/app/storage vybzzz-backend
docker logs vybzzz --tail 15
```
⚠️ Toujours `stop`/`rm`/`run` (pas `restart`) pour recharger le `.env`.

### App (Mac de l'utilisateur)
- Repo local : `~/Downloads/Vybzzz-V12026-version-couplee`.
- Lancer : `flutter run --release -d "iPhone de JS"` (device physique).
- **Bundle IDs** : `com.app.vybzz` (Release/prod) vs `com.app.vybzz.dev` (Debug).
  ⚠️ Les achats in-app (IAP) ne fonctionnent qu'en **`com.app.vybzz`** →
  **toujours tester les paiements en `--release`**.
- Une build **Debug** (`flutter run` simple) ne se relance pas seule sur iPhone
  (normal) ; **`--release`** = app autonome.

---

## 3. Intégrations externes

| Service | Rôle | État |
|---------|------|------|
| **ZegoCloud** | Live streaming (host + audience) | ✅ Fonctionne (testé sur iPhone). Token04 généré côté serveur (`backend/src/services/zego.js`), jamais d'appSign dans l'app. AppID `266313543`. |
| **Mux** | Enregistrement / replay des concerts | Backend prêt (`services/mux.js`, webhooks). Relais Zego→Mux (`addPublishCdnUrl`) branché mais **à valider en live réel**. |
| **RevenueCat** | Achats in-app (IAP) iOS/Android | Projet `projc53bb4b7`. Clé Apple SDK `appl_KIba…` (publique) dans `lib/Global/global.dart`. P8 App Store Connect valide. |
| **Firebase** | Auth (Google/Apple) + Storage clips | Projet `vybzzz-app` (compte du client). Service account base64 dans `.env`. |
| **Stripe** | Abonnements artistes (web uniquement) | Compte en **LIVE** mais **0 transaction** (jamais testé). Clé backend = `rk_live` (restreinte — vérifier droit "Checkout Sessions: Write"). |
| **Anthropic** | Génération de descriptions (admin) | Clé dans `.env`. |

---

## 4. Modèle de monétisation (HYBRIDE)

**Décision validée** : ratio **1 € = 100 points**.

### Billets de concert = ACHAT IAP DIRECT
- Prix de 19,99 € à 149,99 € par **paliers**.
- Produits App Store : `ticket_19`, `ticket_29`, `ticket_39`, `ticket_49`,
  `ticket_59`, `ticket_79`, `ticket_99`, `ticket_129`, `ticket_149`
  (tous **Consommables**, créés dans App Store Connect).
- L'artiste choisit un palier dans un **menu déroulant** à la création d'event.
- Le prix `49.99` → mappe le produit `ticket_49` (`ticket_${prix.floor()}`).
- Flux : app achète le produit via RevenueCat → au succès, appelle
  `POST /api/buy-ticket` (qui **enregistre l'accès**, ne déduit PAS de points).

### Tips / cadeaux = POINTS (monnaie interne)
- Packs de recharge (Consommables App Store) :
  `vybzz_points_100` (0,99€/100pts), `vybzz_points_500` (4,99€/500pts),
  `vybzz_points_1100` (9,99€/1100pts, +10%, "Populaire"),
  `vybzz_points_2400` (19,99€/2400pts, +20%),
  `vybzz_points_6500` (49,99€/6500pts, +30%, "Meilleure valeur").
- Flux recharge : app achète le pack via RevenueCat → **webhook RevenueCat**
  (`POST /api/revenuecat/webhook`) crédite les points côté serveur (dédup via
  table `rc_processed_events`). Le mapping pack→produit est dans la colonne
  `packages.revenuecat_product_id`.
- Envoi d'un cadeau (`POST /api/event-gift`) : déduit les points du fan,
  crédite le portefeuille de l'artiste (transaction atomique).

### Code clé (app)
- `SubscriptionController.purchaseByProductId(productId)` : achète n'importe quel
  produit IAP (billet ou pack) — cherche d'abord dans les offerings, sinon
  `Purchases.getProducts([id], productCategory: nonSubscription)` +
  `Purchases.purchase(PurchaseParams.storeProduct(...))`. (purchases_flutter 10.1.1)

---

## 5. Ce qui FONCTIONNE (validé)

- ✅ Live streaming complet sur vrai iPhone (caméra, micro, chat, promo).
- ✅ Économie de points réelle (déduction billets/cadeaux, crédit artiste).
- ✅ Animations de tips (8 vidéos `assets/animations/*.mp4`) : blend "screen"
  (fond noir transparent, ne masque pas l'artiste), multiples → chips ×N.
- ✅ Modération admin : page "🔴 Lives en direct" (`/admin`), lecteur HLS.
- ✅ Replay : contrôles on/off + durée (7/14/30/60j) sur création event + admin.
- ✅ Avatars : URLs absolues (`profileUrl()` dans `helpers.js`).
- ✅ Fuseaux horaires : heure saisie en local artiste → stockée UTC → affichée
  dans le fuseau de chaque spectateur (`AppDate` + `.toLocal()`).
- ✅ Badge live doré pulsant, minuteur de durée, boutons hôte (vider écran /
  couper chat).

---

## 6. Ce qu'il RESTE pour finir cette version

### Paiements (en cours de test)
- [ ] **Tester l'achat d'un billet** en sandbox (build `--release`, compte
  sandbox testeur, connecté en **fan** — un artiste n'achète pas son concert).
- [ ] **Tester la recharge de points** en sandbox → vérifier que le webhook
  RevenueCat crédite bien le solde.
- [ ] Vérifier que le **webhook RevenueCat** pointe vers
  `https://api.vybzzz.online/api/revenuecat/webhook` (Integrations → Webhooks).
- [ ] Les produits IAP sont en état **"Prêt à soumettre"** (métadonnées + prix +
  capture de vérif) — sinon pas testables en sandbox.
- [ ] Vérifier la clé Stripe `rk_live` : droit **Checkout Sessions: Write**.

### Replay (à valider en live réel)
- [ ] Confirmer le relais **Zego → Mux** (`addPublishCdnUrl`) : voir la vidéo
  dans l'admin "Lives en direct" pendant un live + le replay après.
- [ ] Vérifier le **webhook Mux** (dashboard Mux → `…/api/mux/webhook`).

### Divers / à planifier
- [ ] **Retrait artiste (payout)** : encore un stub. Définir le taux de
  conversion points→€ (ex. 1 pt = 0,7 c) + brancher un vrai virement.
- [ ] **Android** : produits Google Play + clé RevenueCat Google (commentée).
- [ ] **Son du live** : confirmer avec un 2e appareil spectateur.
- [ ] **Multilingue / speech-to-speech** : reporté (commencer par sous-titres
  traduits plutôt que voix — cf. discussion).
- [ ] Vignettes de cadeaux (sélecteur) : 404 sur `giftImages/*.png` (cosmétique).
- [ ] Symbole `$` restant dans quelques labels (ex. "Standard ($)") → passer €.

---

## 7. Gotchas appris (pièges à connaître)

- **IAP = lié au Bundle ID** : tester en `com.app.vybzz` (release), pas `.dev`.
- **JWT_SECRET** : un redéploiement qui change le secret invalide les sessions
  ("Invalid token") → se déconnecter/reconnecter dans l'app.
- **Upload vidéo** : nginx doit avoir `client_max_body_size 2000M` +
  `proxy_request_buffering off` + timeouts 600s (déjà configuré).
- **Storage non persistant** : bien monter `-v /opt/vybzzz-storage:/app/storage`
  sinon les uploads sont effacés à chaque redéploiement.
- **RevenueCat SDK** : `purchases_flutter 10.1.1` (API `PurchaseParams`).
- **Comptes de test** (backend seed) : `artist2@vybzzz.com` = Beyoncé (id 4),
  `fan1@vybzzz.com` (id 8), compte perso `js210@hotmail.com` (id 22).
  Créditer des points de test :
  `docker exec vybzzz node -e "const{db}=require('/app/src/db');db.prepare('UPDATE users SET points=? WHERE id=?').run('2000',4)"`
- **Sécurité** : ne JAMAIS coller de secrets (clés, `.env`) dans le chat.

---

## 8. Structure code utile

- `backend/src/routes/events.routes.js` — events, buy-ticket, event-gift.
- `backend/src/routes/misc.routes.js` — zego-token, recording start/stop,
  packages/list, artist stats.
- `backend/src/routes/revenuecat.routes.js` — webhook IAP (crédit points).
- `backend/src/routes/mux.routes.js` — webhook Mux (replay).
- `backend/src/routes/admin.routes.js` + `backend/public/admin/` — dashboard admin.
- `backend/src/helpers.js` — serializeEvent/User (+ `profileUrl`).
- `backend/src/db.js` — schéma + migrations + seed packs par défaut.
- `lib/ZegoCloud/` — écrans live (start/join/pre_stream, controller, gifts).
- `lib/Controllers/subscription_controller.dart` — achats IAP RevenueCat.
- `lib/BottomBar/screens/homeScreen/check_out_screen.dart` — achat billet.
- `lib/BottomBar/screens/profile/user_wallet.dart` — recharge points.
- `lib/artist_bottom_bar/screen/Studio/artist_create_event.dart` — création event.
- `lib/Global/app_date.dart` — conversion fuseaux (UTC ↔ local).
- `DEPLOY_HOSTINGER.md` — guide de déploiement détaillé.

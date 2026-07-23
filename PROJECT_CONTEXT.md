# VybzzZ — Contexte projet (handoff)

> Ce fichier permet de reprendre le projet dans une **nouvelle conversation** avec
> tout le contexte. Dernière mise à jour : session monétisation / paiements.

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

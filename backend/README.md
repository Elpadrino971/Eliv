# VYBZZZ — Backend (copie autonome)

Backend de référence **Node.js + Express + SQLite** qui **réplique le contrat d'API**
de l'app Flutter (le serveur d'Hammad sur `vybzzz.fryandeatfood.com`) et le
**complète** avec les features de `docs/BACKEND_CHANGES.md` (referral, ghost pass,
event access, event pulse, shorts Mux).

> ⚠️ Ce backend **ne remplace pas et ne touche pas** au serveur d'Hammad.
> C'est une **copie qu'on possède et qu'on finit**, pour ne pas dépendre/bloquer son travail.
> Même format de réponses (`{status, data}`, auth `Bearer`, erreurs `errors` par champ)
> → l'app fonctionne dessus **sans modification**, juste en changeant `APIs.mainIP`.

---

## Démarrage (sur ton Mac)

```bash
cd backend
npm install          # installe les dépendances
npm start            # démarre + seed automatique au 1er lancement
```

Le serveur écoute sur `http://localhost:8002`. Au premier démarrage, la base se
remplit toute seule (5 artistes, 6 events dont 1 live + 2 bannières, gifts, etc.).

Commandes utiles :
```bash
npm run seed     # (re)remplir les données de démo
npm run reset    # vider puis re-seeder (repart de zéro)
npm run dev      # démarrage avec rechargement auto (node --watch)
```

**Compte de démo (app) :** `demo@vybzzz.com` / `password`

## Dashboard admin web

Une fois le serveur lancé, ouvre **`http://localhost:8002/admin`** dans un navigateur.

**Compte admin :** `admin@vybzzz.com` / `admin123`

Thème bleu nuit + or, sections : Dashboard (stats), Users (tabs + status + delete),
Genres (CRUD), User Genre, Events, Packages, Subscription, Abusive (CRUD), Reviews,
Withdrawals (approve/reject), Transactions, Reports, Contact Leads, FAQS (CRUD),
CMS (édition), Profile. API sous `/api/admin/*` (auth Bearer, role=admin).

---

## Brancher l'app dessus (`APIs.mainIP`)

Dans `lib/Global/api.dart` :

```dart
// static const String mainIP = 'https://vybzzz.fryandeatfood.com'; // Hammad (live)
static const String mainIP = 'http://192.168.X.X:8002';            // notre backend
```

- **Simulateur iOS / Mac** : `http://localhost:8002` fonctionne.
- **iPhone physique** : remplace par **l'IP locale de ton Mac** (ex. `http://192.168.1.42:8002`).
  Trouve-la avec `ipconfig getifaddr en0`. Le Mac et l'iPhone doivent être sur le **même Wi-Fi**.
- iOS bloque le HTTP non-sécurisé : pour le dev local, l'`Info.plist` doit autoriser
  l'« App Transport Security » en local (clé `NSAllowsLocalNetworking` / `NSAllowsArbitraryLoads`).

---

## Ce qui est implémenté (réplique de l'API existante)

| Domaine | Endpoints |
|---|---|
| **Auth** | `login`, `sign-up`, `social-login`, `verify`, `forget`, `reset-password`, `update-password`, `get-user`, `update-profile`, `delete-account` |
| **Events** | `events` (filtres status/day/genre), `banner-events`, `featured-artists`, `artist/:id/events`, `buy-ticket`, `user-event-history`, `event-comment`, `event-logs`, `events/update/:id`, `report-event` |
| **Gifts** | `gifts`, `event-gift` |
| **Follow** | `follow`, `unfollow`, `followers/:id`, `following` |
| **Divers** | `genres`, `get-abusive-words`, `settings/get-settings`, `settings/get-management`, `subscription/*`, `packages/*`, `get-transactions`, `support/*`, `withdraw/*`, `get-artist-statistics` |

## Nouvelles features (docs/BACKEND_CHANGES.md) — ce qui manquait

| Feature | Endpoints |
|---|---|
| Contrôle d'accès live | `GET /event/:id/access` |
| Referral (artiste & user) | `referral/generate`, `referral/me`, `referral/redeem` |
| Ghost pass (VIP temporaire) | `ghost-pass/grant`, `ghost-pass/me` |
| Event Pulse (analytics agrégées) | `event/:id/signal`, `event/:id/pulse` |
| Shorts UGC (Mux Direct Upload) | `shorts/create-upload` |

---

## Reste à faire (pour la prod)

1. **Secrets côté serveur** (jamais dans l'app) via variables d'env :
   `JWT_SECRET`, `MUX_TOKEN_ID`/`MUX_TOKEN_SECRET`, clés Stripe, Firebase Admin, Zego.
2. **Mux réel** : `shorts/create-upload` doit appeler `POST https://api.mux.com/video/v1/uploads`
   et renvoyer l'`upload_url`. Idem signed playback IDs par event.
3. **Stripe** : webhooks d'abonnement (voir `docs/STRIPE_HYBRID_SETUP.md`).
4. **Stockage fichiers** : brancher un vrai stockage (S3/Cloud) pour covers/profils/vidéos.
   En dev, les fichiers sont servis depuis `backend/storage/{covers,profiles,videos,gifts}`.
5. **OTP réel** (SMS/email) — actuellement code fixe `1234` en démo.
6. **Migration des données** depuis le serveur d'Hammad si on bascule pour de vrai.
7. **DB de prod** : passer de SQLite à Postgres/MySQL (le schéma est standard).

---

## Stack & structure

```
backend/
  src/
    server.js          # entrée (démarre + seed si base vide)
    app.js             # Express (CORS, json/urlencoded/multipart, static, routes)
    db.js              # SQLite + schéma (mirroir des modèles Flutter)
    auth.js            # JWT Bearer + bcrypt
    helpers.js         # sérialiseurs au format EXACT attendu par l'app
    seed.js            # données de démo (artistes, events, Mux, gifts)
    routes/
      auth.routes.js
      events.routes.js
      misc.routes.js
```

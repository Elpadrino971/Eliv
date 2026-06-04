# VybzzZ — Shorts UGC (uploads utilisateurs via Mux Direct Upload)

Objectif : laisser les utilisateurs poster des **shorts verticaux** → ils
apparaissent dans le feed **« Pour toi »** (déjà branché Mux). Fait vivre
VybzzZ **24/7, hors des lives**.

## ✅ Déjà fait côté APP
- `lib/BottomBar/screens/LiveScreen/create_short_screen.dart` — écran « Créer un
  short » : choix vidéo (`image_picker`) → demande une URL d'upload au backend →
  **PUT** la vidéo sur Mux. Gère proprement le cas « backend pas prêt ».
- Bouton **+** (or) toujours visible sur le feed « Pour toi ».
- `APIs.createShortUploadAPI` = `/api/shorts/create-upload` (le « trou » backend).

## 🔧 À FAIRE — Backend (Laravel) + Mux
### 1. `POST /api/shorts/create-upload` (auth user)
Crée un **Direct Upload** Mux et renvoie l'URL :
```
POST https://api.mux.com/video/v1/uploads      (Basic auth: MUX_TOKEN_ID:SECRET)
{
  "cors_origin": "*",
  "new_asset_settings": { "playback_policy": ["public"] }
}
→ réponse Mux: { "data": { "id": "<upload_id>", "url": "<upload_url>" } }
```
Renvoyer à l'app : `{ "upload_url": "<upload_url>", "upload_id": "<upload_id>" }`
(stocker `upload_id` ↔ user pour relier l'asset plus tard).

### 2. Webhook Mux  `POST /api/mux/webhook`
- `video.asset.ready` → récupérer `playback_ids[0].id` + l'`upload_id`/`asset_id`
  → enregistrer un **short** (playback_id, user_id, created_at, status=approved).
- Vérifier la **signature** du webhook (`Mux-Signature`).

### 3. `GET /api/shorts`  → liste pour le feed
Renvoyer `[{ "playback_id": "...", "artist_name": "...", ... }]`.
→ Côté app, on remplacera la **liste de démo** (`muxDemoPlaybackIds`) par cette
liste : 1 ligne à changer dans `EventController.onPageChanged` / `reelUrlFor`.

### 4. Modération (important pour de l'UGC)
- Signaler / retirer un short (bouton report → backend masque le short).
- (option) revue avant publication, ou `mux` + détection.

## 💸 / ⚠️
- Coût Mux à l'usage (encodage + stockage + delivery).
- Vérifier les règles stores pour l'UGC (modération obligatoire côté Apple).
- Limiter durée/taille (ex. ≤ 60 s, vertical) côté backend (paramètres Mux).

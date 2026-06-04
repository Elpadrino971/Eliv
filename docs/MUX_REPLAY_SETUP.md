# VybzzZ — Replays via Mux (HLS VOD)

> Architecture : **Zego = direct temps réel**, **Mux = stockage/encodage/replay
> + reels VOD**, en parallèle (Zego republie le flux vers Mux en RTMP).
> L'app ne stocke **aucun secret Mux** — elle ne fait que LIRE le HLS public.

## ✅ Déjà fait côté APP (branche `claude/magical-pasteur-zX3IV`)
- `lib/Global/mux.dart` — helpers (HLS url, thumbnail, signed url).
- `lib/widgets/replay_player_screen.dart` — lecteur HLS plein écran (scrub, X).
- `lib/Global/api.dart` → `muxDemoPlaybackId` (le seul "trou" à remplir).
- Fiche event (`future_screen`) : bouton **▶ replay** (or) qui apparaît dès
  qu'un Playback ID est renseigné.

## 🎬 Voir un replay Mux DANS l'app, aujourd'hui (3 min)
1. Récupère un **Playback ID** d'un de tes assets Mux :
   - Dashboard Mux → **Assets** → un asset → **Playback ID** (public), **ou**
   - via le script : `export MUX_TOKEN_ID=… ; export MUX_TOKEN_SECRET=… ; ./scripts/mux.sh list`
   - (créer un asset depuis une vidéo : `./scripts/mux.sh create "https://…/video.mp4"`)
2. Colle-le dans `lib/Global/api.dart` :
   ```dart
   static const String muxDemoPlaybackId = 'TON_PLAYBACK_ID';
   ```
3. `flutter run` → ouvre une fiche event → bouton **▶** → **le replay Mux joue**. 🎉

> Le Playback ID est **public** (c'est ce qui sert à diffuser le HLS). Tu peux
> me le donner sans risque — contrairement à `MUX_TOKEN_SECRET` (jamais ici).

## 🔧 Pour la PROD (ton dev) — replay par event + fenêtre 7/60j
1. **Relais Zego → Mux** : activer le *republish RTMP* de Zego vers l'**ingest
   RTMP de Mux Live** → Mux enregistre le live automatiquement.
2. **Webhook Mux** (`video.asset.ready`) → stocker le `playback_id` sur l'event
   (`replay_playback_id`) côté backend Laravel.
3. **Fenêtre d'accès 7/60j** : utiliser des **playback policy "signed"** →
   le backend génère un **JWT** d'accès valable X jours → l'app appelle
   `Mux.signedHlsUrl(playbackId, token)`. Au-delà de la fenêtre, plus de token
   = plus d'accès.
4. **Modèle app** : ajouter `replay_playback_id` (+ `replay_token`) à l'Event
   model → le bouton replay utilisera le vrai champ au lieu de `muxDemoPlaybackId`.

## 💸 Coût
Mux = facturé à l'usage (encodage + stockage + delivery). Négligeable au
lancement, à surveiller à l'échelle. Zego (RTC) + Mux tournent en parallèle =
on paie les deux pendant le live.

# VybzzZ — Live CONCERT PRO (flux régie → Mux Live → app)

Brancher le **flux grand écran** du concert (IMAG multi-cam mixé) dans l'app,
en qualité broadcast et à grande échelle. **C'est Mux Live, pas Zego.**

## Chaîne technique
```
Régie concert (SDI/HDMI, multi-cam mixé, = ce qui passe sur les écrans géants)
  → Encodeur (Teradek / boîtier SRT, ou OBS / vMix sur laptop)
  → push RTMP ou SRT
  → MUX LIVE (ingest)            [backend crée le live stream]
  → HLS adaptatif → l'app (lecteur HLS déjà en place) + REPLAY auto
```

## ✅ App — déjà prêt
- `ReplayPlayerScreen(playbackId: ..., isLive: true)` joue un **HLS live**
  (pas de boucle, badge **EN DIRECT**). Même lecteur que le replay.
- `APIs.muxLivePlaybackId` = le « trou » (playback id du live pro). En prod :
  champ `mux_live_playback_id` par event (backend).

## 🔧 Backend (dev)
1. **Créer un Live Stream Mux** (token secret, backend uniquement) :
   ```
   POST https://api.mux.com/video/v1/live-streams
   { "playback_policy": ["public"], "new_asset_settings": { "playback_policy": ["public"] } }
   → { data: { id, stream_key, playback_ids:[{id}] } }
   ```
   - `stream_key` → donné à la **régie/encodeur** (à pousser sur `rtmps://global-live.mux.com:443/app` ou SRT).
   - `playback_ids[0].id` → stocké sur l'event (`mux_live_playback_id`), renvoyé à l'app.
2. Webhook `video.live_stream.active` / `.idle` → marquer l'event live/offline.
3. À la fin → Mux a **enregistré** automatiquement = le **replay** est dispo (même pipeline que `MUX_REPLAY_SETUP.md`).

## ⏱️ Latence & interaction
- HLS Mux ≈ 5-30 s (broadcast). OK pour regarder un concert.
- L'**interaction** (chat/gifts/❤️) se superpose via la couche temps réel
  (Zego signaling / backend), **par-dessus** la vidéo Mux.

## 🔐 Clés Mux
- `MUX_TOKEN_ID` / `MUX_TOKEN_SECRET` : **backend uniquement** (ou variables
  d'environnement pour des scripts de test). **Jamais dans l'app / le repo.**
- L'app ne manipule que des **playback ids publics**.

## 2 modes de live VybzzZ (récap)
| Mode | Techno | Pour |
|---|---|---|
| Mobile interactif | Zego (déjà) | artiste à la main, gifts <1s, soirée match |
| **Concert PRO** | **Mux Live** | vrais shows (régie grand écran), scale + replay |

# API de publication VybzzZ (contrat machine-à-machine)

Permet à un service externe (ex. **Atelier**) de **publier des clips dans le feed
VybzzZ** et d'en lire les stats. Montée sous `/api/v1`. Base de production :
`https://api.vybzzz.online/api/v1`.

## Authentification

En-tête **`X-API-Key: <clé>`** sur chaque requête.
La clé se génère dans l'admin VybzzZ → **« API / Atelier » → « Générer une clé »**
(la clé complète n'est affichée qu'une fois).

## 1. Publier — `POST /publish`

Corps JSON :

| Champ | Requis | Détail |
|---|---|---|
| `title` | non | Titre du clip |
| `feed` | non | `for_you` (défaut) ou `clips` |
| `video_url` | * | URL **publique** du média — VybzzZ l'ingère dans Mux |
| `mux_playback_id` | * | Alternative : un Playback ID Mux déjà prêt |
| `artist_id` | non | Rattache le clip à un artiste (apparaît sur sa fiche) |
| `external_ref` | non | Ton id côté Atelier — **idempotent** (rejouable sans doublon) |

`*` : fournir **`video_url` OU `mux_playback_id`**.

```bash
curl -X POST https://api.vybzzz.online/api/v1/publish \
  -H "X-API-Key: vybz_xxx" -H "Content-Type: application/json" \
  -d '{"title":"Session live NOVA","feed":"clips","video_url":"https://cdn.exemple/clip.mp4","external_ref":"piece_4821"}'
```

Réponse :

```json
{ "status": "success",
  "data": { "id": 42, "external_ref": "piece_4821", "state": "processing",
            "feed": "clips", "title": "Session live NOVA",
            "mux_playback_id": null, "hls_url": null, "thumbnail_url": null,
            "active": true, "created_at": "2026-09-03 23:40:00" } }
```

`state` : `processing` (ingestion Mux en cours), `ready` (diffusable), `errored`.

## 2. Statut — `GET /publications/:id`

```bash
curl https://api.vybzzz.online/api/v1/publications/42 -H "X-API-Key: vybz_xxx"
```

```json
{ "status": "success",
  "data": { "id": 42, "state": "ready",
            "mux_playback_id": "abc123", "hls_url": "https://stream.mux.com/abc123.m3u8",
            "thumbnail_url": "https://image.mux.com/abc123/thumbnail.jpg", "active": true } }
```

Une publication n'est visible **que par la clé qui l'a créée**.

## 3. Statistiques — `GET /publications/:id/stats`

```bash
curl https://api.vybzzz.online/api/v1/publications/42/stats -H "X-API-Key: vybz_xxx"
```

```json
{ "status": "success", "data": { "views": 128, "likes": 0 } }
```

- `views` : impressions du clip dans le feed (comptées à chaque service du clip).
- `likes` : à instrumenter côté app (0 pour l'instant).

## Correspondance avec `publishers/vybzzz.py` (Atelier)

| Méthode publisher | Appel VybzzZ |
|---|---|
| `authenticate` | présence d'une `X-API-Key` valide |
| `publish` | `POST /publish` → `id`, `state` |
| `status` | `GET /publications/:id` → `state`, `hls_url` |
| `stats` | `GET /publications/:id/stats` → `views`, `likes` |

## Notes d'intégration

- **Format** : vidéo **16:9** (VybzzZ est paysage), 15–45 s pour un clip de feed.
- **Idempotence** : réutiliser `external_ref` renvoie la publication existante
  plutôt que d'en créer une nouvelle.
- **Ingestion par URL** : l'URL doit être **publiquement accessible** le temps que
  Mux télécharge le média.
- **Erreurs** : `401` (clé absente/invalide), `422` (média manquant), `502`
  (échec Mux), `503` (Mux non configuré côté serveur).

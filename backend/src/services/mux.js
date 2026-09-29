'use strict';

/**
 * Client Mux minimal (fetch natif Node 20+, aucune dépendance ajoutée).
 * Auth Basic avec MUX_TOKEN_ID / MUX_TOKEN_SECRET (jamais exposés à l'app).
 *
 * Flux utilisé partout dans le backend : Direct Upload.
 *   1. createDirectUpload({ passthrough }) -> { uploadUrl, uploadId }
 *   2. le client (admin ou app) PUT le fichier brut directement sur uploadUrl
 *      (le fichier ne transite jamais par notre serveur/disque)
 *   3. Mux traite la vidéo puis POST un webhook `video.asset.ready` avec le
 *      même `passthrough` -> le backend retrouve la ligne (event/clip) visée
 *      et y attache le playback_id.
 */

const crypto = require('crypto');

const MUX_API = 'https://api.mux.com';
const MUX_TOKEN_ID = process.env.MUX_TOKEN_ID;
const MUX_TOKEN_SECRET = process.env.MUX_TOKEN_SECRET;

function isConfigured() {
  return Boolean(MUX_TOKEN_ID && MUX_TOKEN_SECRET);
}

function authHeader() {
  const token = Buffer.from(`${MUX_TOKEN_ID}:${MUX_TOKEN_SECRET}`).toString('base64');
  return `Basic ${token}`;
}

async function muxFetch(path, { method = 'GET', body } = {}) {
  if (!isConfigured()) {
    const err = new Error('Mux non configuré (MUX_TOKEN_ID / MUX_TOKEN_SECRET manquants).');
    err.code = 'MUX_NOT_CONFIGURED';
    throw err;
  }
  const res = await fetch(`${MUX_API}${path}`, {
    method,
    headers: {
      Authorization: authHeader(),
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
    // Mux qui ne répond pas ne doit pas bloquer une requête utilisateur.
    signal: AbortSignal.timeout(8000),
  });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : {}; } catch (_) { json = { raw: text }; }
  if (!res.ok) {
    const err = new Error(`Mux ${method} ${path} -> ${res.status}: ${text}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json.data;
}

/**
 * Replay téléchargeable (lot 9) : rendition MP4 statique demandée à la
 * création de l'asset (live stream, direct upload). API Mux actuelle :
 * `static_renditions: [{ resolution }]` (l'ancien `mp4_support: 'capped-1080p'`
 * est DÉPRÉCIÉ et ne peut pas être combiné avec static_renditions). Le
 * fichier est ensuite servi à :
 *   https://stream.mux.com/<playback_id>/<resolution>.mp4?download=<nom>
 * (`highest` = meilleure résolution de la source ; nom de fichier `highest.mp4`).
 */
const STATIC_RENDITION_RESOLUTION = 'highest';
const STATIC_RENDITIONS = [{ resolution: STATIC_RENDITION_RESOLUTION }];

/** URL de téléchargement du replay MP4 (404 tant que Mux ne l'a pas préparé). */
function staticRenditionUrl(playbackId, fileName) {
  if (!playbackId) return null;
  const name = String(fileName || 'replay').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'replay';
  return `https://stream.mux.com/${playbackId}/${STATIC_RENDITION_RESOLUTION}.mp4?download=${encodeURIComponent(name)}`;
}

/** Demande la rendition MP4 sur un asset EXISTANT (créé sans). */
function createStaticRendition(assetId, resolution = STATIC_RENDITION_RESOLUTION) {
  return muxFetch(`/video/v1/assets/${assetId}/static-renditions`, {
    method: 'POST',
    body: { resolution },
  });
}

/** Crée une Direct Upload : le client PUT le fichier sur data.url. */
function createDirectUpload({ passthrough, corsOrigin = '*' } = {}) {
  return muxFetch('/video/v1/uploads', {
    method: 'POST',
    body: {
      cors_origin: corsOrigin,
      new_asset_settings: {
        playback_policy: ['public'],
        passthrough: passthrough ? JSON.stringify(passthrough) : undefined,
        static_renditions: STATIC_RENDITIONS, // replay MP4 téléchargeable
      },
    },
  }).then((data) => ({ uploadId: data.id, uploadUrl: data.url }));
}

/**
 * Crée un asset Mux directement depuis une URL de média public (ingestion).
 * Sert au contrat de publication (Atelier -> VybzzZ) : on passe une URL, Mux
 * télécharge et encode ; le webhook `video.asset.ready` rattachera le
 * playback_id via le passthrough {kind:'clip', id}.
 */
function createAssetFromUrl(url, { passthrough } = {}) {
  return muxFetch('/video/v1/assets', {
    method: 'POST',
    body: {
      input: [{ url }],
      playback_policy: ['public'],
      passthrough: passthrough ? JSON.stringify(passthrough) : undefined,
      // Clips du feed : pas de MP4 (défaut Mux = aucune rendition ; l'ancien
      // `mp4_support: 'none'` est déprécié).
    },
  }).then((data) => ({
    assetId: data.id,
    status: data.status,
    playbackId: (data.playback_ids && data.playback_ids[0] && data.playback_ids[0].id) || null,
  }));
}

function getUpload(uploadId) {
  return muxFetch(`/video/v1/uploads/${uploadId}`);
}

function getAsset(assetId) {
  return muxFetch(`/video/v1/assets/${assetId}`);
}

function deleteAsset(assetId) {
  return muxFetch(`/video/v1/assets/${assetId}`, { method: 'DELETE' });
}

const LIVE_INGEST_URL = 'rtmps://global-live.mux.com:443/app';
// RTMP simple (non-TLS, port 5222) : cible plus fiable pour le relais CDN
// depuis Zego (addPublishCdnUrl accepte du rtmp://). Même stream key.
const LIVE_INGEST_URL_RTMP = 'rtmp://global-live.mux.com:5222/app';

/**
 * Live Stream Mux (mode "Concert PRO" : régie -> encodeur -> Mux Live).
 * Le `passthrough` se passe UNIQUEMENT à la racine : Mux le recopie lui-même
 * sur l'asset de replay. Le mettre aussi dans `new_asset_settings` est
 * désormais refusé par Mux (400 invalid_parameters) et bloque la création
 * du flux. Filet de sécurité côté webhook `video.asset.ready` : l'asset est
 * aussi rattaché via `live_stream_id` -> events.mux_live_stream_id.
 */
/*
 * `latencyMode` (lot 12) : champ Mux `latency_mode` = 'low' | 'reduced' |
 * 'standard' (défaut Mux : standard, ~15-30 s de retard). Le mode « pro »
 * (régie vidéo) passe 'low' (~5 s) pour que le public réagisse presque en
 * même temps que la salle. Attention : en low/reduced, Mux met le
 * reconnect_window à 0 par défaut -> on le fixe explicitement à 60 s pour
 * qu'une micro-coupure réseau de l'encodeur ne termine pas le concert.
 */
const LATENCY_MODES = ['low', 'reduced', 'standard'];
function createLiveStream({ passthrough, latencyMode } = {}) {
  const pt = passthrough ? JSON.stringify(passthrough) : undefined;
  const latency = LATENCY_MODES.includes(latencyMode) ? latencyMode : undefined;
  return muxFetch('/video/v1/live-streams', {
    method: 'POST',
    body: {
      playback_policy: ['public'],
      reconnect_window: 60,
      latency_mode: latency, // absent = standard (mode mobile / relais Zego inchangé)
      passthrough: pt, // live stream + asset de replay (recopié par Mux)
      new_asset_settings: {
        playback_policy: ['public'],
        static_renditions: STATIC_RENDITIONS, // replay MP4 téléchargeable (lot 9)
      },
    },
  }).then((data) => ({
    liveStreamId: data.id,
    streamKey: data.stream_key,
    playbackId: data.playback_ids?.[0]?.id || null,
    ingestUrl: LIVE_INGEST_URL,
  }));
}

/** Live stream Mux ; `status` = 'active' (flux reçu) | 'idle' | 'disabled'. */
function getLiveStream(id) {
  return muxFetch(`/video/v1/live-streams/${id}`);
}

function deleteLiveStream(id) {
  return muxFetch(`/video/v1/live-streams/${id}`, { method: 'DELETE' });
}

/**
 * Vérifie la signature du webhook Mux.
 * Header `Mux-Signature: t=<timestamp>,v1=<hmac hex>`
 * HMAC-SHA256( `${t}.${rawBody}` , MUX_WEBHOOK_SECRET )
 */
const WEBHOOK_TOLERANCE_S = 5 * 60; // ±5 min : un webhook capturé ne se rejoue pas indéfiniment
function verifyWebhookSignature(rawBody, signatureHeader, secret, { now = Date.now() } = {}) {
  if (!secret || !signatureHeader) return false;
  const parts = Object.fromEntries(
    String(signatureHeader).split(',').map((p) => p.split('=').map((s) => s.trim()))
  );
  const { t, v1 } = parts;
  if (!t || !v1) return false;
  const ts = Number(t);
  if (!Number.isFinite(ts) || Math.abs(now / 1000 - ts) > WEBHOOK_TOLERANCE_S) return false;
  const payload = `${t}.${rawBody}`;
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(v1, 'hex'));
  } catch (_) {
    return false;
  }
}

module.exports = {
  isConfigured,
  createDirectUpload,
  createAssetFromUrl,
  getUpload,
  getAsset,
  deleteAsset,
  createLiveStream,
  getLiveStream,
  deleteLiveStream,
  verifyWebhookSignature,
  createStaticRendition,
  staticRenditionUrl,
  STATIC_RENDITION_RESOLUTION,
  LIVE_INGEST_URL,
  LIVE_INGEST_URL_RTMP,
  LATENCY_MODES,
};

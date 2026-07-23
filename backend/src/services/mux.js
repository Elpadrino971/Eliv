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

/** Crée une Direct Upload : le client PUT le fichier sur data.url. */
function createDirectUpload({ passthrough, corsOrigin = '*' } = {}) {
  return muxFetch('/video/v1/uploads', {
    method: 'POST',
    body: {
      cors_origin: corsOrigin,
      new_asset_settings: {
        playback_policy: ['public'],
        passthrough: passthrough ? JSON.stringify(passthrough) : undefined,
      },
    },
  }).then((data) => ({ uploadId: data.id, uploadUrl: data.url }));
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
 * IMPORTANT : Mux ne recopie PAS le passthrough racine du live stream sur
 * l'asset de replay. Le passthrough de l'asset provient EXCLUSIVEMENT de
 * `new_asset_settings.passthrough`. Sans lui, le webhook `video.asset.ready`
 * reçoit un passthrough null et ne rattache jamais le replay à l'event
 * (le concert s'enregistre mais le replay n'apparaît jamais).
 */
function createLiveStream({ passthrough } = {}) {
  const pt = passthrough ? JSON.stringify(passthrough) : undefined;
  return muxFetch('/video/v1/live-streams', {
    method: 'POST',
    body: {
      playback_policy: ['public'],
      reconnect_window: 60,
      passthrough: pt, // identifie le LIVE stream (webhooks live_stream.*)
      new_asset_settings: {
        playback_policy: ['public'],
        passthrough: pt, // identifie l'ASSET de replay (webhook asset.ready)
      },
    },
  }).then((data) => ({
    liveStreamId: data.id,
    streamKey: data.stream_key,
    playbackId: data.playback_ids?.[0]?.id || null,
    ingestUrl: LIVE_INGEST_URL,
  }));
}

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
function verifyWebhookSignature(rawBody, signatureHeader, secret) {
  if (!secret || !signatureHeader) return false;
  const parts = Object.fromEntries(
    signatureHeader.split(',').map((p) => p.split('=').map((s) => s.trim()))
  );
  const { t, v1 } = parts;
  if (!t || !v1) return false;
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
  getUpload,
  getAsset,
  deleteAsset,
  createLiveStream,
  getLiveStream,
  deleteLiveStream,
  verifyWebhookSignature,
  LIVE_INGEST_URL,
  LIVE_INGEST_URL_RTMP,
};

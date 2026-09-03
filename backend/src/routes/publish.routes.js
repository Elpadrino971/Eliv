'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// API de publication VybzzZ (contrat machine-à-machine, ex : Atelier -> VybzzZ)
// Monté sous /api/v1. Auth par clé API (en-tête X-API-Key).
//
//   POST /api/v1/publish                 -> publie un clip (video_url OU mux_playback_id)
//   GET  /api/v1/publications/:id        -> statut d'une publication
//   GET  /api/v1/publications/:id/stats  -> vues / likes
//
// Correspond 1:1 aux 4 opérations d'un publisher : authenticate (la clé),
// publish, status, stats.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const mux = require('../services/mux');
const { requireApiKey } = require('../auth');

const hls = (pid) => (pid ? `https://stream.mux.com/${pid}.m3u8` : null);
const thumb = (pid) => (pid ? `https://image.mux.com/${pid}/thumbnail.jpg` : null);

function stateOf(clip) {
  if (clip.mux_playback_id) return 'ready';
  if (clip.upload_status === 'errored') return 'errored';
  return 'processing';
}
function payload(clip) {
  return {
    id: clip.id,
    external_ref: clip.external_ref || null,
    state: stateOf(clip),
    feed: clip.feed,
    title: clip.title,
    mux_playback_id: clip.mux_playback_id || null,
    hls_url: hls(clip.mux_playback_id),
    thumbnail_url: thumb(clip.mux_playback_id),
    active: !!clip.active,
    created_at: clip.created_at,
  };
}

// POST /api/v1/publish
router.post('/publish', requireApiKey, async (req, res) => {
  const b = req.body || {};
  const feed = b.feed === 'clips' ? 'clips' : 'for_you';
  const title = (b.title != null ? String(b.title) : '').slice(0, 200) || null;
  const artistId = b.artist_id ? Number(b.artist_id) : null;
  const externalRef = b.external_ref ? String(b.external_ref).slice(0, 120) : null;

  // Idempotence : même external_ref pour la même clé -> on renvoie l'existant.
  if (externalRef) {
    const existing = db.prepare('SELECT * FROM feed_clips WHERE external_ref = ? AND api_key_id = ?').get(externalRef, req.apiKey.id);
    if (existing) return res.json({ status: 'success', data: payload(existing) });
  }

  if (!b.video_url && !b.mux_playback_id) {
    return res.status(422).json({ status: 'error', message: 'Fournis video_url (URL publique) ou mux_playback_id.' });
  }

  // Raccourci : Atelier fournit déjà un Playback ID Mux -> clip prêt tout de suite.
  if (b.mux_playback_id) {
    const info = db.prepare(
      `INSERT INTO feed_clips (feed, title, mux_playback_id, user_id, active, upload_status, source, external_ref, api_key_id)
       VALUES (?, ?, ?, ?, 1, 'ready', 'atelier', ?, ?)`
    ).run(feed, title, String(b.mux_playback_id), artistId, externalRef, req.apiKey.id);
    return res.json({ status: 'success', data: payload(db.prepare('SELECT * FROM feed_clips WHERE id = ?').get(info.lastInsertRowid)) });
  }

  // Cas URL publique : on crée le clip (en cours) puis on lance l'ingestion Mux.
  if (!mux.isConfigured()) return res.status(503).json({ status: 'error', message: 'Mux non configuré côté serveur.' });
  const info = db.prepare(
    `INSERT INTO feed_clips (feed, title, user_id, active, upload_status, source, external_ref, api_key_id)
     VALUES (?, ?, ?, 1, 'processing', 'atelier', ?, ?)`
  ).run(feed, title, artistId, externalRef, req.apiKey.id);
  const clipId = info.lastInsertRowid;
  try {
    const asset = await mux.createAssetFromUrl(String(b.video_url), { passthrough: { kind: 'clip', id: clipId } });
    db.prepare('UPDATE feed_clips SET mux_asset_id = ? WHERE id = ?').run(asset.assetId, clipId);
    if (asset.playbackId) {
      db.prepare("UPDATE feed_clips SET mux_playback_id = ?, upload_status = 'ready' WHERE id = ?").run(asset.playbackId, clipId);
    }
  } catch (e) {
    db.prepare("UPDATE feed_clips SET upload_status = 'errored' WHERE id = ?").run(clipId);
    return res.status(502).json({ status: 'error', message: 'Erreur ingestion Mux : ' + e.message });
  }
  return res.json({ status: 'success', data: payload(db.prepare('SELECT * FROM feed_clips WHERE id = ?').get(clipId)) });
});

// GET /api/v1/publications/:id
router.get('/publications/:id', requireApiKey, (req, res) => {
  const clip = db.prepare('SELECT * FROM feed_clips WHERE id = ? AND api_key_id = ?').get(req.params.id, req.apiKey.id);
  if (!clip) return res.status(404).json({ status: 'error', message: 'Publication introuvable.' });
  return res.json({ status: 'success', data: payload(clip) });
});

// GET /api/v1/publications/:id/stats
router.get('/publications/:id/stats', requireApiKey, (req, res) => {
  const clip = db.prepare('SELECT id, views, likes FROM feed_clips WHERE id = ? AND api_key_id = ?').get(req.params.id, req.apiKey.id);
  if (!clip) return res.status(404).json({ status: 'error', message: 'Publication introuvable.' });
  return res.json({ status: 'success', data: { views: clip.views || 0, likes: clip.likes || 0 } });
});

module.exports = router;

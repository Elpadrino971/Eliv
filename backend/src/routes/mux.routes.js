'use strict';

/**
 * Webhook Mux uniquement (POST /api/mux/webhook). Mounté à part dans app.js
 * avec un parseur `express.raw` car la vérification de signature a besoin
 * du corps BRUT exact envoyé par Mux (pas du JSON déjà parsé).
 *
 * Les endpoints "direct upload" (créer une upload URL) vivent dans
 * admin.routes.js (côté admin) et misc.routes.js (côté app, soumission
 * utilisateur) car ils réutilisent les middlewares requireAdmin/requireAuth
 * déjà définis localement dans ces fichiers.
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const mux = require('../services/mux');

const REPLAY_RETENTION_DAYS = Number(process.env.REPLAY_RETENTION_DAYS) || 60;
const CLIP_RETENTION_DAYS = Number(process.env.CLIP_RETENTION_DAYS) || 30;
const muxHls = (id) => (id ? `https://stream.mux.com/${id}.m3u8` : null);

function safeParsePassthrough(raw) {
  if (!raw) return null;
  try { return JSON.parse(raw); } catch (_) { return null; }
}

router.post('/', (req, res) => {
  const secret = process.env.MUX_WEBHOOK_SECRET;
  const raw = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : JSON.stringify(req.body || {});

  if (secret) {
    const sig = req.headers['mux-signature'];
    if (!mux.verifyWebhookSignature(raw, sig, secret)) {
      console.warn('[mux webhook] signature invalide, rejeté');
      return res.status(400).json({ status: 'error', message: 'Signature invalide.' });
    }
  }

  let evt;
  try {
    evt = JSON.parse(raw);
  } catch (_) {
    return res.status(400).json({ status: 'error', message: 'Payload JSON invalide.' });
  }

  const type = evt.type;
  const obj = evt.data || {};
  console.log(`[mux webhook] ${type}`);

  try {
    if (type === 'video.asset.ready') {
      const passthrough = safeParsePassthrough(obj.passthrough);
      const playbackId = (obj.playback_ids || []).find((p) => p.policy === 'public')?.id
        || obj.playback_ids?.[0]?.id || null;

      // Rattachement du replay à l'event : par passthrough (nominal) ou, en
      // secours, via le live_stream_id que Mux fournit sur les assets issus
      // d'un live -> robuste même si le passthrough de l'asset venait à manquer.
      let eventId = (passthrough?.kind === 'event' && passthrough.id) ? passthrough.id : null;
      if (!eventId && obj.live_stream_id) {
        const evByLs = db.prepare('SELECT id FROM events WHERE mux_live_stream_id = ?').get(obj.live_stream_id);
        if (evByLs) eventId = evByLs.id;
      }

      if (eventId) {
        // Durée du replay choisie par l'artiste/l'admin pour CE concert
        // (défaut = rétention globale). Si le replay est désactivé, on stocke
        // quand même l'asset mais avec une expiration immédiate : serializeEvent
        // ne le sert pas et le cron de rétention le supprimera.
        const ev = db.prepare('SELECT replay_enabled, replay_duration_days FROM events WHERE id = ?').get(eventId);
        const enabled = ev ? (ev.replay_enabled === null || ev.replay_enabled === undefined ? 1 : ev.replay_enabled) : 1;
        let days = ev ? parseInt(ev.replay_duration_days, 10) : REPLAY_RETENTION_DAYS;
        if (!Number.isFinite(days) || days < 1) days = REPLAY_RETENTION_DAYS;
        if (days > 60) days = 60;
        if (!enabled) days = 0; // expire tout de suite
        db.prepare(
          `UPDATE events SET mux_playback_id = ?, mux_live_playback_id = ?, mux_asset_id = ?,
              mux_upload_status = 'ready', video_reel = ?,
              replay_expires_at = datetime('now', '+' || ? || ' days')
           WHERE id = ?`
        ).run(playbackId, playbackId, obj.id, muxHls(playbackId), days, eventId);
      } else if (passthrough?.kind === 'clip' && passthrough.id) {
        db.prepare(
          `UPDATE feed_clips SET mux_playback_id = ?, mux_asset_id = ?, upload_status = 'ready',
              expires_at = datetime('now', '+' || ? || ' days')
           WHERE id = ?`
        ).run(playbackId, obj.id, CLIP_RETENTION_DAYS, passthrough.id);
      }
    } else if (type === 'video.asset.errored') {
      const passthrough = safeParsePassthrough(obj.passthrough);
      if (passthrough?.kind === 'event' && passthrough.id) {
        db.prepare("UPDATE events SET mux_upload_status = 'errored' WHERE id = ?").run(passthrough.id);
      } else if (passthrough?.kind === 'clip' && passthrough.id) {
        db.prepare("UPDATE feed_clips SET upload_status = 'errored' WHERE id = ?").run(passthrough.id);
      }
    } else if (type === 'video.live_stream.active') {
      db.prepare("UPDATE events SET status = 'live' WHERE mux_live_stream_id = ?").run(obj.id);
    } else if (type === 'video.live_stream.idle') {
      db.prepare(
        "UPDATE events SET status = 'completed' WHERE mux_live_stream_id = ? AND status = 'live'"
      ).run(obj.id);
    }
    // video.asset.deleted : rien à faire, c'est nous qui déclenchons la suppression (job de nettoyage).
  } catch (e) {
    console.error('[mux webhook] erreur traitement', e.message);
  }

  return res.json({ status: 'success' });
});

module.exports = router;

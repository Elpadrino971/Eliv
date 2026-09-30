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
const moderation = require('../services/moderation');

const REPLAY_RETENTION_DAYS = Number(process.env.REPLAY_RETENTION_DAYS) || 60;
const CLIP_RETENTION_DAYS = Number(process.env.CLIP_RETENTION_DAYS) || 30;
const muxHls = (id) => (id ? `https://stream.mux.com/${id}.m3u8` : null);

function safeParsePassthrough(raw) {
  if (!raw) return null;
  try { return JSON.parse(raw); } catch (_) { return null; }
}

if (!process.env.MUX_WEBHOOK_SECRET) {
  const msg =
    '[mux webhook] MUX_WEBHOOK_SECRET absent : signature non vérifiée, ' +
    'n\'importe qui pourrait simuler un event Mux.';
  if (process.env.NODE_ENV === 'production') throw new Error(msg);
  console.error('⚠️⚠️ ' + msg + ' (toléré en dev uniquement)');
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

      // Teaser d'accueil (lot 13) : bande-annonce PUBLIQUE, rangée à part du
      // replay (ne touche ni mux_playback_id ni video_reel ni replay_expires_at).
      // L'ancien asset teaser éventuel est supprimé chez Mux en best effort.
      if (passthrough?.kind === 'teaser' && passthrough.id) {
        const prev = db.prepare('SELECT id, teaser_asset_id FROM events WHERE id = ?').get(passthrough.id);
        if (!prev) {
          console.warn(`[mux webhook] teaser pour event #${passthrough.id} introuvable, asset ${obj.id} ignoré`);
        } else {
          db.prepare('UPDATE events SET teaser_playback_id = ?, teaser_asset_id = ? WHERE id = ?')
            .run(playbackId, obj.id, prev.id);
          if (prev.teaser_asset_id && prev.teaser_asset_id !== obj.id && mux.isConfigured()) {
            mux.deleteAsset(prev.teaser_asset_id)
              .then(() => console.log(`[mux webhook] ancien teaser ${prev.teaser_asset_id} (event #${prev.id}) supprimé`))
              .catch((e) => console.error(`[mux webhook] suppression ancien teaser event #${prev.id}:`, e.message));
          }
          moderation.moderateVideo({ url: muxHls(playbackId), targetType: 'teaser', targetId: prev.id });
        }
        return res.json({ status: 'success' });
      }

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
        // Modération du replay (asynchrone) : Sightengine échantillonne l'asset
        // et rappelle /api/moderation/callback ; sur blocage le replay est masqué.
        moderation.moderateVideo({ url: muxHls(playbackId), targetType: 'event', targetId: eventId });
      } else if (passthrough?.kind === 'clip' && passthrough.id) {
        db.prepare(
          `UPDATE feed_clips SET mux_playback_id = ?, mux_asset_id = ?, upload_status = 'ready',
              expires_at = datetime('now', '+' || ? || ' days')
           WHERE id = ?`
        ).run(playbackId, obj.id, CLIP_RETENTION_DAYS, passthrough.id);
        moderation.moderateVideo({ url: muxHls(playbackId), targetType: 'clip', targetId: passthrough.id });
      }
    } else if (type === 'video.asset.errored') {
      const passthrough = safeParsePassthrough(obj.passthrough);
      if (passthrough?.kind === 'event' && passthrough.id) {
        db.prepare("UPDATE events SET mux_upload_status = 'errored' WHERE id = ?").run(passthrough.id);
      } else if (passthrough?.kind === 'clip' && passthrough.id) {
        db.prepare("UPDATE feed_clips SET upload_status = 'errored' WHERE id = ?").run(passthrough.id);
      } else if (passthrough?.kind === 'teaser' && passthrough.id) {
        // Teaser en échec : l'ancien teaser (s'il y en a un) reste en place.
        console.warn(`[mux webhook] teaser event #${passthrough.id} : encodage Mux en échec`);
      }
    } else if (type === 'video.live_stream.active') {
      db.prepare("UPDATE events SET status = 'live' WHERE mux_live_stream_id = ?").run(obj.id);
      // Surveillance du LIVE en direct : on pointe Sightengine sur le flux HLS
      // Mux du concert (échantillonnage continu, alerte sur callback). C'est la
      // surface la plus critique (cams artiste + fans co-host en public).
      const liveEv = db.prepare(
        'SELECT id, mux_live_playback_id FROM events WHERE mux_live_stream_id = ?'
      ).get(obj.id);
      const livePlaybackId = liveEv?.mux_live_playback_id
        || (obj.playback_ids || []).find((p) => p.policy === 'public')?.id
        || obj.playback_ids?.[0]?.id;
      if (liveEv && livePlaybackId) {
        moderation.startLiveMonitor({ url: muxHls(livePlaybackId), targetType: 'live', targetId: liveEv.id });
      }
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

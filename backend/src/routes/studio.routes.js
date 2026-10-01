'use strict';

/**
 * Studio web (/api/studio) : l'artiste lance son concert depuis le navigateur.
 * Désactivé tant que STUDIO_WEB != '1' (404 « Indisponible. », sauf /status).
 * Voir services/studio_ingest.js pour le pipe navigateur -> ffmpeg -> Mux.
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const { db } = require('../db');
const { serializeEvent, ok, fail, asyncHandler } = require('../helpers');
const { requireAuth } = require('../auth');
const eventAccess = require('../services/event_access');
const moderation = require('../services/moderation');
const mux = require('../services/mux');
const studio = require('../services/studio_ingest');

const router = express.Router();
const TITLE_MAX = 80;
const LIVE_WINDOW_MS = 6 * 3600 * 1000;

router.get('/status', (req, res) => ok(res, { enabled: studio.enabled(), ffmpeg: studio.hasFfmpeg() }));

// Tout le reste : 404 tant que la fonction n'est pas activée.
router.use((req, res, next) => {
  if (!studio.enabled()) return res.status(404).json({ status: 'error', message: 'Indisponible.' });
  return next();
});

const artistOnly = (req, res, next) => {
  if (Number(req.user.is_artist) !== 1) return fail(res, 'Réservé aux artistes.', 403);
  return next();
};

// 5 créations / 15 min par compte (seules les créations réussies comptent).
const createLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  keyGenerator: (req) => `studio-u${req.user ? req.user.id : 'anon'}`,
  skipFailedRequests: true,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 'error', message: 'Trop de lancements de live, réessaie dans quelques minutes.' },
});

/** Réponse commune : la session décrite pour le navigateur (jamais la clé Mux). */
function sessionPayload(ev, userId) {
  return {
    event_id: ev.id,
    state: ev.status === 'live' ? 'live' : 'prepared',
    event: serializeEvent(ev, { currentUserId: userId }),
    ingest: studio.ingestInfo(ev.id, userId),
    ...studio.urlsFor(ev.id),
  };
}

const parseBool = (v, dflt) => {
  if (v === undefined || v === null || v === '') return dflt;
  if (v === true || v === 1 || v === '1' || v === 'true') return true;
  if (v === false || v === 0 || v === '0' || v === 'false') return false;
  return dflt;
};

// POST /api/studio/live : crée le concert + le flux Mux, renvoie le jeton d'ingest.
router.post('/live', requireAuth, artistOnly, createLimiter, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const title = typeof b.title === 'string' ? b.title.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim() : '';
  if (!title) return fail(res, 'Le titre est requis.', 422, { title: ['Le titre est requis.'] });
  if (title.length > TITLE_MAX) {
    return fail(res, `Le titre est trop long (${TITLE_MAX} caractères max).`, 422, { title: [`${TITLE_MAX} caractères max.`] });
  }
  const price = eventAccess.normalizeTicketPrice(b.price);
  if (!price.ok) return fail(res, price.error, 422, { price: [price.error] });
  const replay = parseBool(b.replay, true);

  const verdict = await moderation.reviewText(title, { targetType: 'event', targetId: null });
  if (verdict.action === 'block') {
    return fail(res, 'Le titre enfreint les règles de la communauté.', 422, { title: ['Titre refusé.'] });
  }
  if (!studio.hasFfmpeg()) return fail(res, "Le moteur de diffusion n'est pas disponible sur ce serveur.", 503);
  if (!mux.isConfigured()) return fail(res, 'Diffusion indisponible pour le moment.', 503);

  // Contrôle d'unicité + insertion dans le même tour synchrone : deux requêtes
  // simultanées ne peuvent pas créer deux sessions.
  const existing = studio.activeSessionOf(req.user.id);
  if (existing) {
    return res.status(409).json({
      status: 'error',
      message: 'Tu as déjà un live en cours ou en préparation.',
      data: sessionPayload(existing, req.user.id),
    });
  }
  const now = new Date();
  const info = db.prepare(
    `INSERT INTO events (artist_id, name, ticket_price, start_date_time, end_date_time, is_private,
        has_live_chat, replay_enabled, replay_duration_days, status, live_mode, studio_web)
     VALUES (?, ?, ?, ?, ?, 0, 1, ?, 60, 'published', 'pro', 1)`
  ).run(req.user.id, title, price.value, now.toISOString(), new Date(now.getTime() + LIVE_WINDOW_MS).toISOString(), replay ? 1 : 0);
  const eventId = Number(info.lastInsertRowid);

  let stream;
  try {
    stream = await mux.createLiveStream({ passthrough: { kind: 'event', id: eventId }, latencyMode: 'low' });
  } catch (e) {
    console.error(`[studio] event #${eventId} : création du flux Mux échouée (${String(e.message).slice(0, 200)})`);
    db.prepare('DELETE FROM events WHERE id = ? AND studio_web = 1 AND mux_live_stream_id IS NULL').run(eventId);
    return fail(res, 'Impossible de préparer la diffusion pour le moment. Réessaie dans un instant.', 502);
  }
  db.prepare(
    `UPDATE events SET mux_live_stream_id = ?, mux_stream_key = ?, mux_live_playback_id = ?, live_mode = 'pro'
     WHERE id = ?`
  ).run(stream.liveStreamId, stream.streamKey, stream.playbackId, eventId);

  const ev = studio.getEvent(eventId);
  console.log(`[studio] event #${eventId} créé par user#${req.user.id} (prix ${price.value}, replay ${replay ? 'oui' : 'non'})`);
  return ok(res, sessionPayload(ev, req.user.id));
}));

// GET /api/studio/live/current : la session active/préparée de l'artiste, ou null.
router.get('/live/current', requireAuth, (req, res) => {
  const ev = studio.activeSessionOf(req.user.id);
  return ok(res, ev ? sessionPayload(ev, req.user.id) : null);
});

function ownedStudioEvent(req, res) {
  const id = parseInt(req.params.id, 10);
  const ev = id ? studio.getEvent(id) : null;
  if (!ev || Number(ev.studio_web) !== 1) { fail(res, 'Live introuvable.', 404); return null; }
  if (Number(ev.artist_id) !== Number(req.user.id)) { fail(res, 'Non autorisé.', 403); return null; }
  return ev;
}

// POST /api/studio/live/:id/token : nouveau jeton d'ingest (reconnexion après 30 min ou coupure).
router.post('/live/:id/token', requireAuth, (req, res) => {
  const ev = ownedStudioEvent(req, res);
  if (!ev) return undefined;
  if (!['published', 'live'].includes(ev.status)) return fail(res, 'Ce live est terminé.', 409);
  return ok(res, { event_id: ev.id, ingest: studio.ingestInfo(ev.id, req.user.id) });
});

// POST /api/studio/live/:id/stop : l'artiste termine son concert.
router.post('/live/:id/stop', requireAuth, (req, res) => {
  const ev = ownedStudioEvent(req, res);
  if (!ev) return undefined;
  if (['published', 'live'].includes(ev.status)) studio.endEvent(ev.id, 'arrêt par l\'artiste');
  const fresh = studio.getEvent(ev.id);
  return ok(res, { stopped: true, event_id: ev.id, state: fresh.status });
});

module.exports = router;

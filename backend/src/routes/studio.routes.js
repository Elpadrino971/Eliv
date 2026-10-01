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
const pricing = require('../services/pricing');
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
    existing: !!studio.prevOf(ev), // concert programmé (billets vendus) lancé en secours
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

const hasEventId = (b) => b.event_id !== undefined && b.event_id !== null && b.event_id !== '';

/**
 * Lancer le navigateur sur un concert PROGRAMMÉ de l'artiste (billets déjà
 * vendus, plan de secours). Rien n'est créé : le concert passe en live_mode='pro'
 * (l'app lit alors le HLS Mux) et reçoit un flux Mux s'il n'en a pas. Titre, prix,
 * affiche et replay de l'évènement ne sont pas modifiés (ceux du corps sont ignorés).
 */
async function startFromExisting(req, res) {
  const rawId = req.body.event_id;
  const eventId = /^\d+$/.test(String(rawId)) ? parseInt(rawId, 10) : 0;
  if (!eventId) return fail(res, "Concert invalide.", 422, { event_id: ['Concert invalide.'] });
  const ev = studio.getEvent(eventId);
  if (!ev) return fail(res, 'Concert introuvable.', 404);
  // Propriétaire uniquement : un admin ne lance pas le concert d'un artiste depuis le studio.
  if (Number(ev.artist_id) !== Number(req.user.id)) return fail(res, "Ce concert n'est pas le tien.", 403);
  if (!['published', 'live'].includes(ev.status)) {
    return fail(res, 'Ce concert est terminé ou annulé : impossible de le lancer.', 409);
  }
  if (!studio.hasFfmpeg()) return fail(res, "Le moteur de diffusion n'est pas disponible sur ce serveur.", 503);
  if (!mux.isConfigured()) return fail(res, 'Diffusion indisponible pour le moment.', 503);

  // Unicité + réservation dans le même tour synchrone (aucun await avant claimExisting).
  const active = studio.activeSessionOf(req.user.id);
  if (active) {
    return res.status(409).json({
      status: 'error',
      message: 'Tu as déjà un live en cours ou en préparation.',
      data: sessionPayload(active, req.user.id),
    });
  }
  // Flux Mux existant (relais enregistrement de l'app) : réutilisé tel quel, même playback id
  // que celui que l'app et le site connaissent déjà (latence « standard » : quelques secondes de plus).
  const reuse = !!(ev.mux_live_stream_id && ev.mux_stream_key && ev.mux_live_playback_id);
  const prev = studio.claimExisting(ev, { newStream: !reuse });

  if (!reuse) {
    const orphan = ev.mux_live_stream_id; // flux sans clé exploitable : remplacé comme le fait la régie admin
    let stream;
    try {
      stream = await mux.createLiveStream({ passthrough: { kind: 'event', id: ev.id }, latencyMode: 'low' });
    } catch (e) {
      console.error(`[studio] event #${ev.id} : création du flux Mux échouée (${String(e.message).slice(0, 200)})`);
      studio.revertExisting(studio.getEvent(ev.id), { ...prev, new_stream: false }, 'flux Mux impossible');
      return fail(res, 'Impossible de préparer la diffusion pour le moment. Réessaie dans un instant.', 502);
    }
    db.prepare(
      `UPDATE events SET mux_live_stream_id = ?, mux_stream_key = ?, mux_live_playback_id = ?, live_mode = 'pro'
       WHERE id = ?`
    ).run(stream.liveStreamId, stream.streamKey, stream.playbackId, ev.id);
    try { db.prepare('UPDATE events SET mux_live_signed_playback_id = NULL WHERE id = ?').run(ev.id); } catch (_) { /* colonne absente */ }
    if (orphan) Promise.resolve().then(() => mux.deleteLiveStream(orphan)).catch(() => {});
  }

  const fresh = studio.getEvent(ev.id);
  console.log(`[studio] concert programmé #${ev.id} lancé par user#${req.user.id} (était ${prev.status}/${prev.live_mode || 'mobile'}, flux Mux ${reuse ? 'réutilisé' : 'créé'})`);
  return ok(res, sessionPayload(fresh, req.user.id));
}

// GET /api/studio/events : concerts programmés de l'artiste utilisables en secours.
router.get('/events', requireAuth, artistOnly, (req, res) => {
  const rows = db.prepare(
    `SELECT * FROM events
     WHERE artist_id = ? AND status IN ('published','live')
       AND NOT (studio_web = 1 AND studio_prev IS NULL)
       AND start_date_time IS NOT NULL AND datetime(start_date_time) >= datetime('now', '-12 hours')
     ORDER BY datetime(start_date_time) ASC, id ASC`
  ).all(req.user.id);
  let pendingCount = () => 0;
  try {
    require('../db_payments').run(); // colonnes des places en attente (créées à la demande)
    const q = db.prepare('SELECT COUNT(*) n FROM pending_tickets WHERE event_id = ? AND ticket_id IS NULL AND refunded_at IS NULL');
    q.get(0);
    pendingCount = (id) => q.get(id).n;
  } catch (_) { /* table des places en attente absente */ }
  const sold = db.prepare("SELECT COUNT(*) n FROM tickets WHERE event_id = ? AND COALESCE(status, 'active') <> 'refunded'");
  return ok(res, rows.map((e) => ({
    id: e.id,
    name: e.name,
    status: e.status,
    start_date_time: e.start_date_time,
    ticket_price: pricing.effectivePrice(e).price,
    // billets de l'app + places achetées sur le site pas encore rattachées à un compte
    tickets_sold: sold.get(e.id).n + pendingCount(e.id),
    cover_image: e.cover_image || null,
    live_mode: e.live_mode === 'pro' ? 'pro' : 'mobile',
    in_session: Number(e.studio_web) === 1,
  })));
});

// POST /api/studio/live : crée le concert + le flux Mux, renvoie le jeton d'ingest.
// Avec `event_id` : lance le concert programmé de l'artiste au lieu d'en créer un.
router.post('/live', requireAuth, artistOnly, createLimiter, asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (hasEventId(b)) return startFromExisting(req, res);
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
  let reverted = false;
  if (['published', 'live'].includes(ev.status)) {
    const r = studio.endEvent(ev.id, 'arrêt par l\'artiste');
    reverted = !!(r && r.reverted);
  }
  const fresh = studio.getEvent(ev.id);
  // reverted : concert programmé jamais diffusé, remis comme avant (état inchangé pour les fans).
  return ok(res, { stopped: true, event_id: ev.id, state: fresh.status, reverted });
});

module.exports = router;

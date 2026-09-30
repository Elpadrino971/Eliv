'use strict';

/**
 * Regarder un concert depuis le site (live.html), sans l'application.
 * Voir services/web_watch.js.
 *
 *   GET  /api/watch/event/:id   fiche publique (titre, affiche, prix, état)
 *   POST /api/watch/claim       retour de Stripe : session payée -> clé d'accès
 *   POST /api/watch/free        concert gratuit : réservation -> clé d'accès
 *   POST /api/watch/login       compte VybzzZ (billet acheté dans l'app) -> clé
 *   POST /api/watch/resend      « j'ai déjà ma place » : lien renvoyé par e-mail
 *   POST /api/watch/stream      clé -> état du concert et flux HLS à lire
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { compare, requireAuth } = require('../auth');
const { isGeoBlocked, serializeEvent } = require('../helpers');
const geo = require('../services/geo');
const access = require('../services/event_access');
const pricing = require('../services/pricing');
const stripeService = require('../services/stripe');
const webTickets = require('../services/web_tickets');
const webWatch = require('../services/web_watch');
const email = require('../services/email');

const fail = (res, message, code = 422, extra = {}) => res.status(code).json({ status: 'error', message, ...extra });
const ok = (res, data) => res.json({ status: 'success', data });

function eventById(id) {
  const n = Number(id);
  if (!Number.isInteger(n) || n <= 0) return null;
  return db.prepare('SELECT * FROM events WHERE id = ?').get(n) || null;
}

function blocked(req, event) {
  const country = (geo.fromIp(req.ip) || {}).code || '';
  return isGeoBlocked(event, country);
}
const GEO_MESSAGE = "Ce concert n'est pas disponible en ligne dans ta région.";

function publicEvent(event) {
  const s = serializeEvent(event);
  const artist = db.prepare('SELECT artist_name, full_name FROM users WHERE id = ?').get(event.artist_id) || {};
  const price = pricing.effectivePrice(event);
  return {
    id: event.id,
    name: event.name,
    artist: artist.artist_name || artist.full_name || '',
    cover_image: s.cover_image,
    start_date_time: event.start_date_time,
    state: webWatch.stateOf(event),
    is_free: webWatch.isFree(event),
    price: price.price,
    next_price: price.next_price,
    next_price_at: price.next_price_at,
  };
}

async function mailWatchLink(to, event, token, paid) {
  try {
    await email.sendEmail({
      to,
      subject: `Ton accès au live · ${event.name}`,
      html: webWatch.watchEmailHtml(event.name, webWatch.watchUrl(event.id, token), { paid }),
      kind: 'watch_link',
    });
    return true;
  } catch (e) {
    console.error('[live web] e-mail du lien non envoyé :', e.message);
    return false;
  }
}

router.get('/event/:id', (req, res) => {
  const event = eventById(req.params.id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  res.set('Cache-Control', 'no-store');
  return ok(res, publicEvent(event));
});

// Retour de Stripe. On interroge Stripe directement plutôt que d'attendre le
// webhook : le fan revient souvent AVANT lui. handlePaid est idempotent (le
// webhook qui arrive ensuite ne crée ni second billet ni second e-mail).
router.post('/claim', async (req, res) => {
  const sessionId = String((req.body || {}).session_id || '');
  if (!/^cs_(test|live)_[A-Za-z0-9]{10,200}$/.test(sessionId)) return fail(res, 'Lien de paiement invalide.', 400);
  if (!stripeService.isConfigured()) return fail(res, 'Paiement indisponible pour le moment.', 503);
  let session;
  try {
    session = await stripeService.retrieveCheckoutSession(sessionId);
  } catch (e) {
    return fail(res, 'Paiement introuvable.', 404);
  }
  if (!session || session.metadata?.kind !== 'ticket') return fail(res, 'Paiement introuvable.', 404);
  if (session.payment_status !== 'paid') {
    return fail(res, 'Ton paiement est en cours de confirmation, patiente quelques secondes.', 409, { code: 'pending' });
  }
  const eventId = Number(session.metadata?.event_id);
  const e = access.normEmail(session.metadata?.email || session.customer_details?.email);
  const event = eventById(eventId);
  if (!event || !e) return fail(res, 'Paiement introuvable.', 404);
  try {
    await webTickets.handlePaid(session);
  } catch (err) {
    console.error('[live web] attribution après paiement :', err.message);
    return fail(res, 'Ton paiement est bien reçu, mais ta place met un instant à arriver. Réessaie dans une minute.', 503);
  }
  if (!webWatch.canWatch(e, event)) {
    // Paiement remboursé entre-temps.
    return fail(res, "Cette place n'est plus active.", 403, { code: 'no_access' });
  }
  return ok(res, { token: webWatch.issue(e, eventId, 'stripe'), event_id: eventId, email: access.maskEmail(e) });
});

// Concert gratuit : place réservée tout de suite, comme dans l'app.
router.post('/free', async (req, res) => {
  const b = req.body || {};
  const event = eventById(b.event_id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  if (!webWatch.isFree(event)) return fail(res, 'Ce concert est payant.', 409, { code: 'paid' });
  if (webWatch.stateOf(event) === 'ended') return fail(res, 'Ce concert est terminé.', 410);
  if (blocked(req, event)) return fail(res, GEO_MESSAGE, 451);
  const e = access.normEmail(b.email);
  if (!access.isValidEmail(e)) return fail(res, 'Entre une adresse e-mail valide.');
  if (access.isDisposableEmail(e)) return fail(res, 'Utilise ton adresse e-mail habituelle.');
  // Idempotent par (concert, e-mail) : une seconde réservation ne crée rien.
  access.grantByEmail({ email: e, eventId: event.id, pricePaid: 0, source: 'web_free', ref: `${event.id}:${access.canonEmail(e)}` });
  const token = webWatch.issue(e, event.id, 'web_free');
  // L'e-mail sert à retrouver l'accès depuis un autre appareil ; on ne
  // l'attend pas pour ouvrir le live.
  mailWatchLink(e, event, webWatch.issue(e, event.id, 'web_free_email'), false);
  return ok(res, { token, event_id: event.id, email: access.maskEmail(e) });
});

// Compte déjà connecté sur l'app web (/web/) : clé d'accès sans ressaisir
// l'e-mail. Même règle que /login : place (app ou site), concert gratuit,
// artiste du concert ou admin.
router.post('/token', requireAuth, (req, res) => {
  const event = eventById((req.body || {}).event_id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  const user = req.user;
  const e = access.normEmail(user.email);
  const allowed = webWatch.isFree(event)
    || (e && access.hasAccess(e, event.id))
    || !!db.prepare("SELECT 1 FROM tickets WHERE event_id = ? AND user_id = ? AND COALESCE(status, 'active') <> 'refunded'").get(event.id, user.id)
    || Number(user.id) === Number(event.artist_id)
    || user.role === 'admin';
  if (!allowed || !e) return fail(res, 'Pas encore de place pour ce concert.', 403, { code: 'no_access' });
  return ok(res, { token: webWatch.issue(e, event.id, 'web_account'), event_id: event.id, email: access.maskEmail(e) });
});

// Billet acheté dans l'app : on se connecte avec son compte VybzzZ.
router.post('/login', (req, res) => {
  const b = req.body || {};
  const event = eventById(b.event_id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  const e = access.normEmail(b.email);
  const user = e ? access.findUserByEmail(e) : null;
  if (!user || !user.password || !compare(b.password, user.password)) {
    return fail(res, 'E-mail ou mot de passe incorrect.', 401);
  }
  const allowed = webWatch.isFree(event)
    || access.hasAccess(e, event.id)
    || Number(user.id) === Number(event.artist_id)
    || user.role === 'admin';
  if (!allowed) return fail(res, "Pas encore de place pour ce concert avec ce compte.", 403, { code: 'no_access' });
  return ok(res, { token: webWatch.issue(e, event.id, 'account'), event_id: event.id, email: access.maskEmail(e) });
});

// « J'ai déjà ma place » : nouveau lien par e-mail. Réponse identique que la
// place existe ou non (on ne révèle pas qui a acheté).
router.post('/resend', async (req, res) => {
  const b = req.body || {};
  const event = eventById(b.event_id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  const e = access.normEmail(b.email);
  if (!access.isValidEmail(e)) return fail(res, 'Entre une adresse e-mail valide.');
  if (!webWatch.isFree(event) && webWatch.canWatch(e, event)) {
    await mailWatchLink(e, event, webWatch.issue(e, event.id, 'resend'), true);
  }
  return ok(res, { sent: true });
});

// Lecture. Le droit est revérifié à chaque appel (remboursement = accès coupé).
// Le navigateur ne reçoit qu'une URL signée qui expire (jamais l'ID public),
// et une place ne s'ouvre que sur MAX_DEVICES écrans à la fois.
router.post('/stream', async (req, res) => {
  const b = req.body || {};
  res.set('Cache-Control', 'no-store');
  const event = eventById(b.event_id);
  if (!event) return fail(res, 'Concert introuvable.', 404);
  const row = webWatch.lookup(b.token, event.id);
  if (!row) return fail(res, "Ce lien d'accès n'est pas valide pour ce concert.", 401, { code: 'bad_token' });
  if (!webWatch.canWatch(row.email, event)) return fail(res, "Cette place n'est plus active.", 403, { code: 'no_access' });
  if (blocked(req, event)) return fail(res, GEO_MESSAGE, 451, { code: 'geo' });

  const info = publicEvent(event);
  const base = { ...info, email: access.maskEmail(row.email), seat: row.id, media: null, url: null };
  let kind = null;
  if (info.state === 'live' && (event.mux_live_stream_id || event.mux_live_playback_id)) kind = 'live';
  if (info.state === 'ended' && !serializeEvent(event).replay_expired && (event.mux_asset_id || event.mux_playback_id)) kind = 'replay';
  if (!kind) return ok(res, base);

  const device = String(b.device || '');
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(device)) return fail(res, 'Recharge la page.', 400, { code: 'bad_device' });
  if (!webWatch.takeSeat(event.id, row.email, device)) {
    return fail(res, `Ta place est déjà ouverte sur ${webWatch.MAX_DEVICES} écrans. Ferme-en un, puis réessaie dans une minute.`, 409, { code: 'too_many_devices' });
  }
  // L'URL n'est envoyée qu'à la demande (want_url) : la page la demande une
  // fois au lancement, pas à chaque passage de contrôle.
  if (!b.want_url) return ok(res, { ...base, media: kind });
  try {
    const p = await webWatch.playbackUrl(event, kind);
    if (p.reason === 'signing_not_configured') {
      console.error('[live web] MUX_SIGNING_KEY_ID / MUX_SIGNING_KEY_PRIVATE absents : lecture web refusée');
      return fail(res, 'La diffusion sur le site est momentanément indisponible. Regarde le concert dans l’application VybzzZ.', 503, { code: 'unavailable' });
    }
    return ok(res, { ...base, media: p.url ? kind : null, url: p.url });
  } catch (e) {
    console.error('[live web] URL de lecture :', e.message);
    return fail(res, 'Le flux met un instant à arriver, réessaie.', 503, { code: 'retry' });
  }
});

module.exports = router;

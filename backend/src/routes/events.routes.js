'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { serializeEvent, serializeUser, ok, fail, genReceipt, resolveArtistCommission, splitAmount } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');
const { saveUpload } = require('../uploads');
const moderation = require('../services/moderation');
const apporteurLedger = require('../services/apporteur_ledger');
const apporteurBonus = require('../services/apporteur_bonus');

// GET /api/events?status=&day=&genre_ids=
// day: today | future ; status: published | live | completed | …
router.get('/events', optionalAuth, (req, res) => {
  const { status, day, genre_ids } = req.query;
  let sql = 'SELECT * FROM events WHERE 1=1';
  const params = [];

  if (status) { sql += ' AND status = ?'; params.push(status); }

  if (day === 'today') {
    sql += " AND date(start_date_time) = date('now')";
  } else if (day === 'future') {
    sql += " AND datetime(start_date_time) >= datetime('now')";
  }

  if (genre_ids && genre_ids !== '[]' && genre_ids !== '') {
    const ids = String(genre_ids).split(',').filter(Boolean);
    if (ids.length) {
      sql += ` AND genre_id IN (${ids.map(() => '?').join(',')})`;
      params.push(...ids);
    }
  }

  sql += ' ORDER BY datetime(start_date_time) ASC';
  const rows = db.prepare(sql).all(...params);
  return ok(res, rows.map((r) => serializeEvent(r, { currentUserId: req.user?.id })));
});

// GET /api/banner-events
router.get('/banner-events', optionalAuth, (req, res) => {
  const rows = db
    .prepare("SELECT * FROM events WHERE is_banner = 1 AND status IN ('published','live') ORDER BY datetime(start_date_time) ASC")
    .all();
  return ok(res, rows.map((r) => serializeEvent(r, { currentUserId: req.user?.id })));
});

// GET /api/featured-artists
router.get('/featured-artists', (req, res) => {
  const rows = db.prepare('SELECT * FROM users WHERE is_featured = 1 AND is_artist = 1').all();
  return ok(res, rows.map((u) => serializeUser(u)));
});

// GET /api/artist/:id/events
router.get('/artist/:id/events', optionalAuth, (req, res) => {
  const rows = db
    .prepare('SELECT * FROM events WHERE artist_id = ? ORDER BY datetime(start_date_time) DESC')
    .all(req.params.id);
  return ok(res, rows.map((r) => serializeEvent(r, { currentUserId: req.user?.id })));
});

// POST /api/events  (multipart: cover_image, video_reel) — création d'un
// concert par l'artiste connecté (formulaire "Créer un event" côté app).
// artist_id vient TOUJOURS du token (req.user.id), jamais du user_id envoyé
// par le client, pour qu'un user ne puisse pas créer un event au nom d'un autre.
router.post('/events', requireAuth, async (req, res) => {
  const b = req.body || {};
  if (!b.name) return fail(res, 'Le nom est requis.', 422, { name: ['Le nom est requis.'] });

  // Modération texte du titre + description avant création (bloque le grave).
  const textVerdict = await moderation.reviewText(
    [b.name, b.description].filter(Boolean).join('\n'),
    { targetType: 'event', targetId: null }
  );
  if (textVerdict.action === 'block') {
    return fail(res, 'Le titre ou la description enfreint les règles de la communauté.', 422);
  }

  const cover = saveUpload(req, ['cover_image', 'cover'], 'covers', 'events/covers');
  const videoReel = saveUpload(req, ['video_reel', 'visual_video'], 'videos', 'events/videos');

  // Replay : activé par défaut (le concert est rejouable), durée par défaut 60j
  // (fenêtre de hold Apple). L'artiste peut désactiver ou raccourcir depuis le
  // formulaire ; l'admin peut aussi ajuster ensuite.
  const replayEnabled = (b.replay_enabled === '0' || b.replay_enabled === false || b.replay_enabled === 0) ? 0 : 1;
  let replayDays = parseInt(b.replay_duration_days, 10);
  if (!Number.isFinite(replayDays) || replayDays < 1) replayDays = 60;
  if (replayDays > 60) replayDays = 60; // plafond = fenêtre de hold Apple

  const info = db.prepare(
    `INSERT INTO events (artist_id, name, cover_image, ticket_price, start_date_time, end_date_time,
        genre_id, description, video_reel, is_private, has_live_chat, replay_enabled, replay_duration_days, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'published')`
  ).run(
    req.user.id, b.name, cover, b.ticket_price || '0', b.start_date_time || null, b.end_date_time || null,
    b.genre_id || null, b.description || null, videoReel,
    (b.is_private === '1' || b.is_private === true) ? 1 : 0,
    b.has_live_chat === '0' ? 0 : 1,
    replayEnabled, replayDays
  );

  const created = db.prepare('SELECT * FROM events WHERE id = ?').get(info.lastInsertRowid);

  // Modération de la cover (image) + du teaser (vidéo) en tâche de fond : on ne
  // ralentit pas la création. Sur blocage, l'event passe en 'blocked' (masqué).
  const blockEvent = () =>
    db.prepare("UPDATE events SET status = 'blocked' WHERE id = ?").run(created.id);
  if (cover) moderation.moderateImage({ url: cover, targetType: 'event', targetId: created.id, onBlock: blockEvent });
  if (videoReel) moderation.moderateVideo({ url: videoReel, targetType: 'event', targetId: created.id });

  return ok(res, serializeEvent(created, { currentUserId: req.user.id }));
});

// POST /api/buy-ticket  (body: { event_id, user_id })
// Modèle hybride : le BILLET est payé par ACHAT IAP DIRECT (RevenueCat, un
// produit ticket_XX par palier de prix). L'app effectue l'achat (validé par
// RevenueCat côté Apple), puis appelle cet endpoint pour ENREGISTRER l'accès
// au concert. Pas de points ici (les points servent uniquement aux tips).
// NOTE sécurité (MVP) : on fait confiance à l'appel après un achat IAP réussi ;
// à durcir plus tard via vérification du reçu côté serveur (API RevenueCat).
// price_paid est stocké en EUROS (le revenu artiste se calcule depuis tickets).
router.post('/buy-ticket', optionalAuth, (req, res) => {
  const b = req.body || {};
  // Identité = JWT uniquement. On n'accepte JAMAIS un user_id du corps : sinon
  // n'importe qui pourrait s'octroyer (ou octroyer à autrui) un billet gratuit
  // et fabriquer du revenu artiste (price_paid). Le client loggé envoie le
  // Bearer token sur toutes ses requêtes (api_services.dart).
  const userId = req.user?.id;
  if (!userId) return fail(res, 'Authentification requise.', 401);

  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(b.event_id);
  if (!event) return fail(res, 'Event not found.', 404);

  // Déjà acheté -> idempotent.
  const already = db
    .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
    .get(b.event_id, userId);
  if (already) {
    return ok(res, serializeEvent(event, { currentUserId: userId }));
  }

  // Split commission — modèle NET (voir APPORTEURS.md). On divise ce qu'on
  // reçoit RÉELLEMENT après la commission store (Apple/Google ~15%), jamais le
  // brut. La part artiste dépend de sa phase (promo 3 mois = 50%, sinon son
  // offre). Si l'artiste a un apporteur éligible, sa commission (sur la part
  // plateforme) est enregistrée en 'due' — payable après encaissement + facture.
  const gross = parseFloat(event.ticket_price) || 0;
  const { ctx, artistRatePct, apporteurRatePct, breakdown } =
    apporteurLedger.computeForSale(event.artist_id, gross);
  const grant = db.transaction(() => {
    const info = db.prepare(
      `INSERT INTO tickets (event_id, user_id, price_paid, receipt_number, status, commission_rate, artist_share)
       VALUES (?, ?, ?, ?, 'active', ?, ?)`
    ).run(b.event_id, userId, String(event.ticket_price || '0'), genReceipt(), artistRatePct, breakdown.artist.toFixed(2));
    db.prepare(
      `INSERT INTO activities (user_id, event_id, type, description)
       VALUES (?, ?, 'ticket', 'bought a ticket')`
    ).run(userId, b.event_id);
    if (event.artist_id) {
      const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(event.artist_id);
      const newWallet = ((parseFloat(artist?.wallet) || 0) + breakdown.artist).toFixed(2);
      db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(newWallet, event.artist_id);
      db.prepare(
        `INSERT INTO platform_earnings
           (artist_id, source, source_id, gross, artist_share, platform_share, commission_rate, store_fee, net, apporteur_id, apporteur_amount)
         VALUES (?, 'ticket', ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(
        event.artist_id, info.lastInsertRowid, breakdown.gross.toFixed(2),
        breakdown.artist.toFixed(2), breakdown.platform.toFixed(2), artistRatePct,
        breakdown.store.toFixed(2), breakdown.net.toFixed(2),
        ctx.eligible ? ctx.apporteurId : null,
        ctx.eligible ? breakdown.apporteur.toFixed(2) : null,
      );
      if (ctx.eligible && apporteurRatePct > 0) {
        apporteurLedger.recordApporteurCommission({
          apporteurId: ctx.apporteurId, artistId: event.artist_id,
          sourceType: 'ticket', sourceId: info.lastInsertRowid,
          breakdown, rate: apporteurRatePct,
        });
      }
    }
  });
  grant();

  const fresh = db.prepare('SELECT * FROM events WHERE id = ?').get(b.event_id);
  return ok(res, serializeEvent(fresh, { currentUserId: userId }));
});

// POST /api/user-event-history  (body: { user_id })  -> { status, list: [...] }
router.post('/user-event-history', optionalAuth, (req, res) => {
  const userId = req.user?.id || req.body?.user_id;
  const rows = db
    .prepare(
      `SELECT DISTINCT e.* FROM events e
       JOIN tickets t ON t.event_id = e.id
       WHERE t.user_id = ?
       ORDER BY datetime(e.start_date_time) ASC`
    )
    .all(userId);
  return res.json({
    status: 'success',
    list: rows.map((r) => serializeEvent(r, { currentUserId: userId })),
  });
});

// POST /api/event-comment  (body: { event_id, user_id, comment }) -> { status, activity: [...] }
router.post('/event-comment', optionalAuth, async (req, res) => {
  const b = req.body || {};
  const userId = req.user?.id;
  if (!userId) return fail(res, 'Authentification requise.', 401);

  // Modération du message de chat AVANT affichage (Sightengine, temps réel).
  // 'block' -> refusé ; 'review'/'allow' -> passe (le 'review' est déjà journalisé).
  const verdict = await moderation.reviewText(b.comment || '', { targetType: 'comment', targetId: b.event_id });
  if (verdict.action === 'block') {
    return fail(res, 'Ton message enfreint les règles de la communauté.', 422);
  }

  db.prepare(
    `INSERT INTO activities (user_id, event_id, type, description)
     VALUES (?, ?, 'comment', ?)`
  ).run(userId, b.event_id, b.comment || '');
  const activity = db
    .prepare('SELECT * FROM activities WHERE event_id = ? ORDER BY id DESC LIMIT 50')
    .all(b.event_id)
    .map(serializeActivity);
  return res.json({ status: 'success', activity });
});

// POST /api/event-logs  (body: { event_id }) -> { status, activity: [...] }
router.post('/event-logs', (req, res) => {
  const activity = db
    .prepare('SELECT * FROM activities WHERE event_id = ? ORDER BY id DESC LIMIT 100')
    .all(req.body?.event_id)
    .map(serializeActivity);
  return res.json({ status: 'success', activity });
});

// POST /api/events/update/:id  (body: { status })
router.post('/events/update/:id', (req, res) => {
  const status = req.body?.status;
  db.prepare("UPDATE events SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .run(status, req.params.id);
  // Passage EN DIRECT -> déclenche (idempotent) la prime Pionnier de l'apporteur
  // + le départ des 24 mois de commission au premier live (contrat Amandine).
  if (status === 'live') {
    const ev = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(req.params.id);
    if (ev?.artist_id) { try { apporteurBonus.onFirstLive(ev.artist_id); } catch (e) { console.error('[apporteur onFirstLive]', e.message); } }
  }
  return res.json({ status: 'success', message: 'Event updated.' });
});

// POST /api/report-event — signalement utilisateur (exigence Apple 1.2). Avant,
// ce endpoint ne persistait RIEN. Désormais on enregistre un vrai signalement
// dans content_reports (file consultable/actionnable côté admin).
router.post('/report-event', optionalAuth, (req, res) => {
  const b = req.body || {};
  const targetType = b.target_type || (b.user_id && !b.event_id ? 'user' : 'event');
  const targetId = b.event_id || b.target_id || b.reported_user_id || b.user_id || null;
  db.prepare(
    `INSERT INTO content_reports (reporter_id, target_type, target_id, reason, details)
     VALUES (?, ?, ?, ?, ?)`
  ).run(req.user?.id || null, targetType, targetId != null ? String(targetId) : null,
    b.reason || b.type || 'other', b.details || b.message || b.description || null);
  return res.json({ status: 'success', message: 'Report received.' });
});

// POST /api/apporteur/report — un artiste signale SON apporteur (harcèlement,
// nuisance). Suspend AUTOMATIQUEMENT la commission de l'apporteur sur cet
// artiste. La suspension ne peut venir QUE d'ici (trace) — jamais d'une action
// manuelle sans trace. L'artiste reste sur la plateforme ; seule la commission
// est gelée (voir services/apporteur_ledger.js).
router.post('/apporteur/report', requireAuth, (req, res) => {
  const u = db.prepare('SELECT apporteur_id FROM users WHERE id = ?').get(req.user.id);
  if (!u || !u.apporteur_id) return fail(res, "Aucun apporteur rattaché à ton compte.", 422);
  db.prepare('INSERT INTO apporteur_reports (artist_id, apporteur_id, reason) VALUES (?, ?, ?)')
    .run(req.user.id, u.apporteur_id, String(req.body?.reason || '').slice(0, 500));
  return res.json({ status: 'success', message: 'Signalement enregistré. La commission de ton apporteur est suspendue.' });
});

// ─── Gifts ───
// GET /api/gifts -> { status, data: [...] }
router.get('/gifts', (req, res) => {
  const rows = db.prepare('SELECT * FROM gifts').all();
  return ok(res, rows);
});

// POST /api/event-gift  (body: { event_id, user_id, gift_id }) -> { status, activity: [...] }
// Envoi d'un cadeau/tip EN POINTS : déduit le coût du portefeuille du fan,
// crédite l'artiste, refuse si solde insuffisant (transaction atomique).
router.post('/event-gift', optionalAuth, (req, res) => {
  const b = req.body || {};
  // Identité = JWT uniquement. Accepter un user_id du corps permettrait de
  // débiter les points d'un autre utilisateur (vol) vers le wallet d'un artiste.
  const userId = req.user?.id;
  if (!userId) return fail(res, 'Authentification requise.', 401);

  const gift = db.prepare('SELECT * FROM gifts WHERE id = ?').get(b.gift_id);
  if (!gift) return fail(res, 'Cadeau introuvable.', 404);
  const event = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(b.event_id);

  const cost = Math.round(parseFloat(gift.points) || 0);
  const sender = db.prepare('SELECT points FROM users WHERE id = ?').get(userId);
  const balance = parseFloat(sender?.points) || 0;
  if (balance < cost) {
    return fail(res, 'Points insuffisants. Rechargez votre portefeuille.', 402, {
      required: cost,
      balance,
    });
  }

  // Split commission (cadeau en POINTS) : l'artiste reçoit sa part, le reste va
  // à la plateforme (tracé dans platform_earnings). Taux depuis son abonnement.
  const rate = resolveArtistCommission(event?.artist_id);
  const { artistShare, platformShare } = splitAmount(cost, rate);
  const send = db.transaction(() => {
    if (cost > 0) {
      db.prepare('UPDATE users SET points = ? WHERE id = ?').run((balance - cost).toFixed(2), userId);
      if (event?.artist_id) {
        const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(event.artist_id);
        const artistWallet = (parseFloat(artist?.wallet) || 0) + artistShare;
        db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(artistWallet.toFixed(2), event.artist_id);
        db.prepare(
          `INSERT INTO platform_earnings (artist_id, source, source_id, gross, artist_share, platform_share, commission_rate)
           VALUES (?, 'gift', ?, ?, ?, ?, ?)`
        ).run(event.artist_id, b.event_id, String(cost), artistShare.toFixed(2), platformShare.toFixed(2), rate);
      }
    }
    db.prepare(
      `INSERT INTO activities (user_id, event_id, type, description, gift, points)
       VALUES (?, ?, 'gift', ?, ?, ?)`
    ).run(userId, b.event_id, gift.name || 'gift', gift.image || null, String(cost));
  });
  send();

  const activity = db
    .prepare('SELECT * FROM activities WHERE event_id = ? ORDER BY id DESC LIMIT 50')
    .all(b.event_id)
    .map(serializeActivity);
  return res.json({ status: 'success', activity });
});

// ─── Follow ───
router.post('/follow', optionalAuth, (req, res) => {
  const b = req.body || {};
  const me = req.user?.id;
  if (!me) return fail(res, 'Authentification requise.', 401);
  db.prepare('INSERT OR IGNORE INTO follows (follower_id, artist_id) VALUES (?, ?)').run(me, b.artist_id);
  return res.json({ status: 'success', message: 'Followed.' });
});

router.post('/unfollow', optionalAuth, (req, res) => {
  const b = req.body || {};
  const me = req.user?.id;
  if (!me) return fail(res, 'Authentification requise.', 401);
  db.prepare('DELETE FROM follows WHERE follower_id = ? AND artist_id = ?').run(me, b.artist_id);
  return res.json({ status: 'success', message: 'Unfollowed.' });
});

// GET /api/followers/:id
router.get('/followers/:id', (req, res) => {
  const rows = db
    .prepare('SELECT u.* FROM users u JOIN follows f ON f.follower_id = u.id WHERE f.artist_id = ?')
    .all(req.params.id);
  return ok(res, rows.map((u) => serializeUser(u)));
});

function serializeActivity(row) {
  return {
    id: row.id,
    user_id: row.user_id,
    event_id: row.event_id,
    type: row.type,
    description: row.description,
    points: row.points,
    gift: row.gift,
    user_info: row.user_id
      ? serializeUser(db.prepare('SELECT * FROM users WHERE id = ?').get(row.user_id))
      : null,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

module.exports = router;

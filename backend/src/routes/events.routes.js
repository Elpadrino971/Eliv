'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { serializeEvent, serializeUser, ok, fail, genReceipt } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');
const { saveUpload } = require('../uploads');

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
router.post('/events', requireAuth, (req, res) => {
  const b = req.body || {};
  if (!b.name) return fail(res, 'Le nom est requis.', 422, { name: ['Le nom est requis.'] });

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
  return ok(res, serializeEvent(created, { currentUserId: req.user.id }));
});

// POST /api/buy-ticket  (body: { event_id, user_id })
// Achat de billet EN POINTS (monnaie interne, conforme Apple : l'argent réel
// entre via la recharge IAP RevenueCat, pas ici). Déduit réellement les points
// de l'acheteur, crédite le portefeuille de l'artiste, refuse si solde
// insuffisant — le tout en transaction atomique.
router.post('/buy-ticket', optionalAuth, (req, res) => {
  const b = req.body || {};
  const userId = req.user?.id || b.user_id;
  if (!userId) return fail(res, 'Authentification requise.', 401);

  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(b.event_id);
  if (!event) return fail(res, 'Event not found.', 404);

  // Déjà acheté -> idempotent, aucun nouveau débit.
  const already = db
    .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
    .get(b.event_id, userId);
  if (already) {
    return ok(res, serializeEvent(event, { currentUserId: userId }));
  }

  const buyer = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!buyer) return fail(res, 'Utilisateur introuvable.', 404);

  // Le prix du billet est saisi en EUROS par l'artiste ; l'acheteur paie en
  // POINTS (monnaie interne). Ratio : 1 € = 100 points (1 point = 1 centime).
  const POINTS_PER_EURO = 100;
  const price = Math.round((parseFloat(event.ticket_price) || 0) * POINTS_PER_EURO);
  const balance = parseFloat(buyer.points) || 0;
  if (balance < price) {
    return fail(res, 'Points insuffisants. Rechargez votre portefeuille.', 402, {
      required: price,
      balance,
    });
  }

  const buy = db.transaction(() => {
    // Débit acheteur
    const newBalance = (balance - price).toFixed(2);
    db.prepare('UPDATE users SET points = ? WHERE id = ?').run(newBalance, userId);
    // Crédit artiste (revenu du concert)
    if (event.artist_id) {
      const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(event.artist_id);
      const artistWallet = (parseFloat(artist?.wallet) || 0) + price;
      db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(artistWallet.toFixed(2), event.artist_id);
    }
    db.prepare(
      `INSERT INTO tickets (event_id, user_id, price_paid, receipt_number, status)
       VALUES (?, ?, ?, ?, 'active')`
    ).run(b.event_id, userId, String(price), genReceipt());
    db.prepare(
      `INSERT INTO activities (user_id, event_id, type, description)
       VALUES (?, ?, 'ticket', 'bought a ticket')`
    ).run(userId, b.event_id);
    return newBalance;
  });

  const newBalance = buy();
  const fresh = db.prepare('SELECT * FROM events WHERE id = ?').get(b.event_id);
  const payload = serializeEvent(fresh, { currentUserId: userId });
  // Solde restant renvoyé pour que l'app rafraîchisse le portefeuille.
  return ok(res, { ...payload, buyer_points: newBalance });
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
router.post('/event-comment', optionalAuth, (req, res) => {
  const b = req.body || {};
  const userId = req.user?.id || b.user_id;
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
  db.prepare("UPDATE events SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .run(req.body?.status, req.params.id);
  return res.json({ status: 'success', message: 'Event updated.' });
});

// POST /api/report-event
router.post('/report-event', (req, res) => {
  return res.json({ status: 'success', message: 'Report received.' });
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
  const userId = req.user?.id || b.user_id;
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

  const send = db.transaction(() => {
    if (cost > 0) {
      db.prepare('UPDATE users SET points = ? WHERE id = ?').run((balance - cost).toFixed(2), userId);
      if (event?.artist_id) {
        const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(event.artist_id);
        const artistWallet = (parseFloat(artist?.wallet) || 0) + cost;
        db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(artistWallet.toFixed(2), event.artist_id);
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
  const me = req.user?.id || b.user_id;
  db.prepare('INSERT OR IGNORE INTO follows (follower_id, artist_id) VALUES (?, ?)').run(me, b.artist_id);
  return res.json({ status: 'success', message: 'Followed.' });
});

router.post('/unfollow', optionalAuth, (req, res) => {
  const b = req.body || {};
  const me = req.user?.id || b.user_id;
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

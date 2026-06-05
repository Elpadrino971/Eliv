'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { serializeEvent, serializeUser, ok, fail, genReceipt } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');

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

// POST /api/buy-ticket  (body: { event_id, user_id })
router.post('/buy-ticket', optionalAuth, (req, res) => {
  const b = req.body || {};
  const userId = req.user?.id || b.user_id;
  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(b.event_id);
  if (!event) return fail(res, 'Event not found.', 404);

  const already = db
    .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
    .get(b.event_id, userId);
  if (already) {
    return ok(res, serializeEvent(event, { currentUserId: userId }));
  }

  db.prepare(
    `INSERT INTO tickets (event_id, user_id, price_paid, receipt_number, status)
     VALUES (?, ?, ?, ?, 'active')`
  ).run(b.event_id, userId, event.ticket_price, genReceipt());

  db.prepare(
    `INSERT INTO activities (user_id, event_id, type, description)
     VALUES (?, ?, 'ticket', 'bought a ticket')`
  ).run(userId, b.event_id);

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
router.post('/event-gift', optionalAuth, (req, res) => {
  const b = req.body || {};
  const userId = req.user?.id || b.user_id;
  const gift = db.prepare('SELECT * FROM gifts WHERE id = ?').get(b.gift_id);
  db.prepare(
    `INSERT INTO activities (user_id, event_id, type, description, gift, points)
     VALUES (?, ?, 'gift', ?, ?, ?)`
  ).run(userId, b.event_id, gift?.name || 'gift', gift?.image || null, gift?.points || '0');
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

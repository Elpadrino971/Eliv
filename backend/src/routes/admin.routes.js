'use strict';

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { db } = require('../db');
const { hash, compare, SECRET } = require('../auth');

/** Auth admin : exige un token dont le user a role='admin'. */
function requireAdmin(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ status: 'error', message: 'Unauthenticated.' });
  try {
    const payload = jwt.verify(token, SECRET);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.id);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ status: 'error', message: 'Admin only.' });
    }
    req.admin = user;
    next();
  } catch (e) {
    return res.status(401).json({ status: 'error', message: 'Invalid token.' });
  }
}

// POST /api/admin/login
router.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get((email || '').toLowerCase());
  if (!user || user.role !== 'admin' || !compare(password, user.password)) {
    return res.status(401).json({ status: 'error', message: 'Identifiants admin invalides.' });
  }
  const token = jwt.sign({ id: user.id, email: user.email }, SECRET, { expiresIn: '7d' });
  return res.json({
    status: 'success',
    token,
    admin: { id: user.id, email: user.email, full_name: user.full_name },
  });
});

// GET /api/admin/stats
router.get('/stats', requireAdmin, (req, res) => {
  const users = db.prepare('SELECT COUNT(*) c FROM users WHERE role != ?').get('admin').c;
  const events = db.prepare('SELECT COUNT(*) c FROM events').get().c;
  const packages = db.prepare('SELECT COUNT(*) c FROM packages').get().c;
  const revenueRow = db.prepare("SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets").get();
  return res.json({
    status: 'success',
    data: {
      total_users: users,
      total_events: events,
      total_packages: packages,
      total_revenue: Math.round(revenueRow.r),
    },
  });
});

// GET /api/admin/users?type=all|user|artist&search=
router.get('/users', requireAdmin, (req, res) => {
  const { type, search } = req.query;
  let sql = "SELECT * FROM users WHERE role != 'admin'";
  const params = [];
  if (type === 'user') sql += ' AND is_artist = 0';
  if (type === 'artist') sql += ' AND is_artist = 1';
  if (search) {
    sql += ' AND (full_name LIKE ? OR email LIKE ?)';
    params.push(`%${search}%`, `%${search}%`);
  }
  sql += ' ORDER BY id DESC';
  const rows = db.prepare(sql).all(...params).map((u) => ({
    id: u.id, full_name: u.full_name, email: u.email, phone_number: u.phone_number,
    address: u.address, status: u.status, is_artist: !!u.is_artist,
    profile_image: u.profile_image, created_at: u.created_at,
  }));
  const counts = {
    all: db.prepare("SELECT COUNT(*) c FROM users WHERE role != 'admin'").get().c,
    user: db.prepare("SELECT COUNT(*) c FROM users WHERE role != 'admin' AND is_artist = 0").get().c,
    artist: db.prepare("SELECT COUNT(*) c FROM users WHERE is_artist = 1").get().c,
  };
  return res.json({ status: 'success', data: rows, counts });
});

// POST /api/admin/users  (add)
router.post('/users', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.email) return res.status(422).json({ status: 'error', message: 'Email requis.' });
  const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(b.email.toLowerCase());
  if (exists) return res.status(422).json({ status: 'error', message: 'Email déjà utilisé.' });
  db.prepare(
    `INSERT INTO users (email, password, full_name, is_artist, status, registration_type, role)
     VALUES (?, ?, ?, ?, 'active', 'email', ?)`
  ).run(
    b.email.toLowerCase(), hash(b.password || 'password'), b.full_name || null,
    b.is_artist ? 1 : 0, b.is_artist ? 'artist' : 'user'
  );
  return res.json({ status: 'success', message: 'Utilisateur créé.' });
});

// POST /api/admin/users/:id/status
router.post('/users/:id/status', requireAdmin, (req, res) => {
  const status = req.body?.status || 'active';
  db.prepare("UPDATE users SET status = ? WHERE id = ?").run(status, req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});

// DELETE /api/admin/users/:id
router.delete('/users/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM users WHERE id = ? AND role != ?').run(req.params.id, 'admin');
  return res.json({ status: 'success', message: 'Utilisateur supprimé.' });
});

// ─── Genres CRUD ───
router.get('/genres', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM genres ORDER BY id').all() });
});
router.post('/genres', requireAdmin, (req, res) => {
  if (!req.body?.name) return res.status(422).json({ status: 'error', message: 'Nom requis.' });
  db.prepare('INSERT INTO genres (name) VALUES (?)').run(req.body.name);
  return res.json({ status: 'success', message: 'Genre ajouté.' });
});
router.put('/genres/:id', requireAdmin, (req, res) => {
  db.prepare("UPDATE genres SET name = ?, updated_at = datetime('now') WHERE id = ?").run(req.body?.name, req.params.id);
  return res.json({ status: 'success', message: 'Genre modifié.' });
});
router.delete('/genres/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM genres WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Genre supprimé.' });
});

// ─── User Genres ───
router.get('/user-genres', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT ug.user_id, ug.genre_id, u.full_name, u.email, u.profile_image, g.name AS genre, u.created_at
     FROM user_genres ug
     JOIN users u ON u.id = ug.user_id
     JOIN genres g ON g.id = ug.genre_id
     ORDER BY ug.user_id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Events ───
router.get('/events', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT e.id, e.name, e.status, e.ticket_price, e.start_date_time, e.likes_count,
            u.artist_name AS artist
     FROM events e LEFT JOIN users u ON u.id = e.artist_id
     ORDER BY e.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.delete('/events/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM events WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Event supprimé.' });
});

// ─── Packages ───
router.get('/packages', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM packages ORDER BY id').all() });
});
router.post('/packages', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('INSERT INTO packages (name, points, price) VALUES (?, ?, ?)').run(b.name, b.points || '0', b.price || '0');
  return res.json({ status: 'success', message: 'Package ajouté.' });
});
router.delete('/packages/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM packages WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Package supprimé.' });
});

// ─── Subscriptions ───
router.get('/subscriptions', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM subscriptions ORDER BY id').all() });
});

// ─── Reviews ───
router.get('/reviews', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.full_name AS user, u.email, e.name AS event
     FROM reviews r LEFT JOIN users u ON u.id = r.user_id LEFT JOIN events e ON e.id = r.event_id
     ORDER BY r.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.delete('/reviews/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM reviews WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Avis supprimé.' });
});

// ─── Withdrawals ───
router.get('/withdrawals', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT w.id, w.amount, w.status, w.bank, w.created_at, u.full_name AS user, u.artist_name, u.email
     FROM withdrawals w LEFT JOIN users u ON u.id = w.user_id ORDER BY w.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/withdrawals/:id/status', requireAdmin, (req, res) => {
  db.prepare('UPDATE withdrawals SET status = ? WHERE id = ?').run(req.body?.status || 'approved', req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});

// ─── Reports (agrégats) ───
router.get('/reports', requireAdmin, (req, res) => {
  const revenue = Math.round(db.prepare('SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets').get().r);
  const ticketsSold = db.prepare('SELECT COUNT(*) c FROM tickets').get().c;
  const topEvents = db.prepare(
    `SELECT e.name, COUNT(t.id) AS sales FROM events e
     LEFT JOIN tickets t ON t.event_id = e.id GROUP BY e.id ORDER BY sales DESC LIMIT 5`
  ).all();
  const byGenre = db.prepare(
    `SELECT g.name, COUNT(e.id) AS events FROM genres g
     LEFT JOIN events e ON e.genre_id = g.id GROUP BY g.id ORDER BY events DESC`
  ).all();
  return res.json({ status: 'success', data: { revenue, tickets_sold: ticketsSold, top_events: topEvents, by_genre: byGenre } });
});

// ─── Contact Leads ───
router.get('/contact-leads', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM contact_leads ORDER BY id DESC').all() });
});
router.delete('/contact-leads/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM contact_leads WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Lead supprimé.' });
});

// ─── FAQ (CRUD) ───
router.get('/faqs', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM faqs ORDER BY id').all() });
});
router.post('/faqs', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('INSERT INTO faqs (question, answer) VALUES (?, ?)').run(b.question, b.answer);
  return res.json({ status: 'success', message: 'FAQ ajoutée.' });
});
router.put('/faqs/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE faqs SET question = ?, answer = ? WHERE id = ?').run(b.question, b.answer, req.params.id);
  return res.json({ status: 'success', message: 'FAQ modifiée.' });
});
router.delete('/faqs/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM faqs WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'FAQ supprimée.' });
});

// ─── CMS ───
router.get('/cms', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM cms_pages').all() });
});
router.put('/cms/:slug', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare(
    "INSERT INTO cms_pages (slug, title, content, updated_at) VALUES (?, ?, ?, datetime('now')) \
     ON CONFLICT(slug) DO UPDATE SET title = excluded.title, content = excluded.content, updated_at = datetime('now')"
  ).run(req.params.slug, b.title || '', b.content || '');
  return res.json({ status: 'success', message: 'Page CMS enregistrée.' });
});

// ─── Profile (admin courant) ───
router.get('/profile', requireAdmin, (req, res) => {
  const a = req.admin;
  return res.json({ status: 'success', data: { id: a.id, full_name: a.full_name, email: a.email, role: a.role } });
});
router.post('/profile', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (b.full_name) db.prepare('UPDATE users SET full_name = ? WHERE id = ?').run(b.full_name, req.admin.id);
  if (b.password) {
    db.prepare('UPDATE users SET password = ? WHERE id = ?').run(hash(b.password), req.admin.id);
  }
  return res.json({ status: 'success', message: 'Profil mis à jour.' });
});

// ─── Transactions (tickets) ───
router.get('/transactions', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT t.id, t.receipt_number, t.price_paid, t.status, t.created_at,
            u.full_name AS user, u.email, e.name AS event
     FROM tickets t
     LEFT JOIN users u ON u.id = t.user_id
     LEFT JOIN events e ON e.id = t.event_id
     ORDER BY t.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Abusive words ───
router.get('/abusive', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM abusive_words ORDER BY id').all() });
});
router.post('/abusive', requireAdmin, (req, res) => {
  if (req.body?.word) db.prepare('INSERT INTO abusive_words (word) VALUES (?)').run(req.body.word);
  return res.json({ status: 'success', message: 'Mot ajouté.' });
});
router.delete('/abusive/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM abusive_words WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Supprimé.' });
});

module.exports = router;

'use strict';

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { db } = require('../db');
const { hash, compare, SECRET } = require('../auth');
const { saveUpload } = require('../uploads');
const truthy = (v) => v === true || v === 1 || v === '1' || v === 'true' || v === 'on';

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
  const fans = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'user' AND is_artist = 0").get().c;
  const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE is_artist = 1').get().c;
  const events = db.prepare('SELECT COUNT(*) c FROM events').get().c;
  const packages = db.prepare('SELECT COUNT(*) c FROM packages').get().c;
  const referrals = db.prepare("SELECT COUNT(*) c FROM referrals WHERE status = 'validated'").get().c;
  const revenueRow = db.prepare("SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets").get();
  return res.json({
    status: 'success',
    data: {
      total_users: fans,
      total_artists: artists,
      total_events: events,
      total_packages: packages,
      total_referrals: referrals,
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
    id: u.id, full_name: u.full_name, artist_name: u.artist_name, email: u.email, phone_number: u.phone_number,
    address: u.address, status: u.status, is_artist: !!u.is_artist,
    profile_image: u.artist_profile || u.profile_image, created_at: u.created_at,
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

// ─── Events (CRUD complet + vidéo Mux) ───
const muxHls = (id) => (id ? `https://stream.mux.com/${id}.m3u8` : null);

router.get('/events', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT e.id, e.name, e.status, e.ticket_price, e.start_date_time, e.likes_count,
            e.artist_id, e.genre_id, e.description, e.cover_image, e.mux_playback_id,
            e.is_banner, u.artist_name AS artist
     FROM events e LEFT JOIN users u ON u.id = e.artist_id
     ORDER BY e.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// Liste des artistes (pour le menu déroulant du formulaire event)
router.get('/artists-list', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT id, COALESCE(artist_name, full_name, email) AS name FROM users WHERE is_artist = 1 ORDER BY name"
  ).all();
  return res.json({ status: 'success', data: rows });
});

router.post('/events', requireAdmin, (req, res) => {
  const b = req.body || {};
  const cover = saveUpload(req, ['cover', 'cover_image', 'image'], 'covers', 'events/covers') || b.cover_image || null;
  if (!b.name) return res.status(422).json({ status: 'error', message: 'Le nom est requis.' });
  db.prepare(
    `INSERT INTO events (artist_id, name, cover_image, ticket_price, start_date_time, genre_id,
        description, status, mux_playback_id, mux_live_playback_id, video_reel, is_banner)
     VALUES (@artist_id, @name, @cover, @price, @start, @genre, @desc, @status, @mux, @muxLive, @reel, @banner)`
  ).run({
    artist_id: b.artist_id || null, name: b.name, cover,
    price: b.ticket_price || '0', start: b.start_date_time || null, genre: b.genre_id || null,
    desc: b.description || null, status: b.status || 'published',
    mux: b.mux_playback_id || null, muxLive: b.status === 'live' ? (b.mux_playback_id || null) : null,
    reel: muxHls(b.mux_playback_id), banner: b.is_banner ? 1 : 0,
  });
  return res.json({ status: 'success', message: 'Concert créé.' });
});

router.put('/events/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  const cover = saveUpload(req, ['cover', 'cover_image', 'image'], 'covers', 'events/covers') || b.cover_image || null;
  db.prepare(
    `UPDATE events SET artist_id = @artist_id, name = @name, cover_image = @cover,
        ticket_price = @price, start_date_time = @start, genre_id = @genre, description = @desc,
        status = @status, mux_playback_id = @mux, mux_live_playback_id = @muxLive,
        video_reel = @reel, is_banner = @banner, updated_at = datetime('now')
     WHERE id = @id`
  ).run({
    id: req.params.id, artist_id: b.artist_id || null, name: b.name, cover,
    price: b.ticket_price || '0', start: b.start_date_time || null, genre: b.genre_id || null,
    desc: b.description || null, status: b.status || 'published',
    mux: b.mux_playback_id || null, muxLive: b.status === 'live' ? (b.mux_playback_id || null) : null,
    reel: muxHls(b.mux_playback_id), banner: b.is_banner ? 1 : 0,
  });
  return res.json({ status: 'success', message: 'Concert mis à jour.' });
});

router.delete('/events/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM events WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Concert supprimé.' });
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

// ─── Listes pour les menus déroulants ───
router.get('/users-list', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT id, COALESCE(full_name, artist_name, email) AS name FROM users WHERE role != 'admin' ORDER BY name"
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Édition Utilisateur ───
router.put('/users/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  // photo : sert d'avatar artiste (artist_profile) ET de photo profil (profile_image)
  const photo = saveUpload(req, ['photo', 'avatar', 'profile_picture', 'image'], 'profiles', 'profiles') || b.photo || b.artist_profile || null;
  db.prepare(
    `UPDATE users SET full_name = @full_name, artist_name = @artist_name, phone_number = @phone, address = @address,
        is_artist = @artist,
        artist_profile = COALESCE(@photo, artist_profile),
        profile_image = COALESCE(@photo, profile_image)
     WHERE id = @id`
  ).run({
    id: req.params.id, full_name: b.full_name || null, artist_name: b.artist_name || null, phone: b.phone_number || null,
    address: b.address || null, artist: truthy(b.is_artist) ? 1 : 0, photo,
  });
  return res.json({ status: 'success', message: 'Utilisateur modifié.' });
});

// ─── User Genres : ajout / suppression ───
router.post('/user-genres', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.user_id || !b.genre_id) return res.status(422).json({ status: 'error', message: 'Utilisateur et genre requis.' });
  db.prepare('INSERT OR IGNORE INTO user_genres (user_id, genre_id) VALUES (?, ?)').run(b.user_id, b.genre_id);
  return res.json({ status: 'success', message: 'Association ajoutée.' });
});
router.delete('/user-genres', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM user_genres WHERE user_id = ? AND genre_id = ?').run(req.query.user_id, req.query.genre_id);
  return res.json({ status: 'success', message: 'Association supprimée.' });
});

// ─── Packages : édition ───
router.put('/packages/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE packages SET name = ?, points = ?, price = ? WHERE id = ?').run(b.name, b.points || '0', b.price || '0', req.params.id);
  return res.json({ status: 'success', message: 'Package modifié.' });
});

// ─── Abonnements : CRUD ───
router.post('/subscriptions', requireAdmin, (req, res) => {
  const b = req.body || {};
  const image = saveUpload(req, ['image', 'photo'], 'covers', 'events/covers') || b.image || null;
  db.prepare('INSERT INTO subscriptions (name, tier, price, period, active, image, slot_from, slot_to) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    .run(b.name, b.tier || '', b.price || '0', b.period || 'month', b.active === undefined ? 1 : (truthy(b.active) ? 1 : 0), image, b.slot_from || null, b.slot_to || null);
  return res.json({ status: 'success', message: 'Abonnement ajouté.' });
});
router.put('/subscriptions/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  const image = saveUpload(req, ['image', 'photo'], 'covers', 'events/covers') || b.image || null;
  db.prepare(`UPDATE subscriptions SET name = ?, tier = ?, price = ?, period = ?, active = ?,
      image = COALESCE(?, image), slot_from = ?, slot_to = ? WHERE id = ?`)
    .run(b.name, b.tier, b.price, b.period, truthy(b.active) ? 1 : 0, image, b.slot_from || null, b.slot_to || null, req.params.id);
  return res.json({ status: 'success', message: 'Abonnement modifié.' });
});
router.delete('/subscriptions/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM subscriptions WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Abonnement supprimé.' });
});

// ─── Graphiques + Objectifs (Dashboard) ───
const MONTHS_FR = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
router.get('/chart-data', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT strftime('%Y-%m', created_at) m, COALESCE(SUM(CAST(price_paid AS REAL)),0) rev, COUNT(*) cnt FROM tickets GROUP BY m"
  ).all();
  const byMonth = Object.fromEntries(rows.map((r) => [r.m, r]));
  const now = new Date();
  const months = [];
  for (let i = 5; i >= 0; i--) months.push(new Date(now.getFullYear(), now.getMonth() - i, 1));
  const keys = months.map((d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  const labels = months.map((d) => MONTHS_FR[d.getMonth()]);
  const revenue = keys.map((k) => Math.round(byMonth[k]?.rev || 0));
  const tickets = keys.map((k) => byMonth[k]?.cnt || 0);

  const g = (k, def) => +(db.prepare('SELECT value v FROM settings WHERE key = ?').get(k)?.v || def);
  const totalRev = Math.round(db.prepare("SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets").get().r);
  const fans = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'user' AND is_artist = 0").get().c;
  const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE is_artist = 1').get().c;
  return res.json({
    status: 'success',
    data: {
      labels, revenue, tickets,
      goals: {
        revenue: { current: totalRev, target: g('goal_revenue', 50000) },
        users: { current: fans, target: g('goal_users', 500) },
        artists: { current: artists, target: g('goal_artists', 50) },
      },
    },
  });
});
router.put('/goals', requireAdmin, (req, res) => {
  const b = req.body || {};
  const set = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  ['goal_revenue', 'goal_users', 'goal_artists'].forEach((k) => { if (b[k] != null && b[k] !== '') set.run(k, String(b[k])); });
  return res.json({ status: 'success', message: 'Objectifs enregistrés.' });
});

// ─── Parrainage (10% par nouvel artiste parrainé, plafonné à 10/mois) ───
function refRule() {
  const rate = +(db.prepare("SELECT value v FROM settings WHERE key = 'referral_rate'").get()?.v || 10);
  const cap = +(db.prepare("SELECT value v FROM settings WHERE key = 'referral_monthly_cap'").get()?.v || 10);
  return { rate, cap };
}

router.get('/referrals', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT r.id, r.code, r.status, r.reward, r.created_at, r.referrer_id,
            COALESCE(ru.artist_name, ru.full_name, ru.email) AS referrer,
            COALESCE(re.full_name, re.email) AS referee, re.is_artist AS referee_is_artist
     FROM referrals r
     LEFT JOIN users ru ON ru.id = r.referrer_id
     LEFT JOIN users re ON re.id = r.referee_id
     ORDER BY r.id DESC`
  ).all();
  // Compteur du mois en cours par parrain (artistes validés uniquement)
  const month = new Date().toISOString().slice(0, 7);
  const monthly = {};
  for (const r of rows) {
    if (r.status === 'validated' && r.referee_is_artist && (r.created_at || '').slice(0, 7) === month) {
      monthly[r.referrer_id] = (monthly[r.referrer_id] || 0) + 1;
    }
  }
  return res.json({ status: 'success', data: rows, rule: refRule(), monthly });
});

router.put('/referral-settings', requireAdmin, (req, res) => {
  const b = req.body || {};
  const set = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  if (b.rate != null) set.run('referral_rate', String(b.rate));
  if (b.cap != null) set.run('referral_monthly_cap', String(b.cap));
  return res.json({ status: 'success', message: 'Règle de parrainage enregistrée.' });
});

router.post('/referrals', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.referrer_id || !b.referee_id) return res.status(422).json({ status: 'error', message: 'Parrain et filleul requis.' });
  if (b.referrer_id === b.referee_id) return res.status(422).json({ status: 'error', message: 'Un parrain ne peut pas se parrainer lui-même.' });
  const code = db.prepare('SELECT referral_code c FROM users WHERE id = ?').get(b.referrer_id)?.c || 'MANUEL';
  db.prepare("INSERT INTO referrals (code, referrer_id, referee_id, status, reward) VALUES (?, ?, ?, ?, ?)")
    .run(code, b.referrer_id, b.referee_id, b.status || 'validated', refRule().rate + '%');
  return res.json({ status: 'success', message: 'Parrainage ajouté.' });
});

router.post('/referrals/:id/validate', requireAdmin, (req, res) => {
  db.prepare("UPDATE referrals SET status = 'validated' WHERE id = ?").run(req.params.id);
  return res.json({ status: 'success', message: 'Parrainage validé.' });
});
router.delete('/referrals/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM referrals WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Parrainage supprimé.' });
});

// ─── Boîte à idées ───
router.get('/ideas', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT i.*, COALESCE(u.full_name, u.artist_name, i.name) AS author
     FROM ideas i LEFT JOIN users u ON u.id = i.user_id ORDER BY i.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/ideas/:id/status', requireAdmin, (req, res) => {
  db.prepare('UPDATE ideas SET status = ? WHERE id = ?').run(req.body?.status || 'reviewed', req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});
router.delete('/ideas/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM ideas WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Idée supprimée.' });
});

module.exports = router;

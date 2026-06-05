'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { ok, list, fail } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');

// GET /api/genres -> { status, data: [...] }
router.get('/genres', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM genres').all());
});

// GET /api/get-abusive-words -> { status, data: [...] }
router.get('/get-abusive-words', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM abusive_words').all());
});

// GET /api/settings/get-settings -> { status, data: {...} }
router.get('/settings/get-settings', (req, res) => {
  const rows = db.prepare('SELECT * FROM settings').all();
  const obj = {};
  for (const r of rows) obj[r.key] = r.value;
  return res.json({ status: 'success', data: obj });
});

// GET /api/settings/get-management -> { status, data: {...} }
router.get('/settings/get-management', (req, res) => {
  return res.json({
    status: 'success',
    data: {
      terms_url: 'https://vybzzz.com/terms',
      privacy_url: 'https://vybzzz.com/privacy',
      support_email: 'support@vybzzz.com',
    },
  });
});

// ─── Subscriptions (artistes) ───
router.get('/subscription/get', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM settings WHERE key LIKE \'plan_%\'').all());
});
router.post('/subscription/buy', optionalAuth, (req, res) => {
  return res.json({ status: 'success', message: 'Subscription recorded (demo).' });
});

// ─── Packages (points / gifts) ───
router.get('/packages/list', (req, res) => ok(res, []));
router.post('/packages/buy', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Package purchased (demo).' })
);

// ─── Transactions / Wallet ───
router.post('/get-transactions', optionalAuth, (req, res) => ok(res, []));

// ─── Artist statistics ───
router.post('/get-artist-statistics', optionalAuth, (req, res) => {
  return res.json({
    status: 'success',
    data: { followers: 0, events: 0, tickets_sold: 0, revenue: '0' },
  });
});
router.post('/get-event-stats-by-user-id', optionalAuth, (req, res) =>
  res.json({ status: 'success', data: { total_events: 0, total_tickets: 0 } })
);

// ─── Support ───
router.post('/support/get-subjects', (req, res) =>
  ok(res, [{ id: 1, name: 'General' }, { id: 2, name: 'Payment' }, { id: 3, name: 'Technical' }])
);
router.post('/support/get-list', optionalAuth, (req, res) => ok(res, []));
router.post('/support/create', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Ticket created.' })
);
router.post('/support/get-details', optionalAuth, (req, res) => ok(res, {}));
router.post('/support/resolve', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Resolved.' })
);
router.post('/support/store-meta', (req, res) => res.json({ status: 'success' }));

// ─── Bank / Withdraw ───
router.post('/withdraw/add-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank added.' })
);
router.post('/withdraw/get-user-banks', requireAuth, (req, res) => ok(res, []));
router.post('/withdraw/update-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank updated.' })
);
router.post('/withdraw/delete-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank deleted.' })
);
router.post('/withdraw/add', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Withdrawal requested.' })
);
router.get('/following', optionalAuth, (req, res) => ok(res, []));

// ═══════════════════════════════════════════════════════════════════════
// NOUVELLES FEATURES (docs/BACKEND_CHANGES.md) — ce qui manquait à Hammad
// ═══════════════════════════════════════════════════════════════════════

// GET /api/event/:id/access  -> état d'accès du user courant
router.get('/event/:id/access', requireAuth, (req, res) => {
  const eventId = req.params.id;
  const ticket = db
    .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
    .get(eventId, req.user.id);
  if (ticket) {
    return res.json({ status: 'success', has_access: true, access_type: 'ticket', expires_at: null });
  }
  const ghost = db
    .prepare("SELECT * FROM ghost_passes WHERE event_id = ? AND user_id = ? AND datetime(expires_at) > datetime('now') ORDER BY datetime(expires_at) DESC")
    .get(eventId, req.user.id);
  if (ghost) {
    return res.json({ status: 'success', has_access: true, access_type: 'ghost_pass', expires_at: ghost.expires_at });
  }
  return res.json({ status: 'success', has_access: false, access_type: 'none', expires_at: null });
});

// ─── Referral ───
router.post('/referral/generate', requireAuth, (req, res) => {
  let code = req.user.referral_code;
  if (!code) {
    code = `VYB${Math.floor(1000 + Math.random() * 9000)}`;
    db.prepare('UPDATE users SET referral_code = ? WHERE id = ?').run(code, req.user.id);
  }
  return res.json({ status: 'success', data: { code, link: `https://vybzzz.com/r/${code}` } });
});

router.get('/referral/me', requireAuth, (req, res) => {
  const rows = db.prepare('SELECT * FROM referrals WHERE referrer_id = ? ORDER BY id DESC').all(req.user.id);
  return ok(res, rows);
});

router.post('/referral/redeem', requireAuth, (req, res) => {
  const code = req.body?.code;
  const referrer = db.prepare('SELECT * FROM users WHERE referral_code = ?').get(code);
  if (!referrer) return fail(res, 'Invalid referral code.', 422);
  if (referrer.id === req.user.id) return fail(res, 'You cannot refer yourself.', 422);
  const existing = db.prepare('SELECT id FROM referrals WHERE referee_id = ?').get(req.user.id);
  if (existing) return fail(res, 'Referral already redeemed.', 422);

  const reward = referrer.is_artist ? 'free_ticket' : 'ghost_pass';
  db.prepare(
    "INSERT INTO referrals (code, referrer_id, referee_id, status, reward) VALUES (?, ?, ?, 'validated', ?)"
  ).run(code, referrer.id, req.user.id, reward);
  db.prepare('UPDATE users SET referred_by = ? WHERE id = ?').run(referrer.id, req.user.id);
  return res.json({ status: 'success', message: 'Referral redeemed.', data: { reward } });
});

// ─── Ghost pass (accès VIP temporaire gamifié, NON comptabilisé en vente) ───
router.post('/ghost-pass/grant', requireAuth, (req, res) => {
  const b = req.body || {};
  const minutes = parseInt(b.duration_minutes || 10, 10);
  const expires = new Date(Date.now() + minutes * 60000).toISOString().replace('T', ' ').slice(0, 19);
  db.prepare(
    'INSERT INTO ghost_passes (user_id, event_id, duration_minutes, expires_at) VALUES (?, ?, ?, ?)'
  ).run(req.user.id, b.event_id, minutes, expires);
  return res.json({ status: 'success', data: { event_id: b.event_id, duration_minutes: minutes, expires_at: expires } });
});

router.get('/ghost-pass/me', requireAuth, (req, res) => {
  const rows = db
    .prepare("SELECT * FROM ghost_passes WHERE user_id = ? AND datetime(expires_at) > datetime('now')")
    .all(req.user.id);
  return ok(res, rows);
});

// ─── Event Pulse (analytics agrégées, anonymisées) ───
router.post('/event/:id/signal', optionalAuth, (req, res) => {
  const b = req.body || {};
  db.prepare(
    'INSERT INTO event_signals (event_id, user_id, type, region) VALUES (?, ?, ?, ?)'
  ).run(req.params.id, req.user?.id || null, b.type || 'view', b.region || null);
  return res.json({ status: 'success' });
});

router.get('/event/:id/pulse', requireAuth, (req, res) => {
  const id = req.params.id;
  const total = db.prepare('SELECT COUNT(*) c FROM event_signals WHERE event_id = ?').get(id).c;
  const byType = db
    .prepare('SELECT type, COUNT(*) c FROM event_signals WHERE event_id = ? GROUP BY type')
    .all(id);
  return res.json({
    status: 'success',
    data: { total_signals: total, by_type: byType, top_areas: [], best_time: null },
  });
});

// ─── Shorts UGC (Mux Direct Upload) ───
// En prod : appeler l'API Mux avec le token secret pour créer un upload direct.
// Ici (démo) : on renvoie une URL factice pour ne pas exposer de secret.
router.post('/shorts/create-upload', optionalAuth, (req, res) => {
  return res.json({
    status: 'success',
    data: {
      upload_url: 'https://example.com/mux-direct-upload-placeholder',
      upload_id: `up_${Date.now()}`,
      note: 'Brancher l\'API Mux (POST https://api.mux.com/video/v1/uploads) côté serveur avec MUX_TOKEN_SECRET.',
    },
  });
});

module.exports = router;

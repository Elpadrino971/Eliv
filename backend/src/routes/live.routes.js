'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Flux temps réel pour les écrans Stage / Régie (SSE), monté sous /api/live.
//
//   GET  /api/live/:eventId/stream?key=<clé API>  -> flux d'événements du concert
//   POST /api/live/:eventId/emit   (X-API-Key)     -> publie un événement manuel
//                                                    (ex. "cadeau test" depuis la console)
//
// Sécurité : la clé API est celle générée dans l'admin (« API / Atelier »).
// EventSource ne peut pas envoyer d'en-tête -> la clé passe en ?key= pour le
// flux ; on la compare par hash (jamais stockée en clair), comme partout.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { sha256, optionalAuth } = require('../auth');
const bus = require('../services/livebus');

function keyOk(req) {
  const key = req.query.key || req.headers['x-api-key'];
  if (!key) return false;
  try {
    return !!db.prepare('SELECT id FROM api_keys WHERE key_hash = ? AND active = 1').get(sha256(String(key)));
  } catch (_) { return false; }
}

router.get('/:eventId/stream', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise (?key=…).' });
  res.set({
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no', // Nginx : ne pas mettre le flux en tampon
  });
  res.flushHeaders();
  res.write(`event: hello\ndata: ${JSON.stringify({ event_id: req.params.eventId, screens: bus.count(req.params.eventId) + 1 })}\n\n`);
  bus.subscribe(req.params.eventId, res);
  // Battement de cœur : garde la connexion ouverte à travers les proxys.
  const hb = setInterval(() => { try { res.write(': ping\n\n'); } catch (_) { clearInterval(hb); } }, 25000);
  req.on('close', () => clearInterval(hb));
});

router.post('/:eventId/emit', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const p = req.body || {};
  if (!p.type) return res.status(422).json({ status: 'error', message: 'Champ "type" requis (gift, ticket, note, goal…).' });
  const delivered = bus.emit(req.params.eventId, p);
  return res.json({ status: 'success', delivered });
});

// ── Chat live centralisé ─────────────────────────────────────────────────────
// POST /api/live/:eventId/messages  { text, user? }
//   - un fan (app)   : JWT Bearer -> nom pris sur son compte (jamais l'e-mail)
//   - la régie       : clé API    -> nom libre (défaut « Régie »)
router.post('/:eventId/messages', optionalAuth, (req, res) => {
  const b = req.body || {};
  const text = String(b.text || '').replace(/\s+/g, ' ').trim().slice(0, 300);
  if (!text) return res.status(422).json({ status: 'error', message: 'Message vide.' });
  let userId = null, name = null;
  if (req.user) { userId = req.user.id; name = req.user.artist_name || req.user.full_name || 'Un fan'; }
  else if (keyOk(req)) { name = String(b.user || 'Régie').trim().slice(0, 60) || 'Régie'; }
  else return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const info = db.prepare('INSERT INTO live_messages (event_id, user_id, name, text) VALUES (?, ?, ?, ?)')
    .run(req.params.eventId, userId, name, text);
  bus.emit(req.params.eventId, { type: 'chat', id: info.lastInsertRowid, user: name, text });
  return res.json({ status: 'success', data: { id: info.lastInsertRowid, user: name, text } });
});

// GET /api/live/:eventId/messages?since=<id>&limit=50 -> historique (clé API ou JWT)
router.get('/:eventId/messages', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const since = Number(req.query.since) || 0;
  const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 50));
  const rows = db.prepare(
    'SELECT id, user_id, name, text, created_at FROM live_messages WHERE event_id = ? AND id > ? ORDER BY id DESC LIMIT ?'
  ).all(req.params.eventId, since, limit).reverse();
  return res.json({ status: 'success', data: rows });
});

// ── Questions du public (Q&A live) ──────────────────────────────────────────
// Le Stage n'affiche qu'UNE question à la fois : celle mise à l'écran par la
// régie (featured) sinon la plus likée (si elle atteint QUESTION_MIN_LIKES).
const QUESTION_MIN_LIKES = Number(process.env.QUESTION_MIN_LIKES) || 3;
const pubQ = (q) => ({ id: q.id, text: q.text, user: q.name, likes: q.likes, status: q.status, created_at: q.created_at });
function questionBoard(eventId) {
  const f = db.prepare("SELECT * FROM live_questions WHERE event_id = ? AND status = 'featured' ORDER BY id DESC LIMIT 1").get(eventId);
  if (f) return { reason: 'featured', question: pubQ(f) };
  const t = db.prepare("SELECT * FROM live_questions WHERE event_id = ? AND status = 'open' ORDER BY likes DESC, id ASC LIMIT 1").get(eventId);
  if (t && t.likes >= QUESTION_MIN_LIKES) return { reason: 'top', question: pubQ(t) };
  return { reason: 'none', question: null };
}
function broadcastQuestions(eventId) {
  bus.emit(eventId, { type: 'question', ...questionBoard(eventId) }); // pour le Stage
  bus.emit(eventId, { type: 'questions_changed' });                    // la console recharge sa liste
}
function ownQuestion(req, res) {
  const q = db.prepare('SELECT * FROM live_questions WHERE id = ? AND event_id = ?').get(req.params.id, req.params.eventId);
  if (!q) res.status(404).json({ status: 'error', message: 'Question introuvable.' });
  return q;
}

// GET /api/live/:eventId/questions?status=active|all  (clé API ou JWT)
router.get('/:eventId/questions', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const all = req.query.status === 'all';
  const rows = db.prepare(
    `SELECT * FROM live_questions WHERE event_id = ? ${all ? '' : "AND status IN ('open','featured')"} ORDER BY (status='featured') DESC, likes DESC, id ASC LIMIT 100`
  ).all(req.params.eventId);
  const liked = req.user ? new Set(db.prepare('SELECT question_id FROM live_question_likes WHERE user_id = ?').all(req.user.id).map((r) => r.question_id)) : null;
  return res.json({ status: 'success', data: rows.map((q) => ({ ...pubQ(q), liked: liked ? liked.has(q.id) : undefined })), board: questionBoard(req.params.eventId), min_likes: QUESTION_MIN_LIKES });
});

// POST /api/live/:eventId/questions { text, user? }  (fan : JWT ; régie : clé API)
router.post('/:eventId/questions', optionalAuth, (req, res) => {
  const text = String((req.body || {}).text || '').replace(/\s+/g, ' ').trim().slice(0, 200);
  if (text.length < 3) return res.status(422).json({ status: 'error', message: 'Question trop courte.' });
  let userId = null, name = null;
  if (req.user) { userId = req.user.id; name = req.user.artist_name || req.user.full_name || 'Un fan'; }
  else if (keyOk(req)) { name = String((req.body || {}).user || 'Régie').trim().slice(0, 60) || 'Régie'; }
  else return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const info = db.prepare('INSERT INTO live_questions (event_id, user_id, name, text) VALUES (?, ?, ?, ?)').run(req.params.eventId, userId, name, text);
  broadcastQuestions(req.params.eventId);
  return res.json({ status: 'success', data: pubQ(db.prepare('SELECT * FROM live_questions WHERE id = ?').get(info.lastInsertRowid)) });
});

// POST /api/live/:eventId/questions/:id/like  (fan : JWT ; un seul like par personne)
router.post('/:eventId/questions/:id/like', optionalAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ status: 'error', message: 'Connexion requise pour liker.' });
  const q = ownQuestion(req, res); if (!q) return;
  if (!['open', 'featured'].includes(q.status)) return res.status(409).json({ status: 'error', message: 'Question close.' });
  try { db.prepare('INSERT INTO live_question_likes (question_id, user_id) VALUES (?, ?)').run(q.id, req.user.id); }
  catch (_) { return res.status(409).json({ status: 'error', message: 'Déjà liké.' }); }
  db.prepare('UPDATE live_questions SET likes = (SELECT COUNT(*) FROM live_question_likes WHERE question_id = ?) WHERE id = ?').run(q.id, q.id);
  broadcastQuestions(req.params.eventId);
  return res.json({ status: 'success', data: { id: q.id, likes: db.prepare('SELECT likes FROM live_questions WHERE id = ?').get(q.id).likes } });
});

// Actions régie (clé API) : mettre à l'écran / répondue / masquer
function regieAction(status) {
  return (req, res) => {
    if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
    const q = ownQuestion(req, res); if (!q) return;
    if (status === 'featured') db.prepare("UPDATE live_questions SET status = 'open' WHERE event_id = ? AND status = 'featured'").run(req.params.eventId); // une seule à l'écran
    db.prepare('UPDATE live_questions SET status = ? WHERE id = ?').run(status, q.id);
    broadcastQuestions(req.params.eventId);
    return res.json({ status: 'success', data: { id: q.id, status } });
  };
}
router.post('/:eventId/questions/:id/feature', regieAction('featured'));
router.post('/:eventId/questions/:id/unfeature', regieAction('open'));
router.post('/:eventId/questions/:id/answered', regieAction('answered'));
router.post('/:eventId/questions/:id/hide', regieAction('hidden'));

// ── Compte à rebours de fin de live ─────────────────────────────────────────
// events.live_ends_at (ISO UTC) = fin réelle du live, initialisée depuis la fin
// planifiée (end_date_time) si vide. La régie peut fixer / prolonger / réduire /
// terminer ; chaque changement est poussé en SSE ('clock') à tous les écrans.
function parseDbDate(s) {
  if (!s) return null;
  const t = /[zZ]|[+-]\d\d:\d\d$/.test(s) ? Date.parse(s) : Date.parse(String(s).replace(' ', 'T') + 'Z');
  return Number.isNaN(t) ? null : t;
}
function clockState(eventId) {
  const ev = db.prepare('SELECT id, live_ends_at, end_date_time, tz_offset_minutes FROM events WHERE id = ?').get(eventId);
  if (!ev) return null;
  let ends = parseDbDate(ev.live_ends_at);
  if (ends == null && ev.end_date_time) {
    const t = parseDbDate(ev.end_date_time);
    if (t != null) ends = t - (Number(ev.tz_offset_minutes) || 0) * 60000;
  }
  return {
    ends_at: ends != null ? new Date(ends).toISOString() : null,
    server_now: new Date().toISOString(),
    remaining_s: ends != null ? Math.round((ends - Date.now()) / 1000) : null,
  };
}
// GET /api/live/:eventId/clock  (clé API ou JWT)
router.get('/:eventId/clock', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const s = clockState(req.params.eventId);
  if (!s) return res.status(404).json({ status: 'error', message: 'Concert introuvable.' });
  return res.json({ status: 'success', data: s });
});
// POST /api/live/:eventId/clock { action: set|extend|reduce|end, minutes, by }  (clé API)
router.post('/:eventId/clock', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const b = req.body || {};
  const action = String(b.action || '');
  const minutes = Math.max(0, Math.min(600, Number(b.minutes) || 0));
  const by = String(b.by || 'Régie').slice(0, 60);
  const s = clockState(req.params.eventId);
  if (!s) return res.status(404).json({ status: 'error', message: 'Concert introuvable.' });
  const now = Date.now();
  const cur = s.ends_at ? Date.parse(s.ends_at) : null;
  let next, delta = 0;
  if (action === 'set' && minutes) next = now + minutes * 60000;
  else if (action === 'extend' && minutes) { next = (cur != null && cur > now ? cur : now) + minutes * 60000; delta = minutes; }
  else if (action === 'reduce' && minutes) { next = Math.max(now, (cur != null ? cur : now) - minutes * 60000); delta = -minutes; }
  else if (action === 'end') next = now;
  else return res.status(422).json({ status: 'error', message: 'action = set | extend | reduce | end (+ minutes).' });
  db.prepare('UPDATE events SET live_ends_at = ? WHERE id = ?').run(new Date(next).toISOString(), req.params.eventId);
  const out = { ...clockState(req.params.eventId), delta_min: delta, by };
  bus.emit(req.params.eventId, { type: 'clock', ...out });
  return res.json({ status: 'success', data: out });
});

module.exports = router;

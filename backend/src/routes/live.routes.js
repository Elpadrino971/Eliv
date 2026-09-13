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

module.exports = router;

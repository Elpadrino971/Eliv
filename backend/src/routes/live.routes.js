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
const { asyncHandler } = require('../helpers');
const bus = require('../services/livebus');
const zegoService = require('../services/zego');
const badges = require('../services/badges');
const moderation = require('../services/moderation');

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

// ── Garde-fous du chat / des questions (fans) ───────────────────────────────
// 1. Accès : billet pour ce concert, ou concert gratuit, ou l'artiste. Avant,
//    n'importe quel compte pouvait écrire sur le mur d'un concert payant.
// 2. Contenu : mots interdits (table abusive_words) puis modération
//    Sightengine (fail-open si non configurée) ; 300 caractères max.
// 3. Débit : 1 message / 2 s par utilisateur (mémoire, par process).
const FAN_MSG_MAX_LEN = 300;
const FAN_MSG_MIN_INTERVAL_MS = 2000;
const lastFanMessageAt = new Map(); // user_id -> timestamp
function fanCanWrite(user, eventId) {
  const ev = db.prepare('SELECT id, artist_id, ticket_price FROM events WHERE id = ?').get(eventId);
  if (!ev) return { ok: false, status: 404, message: 'Concert introuvable.' };
  if (Number(ev.artist_id) === Number(user.id)) return { ok: true };
  if ((parseFloat(ev.ticket_price) || 0) <= 0) return { ok: true };
  const t = db.prepare('SELECT 1 FROM tickets WHERE event_id = ? AND user_id = ? LIMIT 1').get(eventId, user.id);
  if (!t) return { ok: false, status: 403, message: 'Un billet est nécessaire pour participer à ce concert.' };
  return { ok: true };
}
function fanRateLimited(userId) {
  const now = Date.now();
  const last = lastFanMessageAt.get(userId) || 0;
  if (now - last < FAN_MSG_MIN_INTERVAL_MS) return true;
  lastFanMessageAt.set(userId, now);
  if (lastFanMessageAt.size > 20000) { // évite une croissance sans fin
    for (const [k, v] of lastFanMessageAt) if (now - v > 60000) lastFanMessageAt.delete(k);
  }
  return false;
}
let abusiveCache = { at: 0, words: [] };
function abusiveWords() {
  if (Date.now() - abusiveCache.at > 60000) {
    try { abusiveCache = { at: Date.now(), words: db.prepare('SELECT word FROM abusive_words').all().map((r) => String(r.word || '').toLowerCase()).filter(Boolean) }; }
    catch (_) { abusiveCache.at = Date.now(); }
  }
  return abusiveCache.words;
}
function hasAbusiveWord(text) {
  const lower = String(text).toLowerCase();
  const tokens = new Set(lower.split(/[^\p{L}\p{N}]+/u).filter(Boolean));
  for (const w of abusiveWords()) {
    if (w.includes(' ')) { if (lower.includes(w)) return true; } // expression : sous-chaîne
    else if (tokens.has(w)) return true;                         // mot entier
  }
  return false;
}
async function checkFanText(text, { targetType, targetId }) {
  if (hasAbusiveWord(text)) return 'Message refusé : langage inapproprié.';
  const decision = await moderation.reviewText(text, { targetType, targetId });
  if (decision && decision.action === 'block') return 'Message refusé par la modération.';
  return null;
}

// ── Chat live centralisé ─────────────────────────────────────────────────────
// POST /api/live/:eventId/messages  { text, user? }
//   - un fan (app)   : JWT Bearer -> nom pris sur son compte (jamais l'e-mail)
//   - la régie       : clé API    -> nom libre (défaut « Régie »)
router.post('/:eventId/messages', optionalAuth, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const text = String(b.text || '').replace(/\s+/g, ' ').trim().slice(0, FAN_MSG_MAX_LEN);
  if (!text) return res.status(422).json({ status: 'error', message: 'Message vide.' });
  let userId = null, name = null;
  if (req.user) {
    const access = fanCanWrite(req.user, req.params.eventId);
    if (!access.ok) return res.status(access.status).json({ status: 'error', message: access.message });
    if (fanRateLimited(req.user.id)) return res.status(429).json({ status: 'error', message: 'Doucement : un message toutes les 2 secondes.' });
    const refused = await checkFanText(text, { targetType: 'live_message', targetId: req.params.eventId });
    if (refused) return res.status(422).json({ status: 'error', message: refused });
    userId = req.user.id; name = req.user.artist_name || req.user.full_name || 'Un fan';
  }
  else if (keyOk(req)) { name = String(b.user || 'Régie').trim().slice(0, 60) || 'Régie'; }
  else return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const info = db.prepare('INSERT INTO live_messages (event_id, user_id, name, text) VALUES (?, ?, ?, ?)')
    .run(req.params.eventId, userId, name, text);
  bus.emit(req.params.eventId, { type: 'chat', id: info.lastInsertRowid, user: name, text });
  return res.json({ status: 'success', data: { id: info.lastInsertRowid, user: name, text } });
}));

// GET /api/live/:eventId/messages?since=<id>&limit=50 -> historique (clé API ou JWT)
router.get('/:eventId/messages', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const since = Number(req.query.since) || 0;
  const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 50));
  // Les messages d'un compte bloqué ne s'affichent plus pour celui qui l'a bloqué.
  let blocked = [];
  if (req.user?.id) {
    try { blocked = db.prepare('SELECT blocked_id FROM user_blocks WHERE blocker_id = ?').all(req.user.id).map((r) => r.blocked_id); } catch (_) {}
  }
  const rows = db.prepare(
    `SELECT id, user_id, name, text, created_at FROM live_messages
      WHERE event_id = ? AND id > ?${blocked.length ? ` AND (user_id IS NULL OR user_id NOT IN (${blocked.map(() => '?').join(',')}))` : ''}
      ORDER BY id DESC LIMIT ?`
  ).all(req.params.eventId, since, ...blocked, limit).reverse();
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
router.post('/:eventId/questions', optionalAuth, asyncHandler(async (req, res) => {
  const text = String((req.body || {}).text || '').replace(/\s+/g, ' ').trim().slice(0, 200);
  if (text.length < 3) return res.status(422).json({ status: 'error', message: 'Question trop courte.' });
  let userId = null, name = null;
  if (req.user) {
    const access = fanCanWrite(req.user, req.params.eventId);
    if (!access.ok) return res.status(access.status).json({ status: 'error', message: access.message });
    if (fanRateLimited(req.user.id)) return res.status(429).json({ status: 'error', message: 'Doucement : un message toutes les 2 secondes.' });
    const refused = await checkFanText(text, { targetType: 'live_question', targetId: req.params.eventId });
    if (refused) return res.status(422).json({ status: 'error', message: refused });
    userId = req.user.id; name = req.user.artist_name || req.user.full_name || 'Un fan';
  }
  else if (keyOk(req)) { name = String((req.body || {}).user || 'Régie').trim().slice(0, 60) || 'Régie'; }
  else return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const info = db.prepare('INSERT INTO live_questions (event_id, user_id, name, text) VALUES (?, ?, ?, ?)').run(req.params.eventId, userId, name, text);
  broadcastQuestions(req.params.eventId);
  return res.json({ status: 'success', data: pubQ(db.prepare('SELECT * FROM live_questions WHERE id = ?').get(info.lastInsertRowid)) });
}));

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

// ── Jeton Zego pour les écrans web (Stage / Régie) ─────────────────────────
// Les écrans rejoignent LA room du concert (room = id du concert, comme l'app)
// pour afficher les vraies cams des fans. Rôle : stage | regie.
router.get('/:eventId/zego-token', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  if (!zegoService.isConfigured()) return res.status(503).json({ status: 'error', message: 'ZegoCloud non configuré (ZEGO_APP_ID / ZEGO_SERVER_SECRET).' });
  const role = req.query.role === 'stage' ? 'stage' : 'regie';
  const userId = 'web_' + role + '_' + req.params.eventId + '_' + Math.random().toString(36).slice(2, 8);
  // artist_id : l'écran repère le flux de l'artiste (`<concert>_<artist_id>_main`)
  // pour l'afficher en grand ; les autres flux publiés sont les fans sur scène.
  let artistId = null;
  try { const ev = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(req.params.eventId); artistId = ev ? ev.artist_id : null; } catch (_) {}
  try {
    const { token, appId, expiresAt } = zegoService.generateToken04(userId);
    return res.json({ status: 'success', data: {
      app_id: appId, token, expires_at: expiresAt, room_id: String(req.params.eventId),
      artist_id: artistId != null ? String(artistId) : null,
      user_id: userId, user_name: role === 'stage' ? 'Stage VybzzZ' : 'Régie VybzzZ',
      server: 'wss://webliveroom' + appId + '-api.zegocloud.com/ws',
    } });
  } catch (e) { return res.status(502).json({ status: 'error', message: 'Erreur Zego : ' + e.message }); }
});

// ── Mains levées + micro unique ─────────────────────────────────────────────
// Un fan lève la main depuis l'app (JWT). La régie donne / retire la parole ;
// UN SEUL micro à la fois : 'mic' porte le flux (`<concert>_<user>_main`) que
// les écrans laissent sonner, tous les autres sont coupés.
const HANDS = new Map(); // event_id -> Map(user_id -> {user_id, name, at})
const MIC = new Map();   // event_id -> {user_id, name, stream_id} | null
function handsList(id) { return [...(HANDS.get(String(id)) || new Map()).values()].sort((a, b) => a.at - b.at); }
function broadcastHands(id) { bus.emit(id, { type: 'hands', hands: handsList(id) }); }
function nameOf(userId) { const u = db.prepare('SELECT full_name, artist_name FROM users WHERE id = ?').get(userId); return (u && (u.artist_name || u.full_name)) || ('Fan ' + userId); }

router.get('/:eventId/hands', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  return res.json({ status: 'success', data: { hands: handsList(req.params.eventId), mic: MIC.get(String(req.params.eventId)) || null } });
});
router.post('/:eventId/hand', optionalAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ status: 'error', message: 'Connexion requise.' });
  const id = String(req.params.eventId);
  if (!HANDS.has(id)) HANDS.set(id, new Map());
  const up = (req.body || {}).up !== false;
  if (up) HANDS.get(id).set(String(req.user.id), { user_id: req.user.id, name: req.user.artist_name || req.user.full_name || 'Un fan', at: Date.now() });
  else HANDS.get(id).delete(String(req.user.id));
  broadcastHands(id);
  return res.json({ status: 'success', data: { up } });
});
router.post('/:eventId/hands/:userId/grant', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const id = String(req.params.eventId), uid = String(req.params.userId);
  const h = (HANDS.get(id) || new Map()).get(uid);
  const name = (h && h.name) || String((req.body || {}).name || '').slice(0, 60) || nameOf(uid);
  if (HANDS.get(id)) HANDS.get(id).delete(uid);
  const mic = { user_id: uid, name, stream_id: id + '_' + uid + '_main' };
  MIC.set(id, mic);
  bus.emit(id, { type: 'mic', ...mic });
  bus.emit(id, { type: 'note', user: 'Régie', text: '🎙️ ' + name + ' a la parole' });
  broadcastHands(id);
  return res.json({ status: 'success', data: mic });
});
router.post('/:eventId/hands/:userId/deny', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const id = String(req.params.eventId);
  if (HANDS.get(id)) HANDS.get(id).delete(String(req.params.userId));
  broadcastHands(id);
  return res.json({ status: 'success' });
});
router.post('/:eventId/mic/off', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const id = String(req.params.eventId);
  MIC.set(id, null);
  bus.emit(id, { type: 'mic', user_id: null, name: null, stream_id: null });
  return res.json({ status: 'success' });
});

// ── Top fans du concert (somme des points de cadeaux confirmés) ─────────────
// GET /api/live/:eventId/top-fans?limit=5  (clé API ou JWT) — alimente l'onglet
// « Top fans » de la régie et le classement du Stage (aucune donnée inventée).
router.get('/:eventId/top-fans', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  const limit = Math.min(20, Math.max(1, Number(req.query.limit) || 5));
  const rows = db.prepare(
    `SELECT a.user_id, SUM(CAST(a.points AS REAL)) points, MIN(a.id) first_id, u.artist_name, u.full_name
       FROM activities a LEFT JOIN users u ON u.id = a.user_id
      WHERE a.event_id = ? AND a.type = 'gift' AND a.user_id IS NOT NULL
      GROUP BY a.user_id ORDER BY points DESC, first_id ASC LIMIT ?`
  ).all(req.params.eventId, limit);
  return res.json({ status: 'success', data: rows.map((r) => ({
    user_id: r.user_id, name: r.artist_name || r.full_name || 'Un fan', points: Math.round(r.points || 0),
  })) });
});

// ── Badges du mur (👑 Top Supporter · 💸 Meilleur Tippeur · ⭐ Invité VIP) ──
router.get('/:eventId/badges', optionalAuth, (req, res) => {
  if (!req.user && !keyOk(req)) return res.status(401).json({ status: 'error', message: 'Connexion ou clé API requise.' });
  return res.json({ status: 'success', data: badges.refresh(req.params.eventId, { announce: false }) || badges.current(req.params.eventId) });
});
router.post('/:eventId/badges/vip', (req, res) => {
  if (!keyOk(req)) return res.status(401).json({ status: 'error', message: 'Clé API requise.' });
  const b = req.body || {};
  const data = badges.setVip(req.params.eventId, b.user_id ? (Number(b.user_id) || String(b.user_id)) : null, b.name ? String(b.name).slice(0, 60) : null);
  return res.json({ status: 'success', data });
});

module.exports = router;

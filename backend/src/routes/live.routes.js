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

module.exports = router;

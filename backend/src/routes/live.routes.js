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
const { sha256 } = require('../auth');
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

module.exports = router;

'use strict';

/** Auth par Bearer token (JWT), comme l'API actuelle (Authorization: Bearer …). */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db } = require('./db');
const geo = require('./services/geo');

// Capture best-effort du pays via l'IP, une seule fois (tant que non renseigné).
// Non bloquant : toute erreur est ignorée pour ne jamais casser une requête.
function captureGeo(user, req) {
  try {
    if (!user || user.country_code) return;
    const g = geo.fromIp(req.ip || (req.headers && req.headers['x-forwarded-for']));
    if (!g || !g.code) return;
    db.prepare('UPDATE users SET country_code = ?, geo_lat = ?, geo_lon = ?, geo_at = datetime("now") WHERE id = ?')
      .run(g.code, g.lat, g.lon, user.id);
  } catch (_) { /* silencieux */ }
}

// Secret de signature JWT. S'il est manquant ou laissé à un placeholder, la
// clé est publique/devinable -> n'importe qui peut forger un token (y compris
// admin). En production on REFUSE de démarrer ; ailleurs on avertit bruyamment.
const PLACEHOLDER_SECRETS = new Set([
  'vybzzz-dev-secret-change-me',
  'change-me-with-a-long-random-string',
]);
const RAW_SECRET = process.env.JWT_SECRET;
const SECRET_IS_WEAK = !RAW_SECRET || PLACEHOLDER_SECRETS.has(RAW_SECRET) || RAW_SECRET.length < 32;
if (SECRET_IS_WEAK) {
  const msg = 'JWT_SECRET manquant/faible : définir une chaîne aléatoire >= 32 caractères (openssl rand -hex 32).';
  if (process.env.NODE_ENV === 'production') {
    throw new Error(`[auth] ${msg} Démarrage refusé en production.`);
  }
  console.warn(`[auth] ⚠️  ${msg}`);
}
const SECRET = RAW_SECRET || 'vybzzz-dev-secret-change-me';

function hash(pw) {
  return bcrypt.hashSync(String(pw), 10);
}
function compare(pw, hashed) {
  if (!hashed) return false;
  return bcrypt.compareSync(String(pw), hashed);
}
function sign(user) {
  return jwt.sign({ id: user.id, email: user.email }, SECRET, { expiresIn: '90d' });
}

/** Middleware : exige un token valide, attache req.user. */
function requireAuth(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ status: 'error', message: 'Unauthenticated.' });
  }
  try {
    const payload = jwt.verify(token, SECRET);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.id);
    if (!user) {
      return res.status(401).json({ status: 'error', message: 'User not found.' });
    }
    // Un compte banni/suspendu via l'admin (users.status) gardait un accès
    // complet (achat, cadeaux, retrait…) tant que son JWT (valable 90j)
    // n'expirait pas -> le blocage admin n'avait aucun effet réel.
    if (user.status && user.status !== 'active') {
      return res.status(403).json({ status: 'error', message: 'Account suspended.' });
    }
    req.user = user;
    captureGeo(user, req);
    next();
  } catch (e) {
    return res.status(401).json({ status: 'error', message: 'Invalid token.' });
  }
}

/** Middleware souple : attache req.user si un token valide est présent, sinon continue. */
function optionalAuth(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (token) {
    try {
      const payload = jwt.verify(token, SECRET);
      req.user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.id);
    } catch (_) {
      /* ignore */
    }
  }
  next();
}

module.exports = { hash, compare, sign, requireAuth, optionalAuth, SECRET };

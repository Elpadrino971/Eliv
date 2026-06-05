'use strict';

/** Auth par Bearer token (JWT), comme l'API actuelle (Authorization: Bearer …). */

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db } = require('./db');

const SECRET = process.env.JWT_SECRET || 'vybzzz-dev-secret-change-me';

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
    req.user = user;
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

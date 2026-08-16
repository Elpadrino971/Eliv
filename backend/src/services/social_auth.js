'use strict';

/**
 * Vérification serveur des jetons de connexion sociale (Google / Apple).
 * Avant, /social-login renvoyait un token sur simple email -> n'importe qui
 * pouvait se connecter comme un autre (y compris admin). On exige et vérifie
 * désormais un vrai jeton du fournisseur.
 *
 * Config (.env) :
 *   GOOGLE_CLIENT_IDS = liste (séparée par des virgules) des client IDs OAuth
 *                       autorisés (web + iOS + android). Recommandé.
 *   APPLE_BUNDLE_ID   = bundle id de l'app (audience du jeton Apple). Recommandé.
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// Vérifie un id_token Google via l'endpoint officiel tokeninfo (jeton signé par
// Google). Renvoie { email, name, picture } ou lève.
async function verifyGoogle(idToken) {
  if (!idToken) throw new Error('google: token manquant');
  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  if (!res.ok) throw new Error(`google: token invalide (${res.status})`);
  const d = await res.json();
  const allowed = (process.env.GOOGLE_CLIENT_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (allowed.length && !allowed.includes(d.aud)) {
    throw new Error('google: audience (client id) non autorisée');
  }
  if (d.email_verified !== true && d.email_verified !== 'true') {
    throw new Error('google: email non vérifié');
  }
  if (!d.email) throw new Error('google: email absent du jeton');
  return { email: String(d.email).toLowerCase(), name: d.name, picture: d.picture };
}

let _appleKeys = null;
let _appleKeysAt = 0;
async function _getAppleKeys() {
  if (_appleKeys && Date.now() - _appleKeysAt < 3600_000) return _appleKeys;
  const res = await fetch('https://appleid.apple.com/auth/keys');
  if (!res.ok) throw new Error(`apple: JWKS indisponible (${res.status})`);
  const data = await res.json();
  _appleKeys = data.keys || [];
  _appleKeysAt = Date.now();
  return _appleKeys;
}

// Vérifie un identityToken Apple contre les clés publiques Apple (JWKS).
// Renvoie { email, sub } ou lève. email peut être absent aux connexions
// répétées -> l'appelant retombe sur le sub stable.
async function verifyApple(identityToken) {
  if (!identityToken) throw new Error('apple: token manquant');
  const decoded = jwt.decode(identityToken, { complete: true });
  if (!decoded || !decoded.header) throw new Error('apple: token illisible');
  const keys = await _getAppleKeys();
  const jwk = keys.find((k) => k.kid === decoded.header.kid);
  if (!jwk) throw new Error('apple: clé introuvable');
  const pub = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  const payload = jwt.verify(identityToken, pub, {
    algorithms: ['RS256'],
    issuer: 'https://appleid.apple.com',
    audience: process.env.APPLE_BUNDLE_ID || undefined,
  });
  return {
    email: payload.email ? String(payload.email).toLowerCase() : null,
    sub: payload.sub || null,
  };
}

module.exports = { verifyGoogle, verifyApple };

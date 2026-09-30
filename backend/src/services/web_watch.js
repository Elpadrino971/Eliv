'use strict';

/**
 * Regarder un concert depuis le site, sans l'application.
 *
 * Pourquoi : le fan qui paie sur le site devait jusqu'ici installer l'app et
 * créer un compte avec la même adresse avant de voir le live. À 23 h 50, au
 * moment où le concert commence, c'est autant de places payées et jamais
 * regardées. Ici, l'accès est immédiat : le paiement (ou la réservation d'un
 * concert gratuit) renvoie une clé d'accès, et la page live.html lit le flux
 * HLS Mux du concert avec cette clé.
 *
 * La clé est un secret aléatoire propre à (e-mail, concert) ; seule son
 * empreinte SHA-256 est stockée. Le droit de regarder est revérifié à chaque
 * lecture : une place remboursée coupe l'accès, même avec une clé valide.
 */

const crypto = require('crypto');
const { db } = require('../db');
const access = require('./event_access');
const pricing = require('./pricing');
const mux = require('./mux');

const SITE_URL = (process.env.SITE_URL || 'https://vybzzz.online').replace(/\/+$/, '');

let ready = false;
function ensure() {
  if (ready) return;
  db.exec(`
    CREATE TABLE IF NOT EXISTS web_watch_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      token_hash TEXT UNIQUE NOT NULL,
      email TEXT NOT NULL,
      event_id INTEGER NOT NULL,
      source TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      last_used_at TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_web_watch_tokens_event ON web_watch_tokens (event_id);
  `);
  // ID de lecture « signed » (site web) du direct et du replay : créés à la
  // première lecture web, à côté des ID « public » qu'utilise l'app.
  for (const sql of [
    'ALTER TABLE events ADD COLUMN mux_live_signed_playback_id TEXT',
    'ALTER TABLE events ADD COLUMN mux_signed_playback_id TEXT',
  ]) {
    try { db.exec(sql); } catch (e) { /* colonne déjà présente */ }
  }
  ready = true;
}

const sha = (t) => crypto.createHash('sha256').update(String(t)).digest('hex');

/** Nouvelle clé d'accès pour cet e-mail et ce concert. Renvoie la clé en clair (une seule fois). */
function issue(email, eventId, source) {
  ensure();
  const token = crypto.randomBytes(24).toString('base64url');
  db.prepare('INSERT INTO web_watch_tokens (token_hash, email, event_id, source) VALUES (?, ?, ?, ?)')
    .run(sha(token), access.canonEmail(email), Number(eventId), source || null);
  return token;
}

/** Ligne de la clé si elle existe ET correspond à ce concert, sinon null. */
function lookup(token, eventId) {
  ensure();
  const t = String(token || '');
  if (!t || t.length > 100) return null;
  const row = db.prepare('SELECT * FROM web_watch_tokens WHERE token_hash = ?').get(sha(t));
  if (!row || Number(row.event_id) !== Number(eventId)) return null;
  // Horodatage d'usage, au plus une écriture toutes les 5 min par clé : la
  // page interroge le serveur toutes les 20 s pendant le live.
  db.prepare(
    "UPDATE web_watch_tokens SET last_used_at = datetime('now') WHERE id = ? AND (last_used_at IS NULL OR last_used_at < datetime('now', '-5 minutes'))"
  ).run(row.id);
  return row;
}

function watchUrl(eventId, token) {
  return `${SITE_URL}/live.html?e=${Number(eventId)}&k=${encodeURIComponent(token)}`;
}

function isFree(event) {
  return (parseFloat(pricing.effectivePrice(event).price) || 0) <= 0;
}

/** État du concert vu du site : 'upcoming' | 'live' | 'ended'. */
function stateOf(event) {
  if (event.status === 'live') return 'live';
  if (event.status === 'completed' || event.status === 'ended') return 'ended';
  return 'upcoming';
}

/**
 * Peut-on montrer le flux à cet e-mail ? Concert gratuit : oui (la
 * réservation sert à compter et à prévenir). Payant : billet ou place non
 * remboursés (hasAccess couvre les deux), ou artiste / admin du compte.
 */
function canWatch(email, event) {
  if (isFree(event)) return true;
  if (access.hasAccess(email, event.id)) return true;
  const user = access.findUserByEmail(email);
  if (!user) return false;
  return Number(user.id) === Number(event.artist_id) || user.role === 'admin';
}

/** E-mail « regarde le live » : lien direct vers la page, clé comprise. */
function watchEmailHtml(eventName, url, { paid = false } = {}) {
  const safe = String(eventName || 'Ton concert').replace(/[<>&"]/g, '');
  return `<!doctype html><html lang="fr"><body style="margin:0;background:#0A1226;font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#F4EFE3">
<div style="max-width:520px;margin:0 auto;padding:36px 26px;text-align:center">
  <div style="font-weight:800;letter-spacing:.12em;font-size:18px">Vybzz<span style="color:#E6C76A">Z</span></div>
  <h1 style="font-size:24px;margin:28px 0 10px">${paid ? 'Ta place est réservée' : 'Ton accès au live'}</h1>
  <p style="color:#B9C0D0;line-height:1.6;margin:0 0 24px">${safe}, en direct sur VybzzZ.</p>
  <a href="${url}" style="display:inline-block;background:#E6C76A;color:#0A1226;text-decoration:none;font-weight:700;padding:15px 28px;border-radius:12px">Regarder le live</a>
  <p style="color:#B9C0D0;line-height:1.6;margin:26px 0 0;font-size:14px">Ce lien ouvre le concert dans ton navigateur, sur téléphone, ordinateur ou tablette. Garde-le pour toi : c'est ta place.</p>
  <p style="color:#B9C0D0;line-height:1.6;margin:14px 0 0;font-size:14px">Tu préfères l'application ? Connecte-toi à VybzzZ avec cette même adresse e-mail : ta place y est aussi.</p>
</div></body></html>`;
}


// ─── Lecture protégée ──────────────────────────────────────────────────────
// Le site ne reçoit JAMAIS un ID de lecture public : seulement une URL
// signée qui expire, liée au domaine vybzzz.online (restriction Mux sur
// l'en-tête Referer). Sans clé de signature configurée, pas de lecture web,
// sauf dérogation explicite WATCH_ALLOW_PUBLIC=1 (tests).
const LIVE_TTL_S = 4 * 3600; // couvre un concert entier sans coupure
const REPLAY_TTL_S = 3 * 3600;
const ALLOWED_DOMAINS = (process.env.WATCH_ALLOWED_DOMAINS || 'vybzzz.online,*.vybzzz.online')
  .split(',').map((d) => d.trim()).filter(Boolean);

function setting(key) {
  const r = db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
  return r ? r.value : null;
}

let restrictionPromise = null;
function restrictionId() {
  const known = setting('mux_playback_restriction_id');
  if (known) return Promise.resolve(known);
  if (!restrictionPromise) {
    restrictionPromise = mux.createPlaybackRestriction(ALLOWED_DOMAINS).then((id) => {
      db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run('mux_playback_restriction_id', id);
      return id;
    }).finally(() => { restrictionPromise = null; });
  }
  return restrictionPromise;
}

// Un seul appel Mux à la fois par flux (500 fans qui arrivent ensemble).
const pendingSigned = new Map();
function signedIdFor(event, kind) {
  const col = kind === 'live' ? 'mux_live_signed_playback_id' : 'mux_signed_playback_id';
  const current = db.prepare(`SELECT ${col} AS v FROM events WHERE id = ?`).get(event.id);
  if (current && current.v) return Promise.resolve(current.v);
  const muxId = kind === 'live' ? event.mux_live_stream_id : event.mux_asset_id;
  if (!muxId) return Promise.resolve(null);
  const key = `${kind}:${event.id}`;
  if (!pendingSigned.has(key)) {
    pendingSigned.set(key, mux.addSignedPlaybackId(kind === 'live' ? 'live' : 'asset', muxId).then((id) => {
      db.prepare(`UPDATE events SET ${col} = ? WHERE id = ?`).run(id, event.id);
      return id;
    }).finally(() => pendingSigned.delete(key)));
  }
  return pendingSigned.get(key);
}

/**
 * URL HLS à donner au navigateur pour ce concert, ou null.
 * @returns {Promise<{url:string|null, reason?:string}>}
 */
async function playbackUrl(event, kind) {
  ensure();
  if (!mux.isSigningConfigured()) {
    if (process.env.WATCH_ALLOW_PUBLIC === '1') {
      const pid = kind === 'live' ? event.mux_live_playback_id : event.mux_playback_id;
      return { url: pid ? `https://stream.mux.com/${pid}.m3u8` : null };
    }
    return { url: null, reason: 'signing_not_configured' };
  }
  const signedId = await signedIdFor(event, kind);
  if (!signedId) return { url: null };
  const token = mux.signPlaybackToken(signedId, {
    ttlSeconds: kind === 'live' ? LIVE_TTL_S : REPLAY_TTL_S,
    restrictionId: await restrictionId(),
  });
  return { url: `https://stream.mux.com/${signedId}.m3u8?token=${token}` };
}

// ─── Appareils simultanés ──────────────────────────────────────────────────
// Une place = deux écrans en même temps au plus (téléphone + TV). Chaque page
// ouverte envoie un identifiant d'appareil à chaque passage (toutes les 20 s) ;
// un appareil silencieux depuis 70 s libère sa place. Empêche de faire
// circuler un lien d'accès dans un groupe WhatsApp.
const MAX_DEVICES = Math.max(1, parseInt(process.env.WATCH_MAX_DEVICES, 10) || 2);
const DEVICE_IDLE_MS = 70 * 1000;
const seats = new Map(); // "event:email" -> Map(deviceId -> dernier passage)

function takeSeat(eventId, emailAddr, deviceId) {
  const key = `${Number(eventId)}:${access.canonEmail(emailAddr)}`;
  const now = Date.now();
  let devices = seats.get(key);
  if (!devices) { devices = new Map(); seats.set(key, devices); }
  for (const [d, t] of devices) if (now - t > DEVICE_IDLE_MS) devices.delete(d);
  if (!devices.has(deviceId) && devices.size >= MAX_DEVICES) return false;
  devices.set(deviceId, now);
  return true;
}
setInterval(() => {
  const now = Date.now();
  for (const [k, devices] of seats) {
    for (const [d, t] of devices) if (now - t > DEVICE_IDLE_MS) devices.delete(d);
    if (!devices.size) seats.delete(k);
  }
}, 60 * 1000).unref();

module.exports = { ensure, issue, lookup, watchUrl, isFree, stateOf, canWatch, watchEmailHtml, playbackUrl, takeSeat, MAX_DEVICES, SITE_URL };

'use strict';

/**
 * Liens d'invitation : des places gratuites qu'un artiste distribue lui-même.
 *
 * Avant, offrir une place se faisait e-mail par e-mail depuis l'admin ou
 * l'app. Ici l'admin crée UN lien pour un concert (nombre de places limité),
 * l'artiste l'envoie à qui il veut, et chaque invité entre son e-mail sur la
 * page live : sa place est réservée tout de suite, il regarde sur le site ou
 * dans l'app avec la même adresse.
 *
 * Le lien n'est pas « une place » : il en vaut `max_uses`. Un même e-mail ne
 * consomme qu'une place même en recliquant (idempotent).
 */

const crypto = require('crypto');
const { db } = require('../db');
const access = require('./event_access');

let ready = false;
function ensure() {
  if (ready) return;
  db.exec(`
    CREATE TABLE IF NOT EXISTS event_invites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT UNIQUE NOT NULL,
      event_id INTEGER NOT NULL,
      label TEXT,
      max_uses INTEGER NOT NULL DEFAULT 50,
      used INTEGER NOT NULL DEFAULT 0,
      disabled INTEGER NOT NULL DEFAULT 0,
      created_by INTEGER,
      created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS event_invite_uses (
      invite_id INTEGER NOT NULL,
      email TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (invite_id, email)
    );
  `);
  ready = true;
}

// Code court, lisible, sans caractères ambigus (0/O, 1/l) : « WILSON-7K3P ».
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
function genCode(prefix) {
  const base = String(prefix || 'VYB').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^A-Za-z0-9]+/g, '').toUpperCase().slice(0, 8) || 'VYB';
  let tail = '';
  for (const b of crypto.randomBytes(4)) tail += ALPHABET[b % ALPHABET.length];
  return `${base}-${tail}`;
}

function create({ eventId, label, maxUses, prefix, adminId }) {
  ensure();
  let code;
  for (let i = 0; i < 5; i++) {
    code = genCode(prefix);
    if (!db.prepare('SELECT 1 FROM event_invites WHERE code = ?').get(code)) break;
  }
  const info = db.prepare(
    'INSERT INTO event_invites (code, event_id, label, max_uses, created_by) VALUES (?, ?, ?, ?, ?)'
  ).run(code, Number(eventId), label || null, Math.max(1, Math.min(5000, Number(maxUses) || 50)), adminId || null);
  return get(info.lastInsertRowid);
}

function get(id) {
  ensure();
  return db.prepare('SELECT * FROM event_invites WHERE id = ?').get(Number(id)) || null;
}

function byCode(code) {
  ensure();
  const c = String(code || '').trim().toUpperCase();
  if (!/^[A-Z0-9]{1,8}-[A-Z0-9]{4}$/.test(c)) return null;
  return db.prepare('SELECT * FROM event_invites WHERE code = ?').get(c) || null;
}

function listForEvent(eventId) {
  ensure();
  return db.prepare('SELECT * FROM event_invites WHERE event_id = ? ORDER BY id DESC').all(Number(eventId));
}

function setDisabled(id, disabled) {
  ensure();
  db.prepare('UPDATE event_invites SET disabled = ? WHERE id = ?').run(disabled ? 1 : 0, Number(id));
}

/**
 * Un invité réclame sa place. Renvoie {status:'granted'|'pending'|'already'}
 * ou {error, code} (lien inconnu / désactivé / épuisé).
 */
function redeem(invite, email) {
  ensure();
  if (!invite || invite.disabled) return { error: "Ce lien d'invitation n'est plus valable.", code: 410 };
  const canon = access.canonEmail(email);
  return db.transaction(() => {
    const seen = db.prepare('SELECT 1 FROM event_invite_uses WHERE invite_id = ? AND email = ?').get(invite.id, canon);
    if (!seen) {
      const fresh = db.prepare('SELECT used, max_uses FROM event_invites WHERE id = ?').get(invite.id);
      if (fresh.used >= fresh.max_uses) return { error: 'Toutes les places de cette invitation ont été prises.', code: 409 };
      db.prepare('INSERT INTO event_invite_uses (invite_id, email) VALUES (?, ?)').run(invite.id, canon);
      db.prepare('UPDATE event_invites SET used = used + 1 WHERE id = ?').run(invite.id);
    }
    // Même mécanique que les places offertes par l'artiste : billet immédiat si
    // un compte vérifié porte cet e-mail, sinon place en attente du compte.
    const r = access.grantByEmail({
      email: canon, eventId: invite.event_id, pricePaid: 0, storeFeeRate: 0,
      source: 'artist_gift', ref: `${invite.event_id}:${canon}`,
    });
    return { status: r.status };
  })();
}

function uses(inviteId) {
  ensure();
  return db.prepare('SELECT email, created_at FROM event_invite_uses WHERE invite_id = ? ORDER BY created_at DESC').all(Number(inviteId));
}

module.exports = { ensure, create, get, byCode, listForEvent, setDisabled, redeem, uses };

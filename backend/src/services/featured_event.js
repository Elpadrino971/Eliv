'use strict';

/**
 * Événement « à la une » au lancement de l'app (lot 4).
 *
 * L'admin choisit un concert ; l'app affiche une popup au démarrage tant que
 * la mise en avant est active. Tout est piloté depuis le serveur (aucune
 * mise à jour store) : réglage `settings.featured_event` =
 * JSON { event_id, headline, until } (`until` ISO UTC).
 *
 * Par défaut la mise en avant s'arrête à la fin du concert (end_date_time),
 * sinon 6 h après son début, sinon 7 jours après le réglage.
 */

const { db } = require('../db');
const { normalizeIsoUtc } = require('./event_access');

const KEY = 'featured_event';
const HEADLINE_MAX = 120;
const SIX_HOURS_MS = 6 * 60 * 60 * 1000;
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
// Statuts pour lesquels la mise en avant ne s'affiche pas (concert masqué / annulé).
const HIDDEN_STATUS = new Set(['blocked', 'cancelled']);

/** Réglage brut tel qu'enregistré, ou null. */
function getSetting() {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(KEY);
  if (!row || !row.value) return null;
  try {
    const v = JSON.parse(row.value);
    if (!v || !Number.isInteger(Number(v.event_id))) return null;
    return { event_id: Number(v.event_id), headline: v.headline || null, until: v.until || null };
  } catch (_) {
    return null;
  }
}

function defaultUntil(event) {
  const end = normalizeIsoUtc(event.end_date_time);
  if (end.ok && end.value) return end.value;
  const start = normalizeIsoUtc(event.start_date_time);
  if (start.ok && start.value) return new Date(Date.parse(start.value) + SIX_HOURS_MS).toISOString();
  return new Date(Date.now() + SEVEN_DAYS_MS).toISOString();
}

function isExpired(until) {
  if (!until) return false;
  const t = Date.parse(until);
  return Number.isFinite(t) && t <= Date.now();
}

/**
 * Mise en avant ACTIVE : réglage présent, concert existant et visible,
 * `until` non dépassé. Sinon null.
 * @returns {{event_id:number, headline:string|null, until:string, event:object}|null}
 */
function resolve() {
  const s = getSetting();
  if (!s) return null;
  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(s.event_id);
  if (!event) return null;
  if (HIDDEN_STATUS.has(String(event.status || '').toLowerCase())) return null;
  if (isExpired(s.until)) return null;
  return { event_id: event.id, headline: s.headline, until: s.until, event };
}

/**
 * Enregistre la mise en avant.
 * @returns {{ok:true, setting:object}|{ok:false, error:string, code:number}}
 */
function set({ event_id, headline, until }) {
  const id = Number(event_id);
  if (!Number.isInteger(id) || id <= 0) return { ok: false, error: 'event_id requis.', code: 422 };
  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(id);
  if (!event) return { ok: false, error: 'Concert introuvable.', code: 422 };
  if (HIDDEN_STATUS.has(String(event.status || '').toLowerCase())) {
    return { ok: false, error: `Ce concert est ${event.status === 'blocked' ? 'bloqué' : 'annulé'} : impossible de le mettre à la une.`, code: 422 };
  }
  let h = headline == null ? null : String(headline).trim().slice(0, HEADLINE_MAX);
  if (h === '') h = null;
  const u = normalizeIsoUtc(until, 'until');
  if (!u.ok) return { ok: false, error: u.error, code: 422 };
  const untilIso = u.value || defaultUntil(event);
  if (isExpired(untilIso)) return { ok: false, error: 'La date de fin (until) est déjà passée.', code: 422 };
  const setting = { event_id: id, headline: h, until: untilIso };
  db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(KEY, JSON.stringify(setting));
  return { ok: true, setting, event };
}

function clear() {
  const info = db.prepare('DELETE FROM settings WHERE key = ?').run(KEY);
  return info.changes > 0;
}

/** Vue admin : réglage courant + résumé du concert (même si inactif), ou null. */
function adminView() {
  const s = getSetting();
  if (!s) return null;
  const event = db.prepare(
    `SELECT e.id, e.name, e.status, e.start_date_time, e.end_date_time, e.ticket_price, e.cover_image, u.artist_name AS artist
       FROM events e LEFT JOIN users u ON u.id = e.artist_id WHERE e.id = ?`
  ).get(s.event_id);
  const active = !!event && !HIDDEN_STATUS.has(String(event.status || '').toLowerCase()) && !isExpired(s.until);
  return { event_id: s.event_id, headline: s.headline, until: s.until, active, event: event || null };
}

module.exports = { KEY, getSetting, resolve, set, clear, adminView, defaultUntil };

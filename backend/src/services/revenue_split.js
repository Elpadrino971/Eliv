'use strict';

/**
 * Artistes invités sur un concert + partage de LA PART ARTISTE (lot 7).
 *
 * Un concert peut avoir des invités (table `event_guests`). Chaque invité a
 * `share_pct` = pourcentage de la PART ARTISTE (jamais du prix) qui lui est
 * reversé ; Σ share_pct ≤ 100, le reste revient à l'artiste principal.
 *
 * La répartition brut → store → net → part artiste / part plateforme /
 * apporteur ne change PAS (apporteur_ledger.computeForSale) : ce module ne
 * fait que découper la part artiste déjà calculée, entre le principal et ses
 * invités, et journaliser chaque mouvement dans `wallet_transactions`
 * (type 'ticket_share', une ligne par bénéficiaire). Les tips / cadeaux ne
 * sont PAS partagés (hors périmètre).
 */

const { db: defaultDb } = require('../db');
const { round2 } = require('./apporteur');
const { profileUrl } = require('../helpers');

// Bornes de sécurité (pas un contrat métier) : au-delà, on refuse.
const MAX_GUESTS = 10;
const PCT_EPS = 1e-6;

const num = (v) => (typeof v === 'number' ? v : parseFloat(v));
const fmtPct = (pct) => String(Math.round(num(pct) * 100) / 100).replace('.', ',');

/** Invités d'un concert, avec le profil public (sans e-mail). */
function listGuests(eventId, db = defaultDb) {
  return db.prepare(
    `SELECT g.user_id, g.share_pct, u.artist_name, u.full_name, u.profile_image
       FROM event_guests g LEFT JOIN users u ON u.id = g.user_id
      WHERE g.event_id = ? ORDER BY g.id ASC`
  ).all(Number(eventId)).map((g) => ({
    user_id: g.user_id,
    artist_name: g.artist_name || g.full_name || null,
    full_name: g.full_name || null,
    profile_image: profileUrl(g.profile_image),
    share_pct: round2(g.share_pct),
  }));
}

function sumPct(guests) {
  return round2(guests.reduce((n, g) => n + num(g.share_pct), 0));
}

/** Vue renvoyée par GET/PUT /events/:id/guests. */
function guestsView(eventId, db = defaultDb) {
  const guests = listGuests(eventId, db);
  return { guests, remaining_pct: round2(100 - sumPct(guests)) };
}

/**
 * Lit le champ `guests` (tableau JSON, ou chaîne JSON en multipart / form).
 * @returns {{ok:true, guests:Array}|{ok:false, error:string}}
 */
function parseGuests(raw) {
  if (raw == null) return { ok: true, guests: [] };
  let v = raw;
  if (typeof v === 'string') {
    if (v.trim() === '') return { ok: true, guests: [] };
    try { v = JSON.parse(v); } catch (_) {
      return { ok: false, error: 'guests : JSON invalide (attendu [{"user_id":12,"share_pct":30}]).' };
    }
  }
  if (!Array.isArray(v)) return { ok: false, error: 'guests : une liste est attendue.' };
  return { ok: true, guests: v };
}

/**
 * Valide la liste : artistes existants, ≠ propriétaire, pas de doublon, pct
 * 1–100 chacun, Σ ≤ 100, au plus MAX_GUESTS.
 * @returns {{ok:true, guests:Array<{user_id:number, share_pct:number}>}|{ok:false, error:string}}
 */
function validateGuests(raw, ownerId, db = defaultDb) {
  const parsed = parseGuests(raw);
  if (!parsed.ok) return parsed;
  const out = [];
  const seen = new Set();
  if (parsed.guests.length > MAX_GUESTS) return { ok: false, error: `Au plus ${MAX_GUESTS} artistes invités par concert.` };
  for (const g of parsed.guests) {
    const userId = Number(g && g.user_id);
    const pct = num(g && g.share_pct);
    if (!Number.isInteger(userId) || userId <= 0) return { ok: false, error: 'Invité invalide : user_id manquant.' };
    if (!Number.isFinite(pct) || pct < 1 - PCT_EPS || pct > 100 + PCT_EPS) {
      return { ok: false, error: `Invité #${userId} : la part doit être comprise entre 1 et 100 %.` };
    }
    if (userId === Number(ownerId)) return { ok: false, error: 'L’artiste principal ne peut pas être son propre invité.' };
    if (seen.has(userId)) return { ok: false, error: `Invité #${userId} en double.` };
    seen.add(userId);
    const u = db.prepare('SELECT id, is_artist FROM users WHERE id = ?').get(userId);
    if (!u) return { ok: false, error: `Invité #${userId} : utilisateur introuvable.` };
    if (Number(u.is_artist) !== 1) return { ok: false, error: `Invité #${userId} : ce compte n’est pas un artiste.` };
    out.push({ user_id: userId, share_pct: round2(pct) });
  }
  const total = sumPct(out);
  if (total > 100 + PCT_EPS) {
    return { ok: false, error: `La somme des parts des invités (${fmtPct(total)} %) dépasse 100 % de la part artiste.` };
  }
  return { ok: true, guests: out };
}

/** Billets PAYÉS non remboursés sur ce concert (une vente = répartition figée). */
function hasPaidSales(eventId, db = defaultDb) {
  return !!db.prepare(
    `SELECT 1 FROM tickets WHERE event_id = ? AND CAST(price_paid AS REAL) > 0
       AND COALESCE(status, 'active') <> 'refunded' LIMIT 1`
  ).get(Number(eventId));
}

function sameSplit(a, b) {
  if (a.length !== b.length) return false;
  const key = (list) => list.map((g) => `${g.user_id}:${round2(g.share_pct).toFixed(2)}`).sort().join('|');
  return key(a) === key(b);
}

/** Remplace la liste (à appeler dans une transaction, liste déjà validée). */
function writeGuests(eventId, guests, db = defaultDb) {
  db.prepare('DELETE FROM event_guests WHERE event_id = ?').run(Number(eventId));
  const ins = db.prepare('INSERT INTO event_guests (event_id, user_id, share_pct) VALUES (?, ?, ?)');
  for (const g of guests) ins.run(Number(eventId), g.user_id, g.share_pct);
}

/**
 * PUT /events/:id/guests : valide puis remplace. Refusé (409) si le concert a
 * déjà des billets vendus ET que la répartition change (on ne réécrit pas
 * l'histoire des ventes passées).
 * @returns {{ok:true, data:object}|{ok:false, code:number, error:string}}
 */
function replaceGuests(eventId, ownerId, raw, db = defaultDb) {
  const v = validateGuests(raw, ownerId, db);
  if (!v.ok) return { ok: false, code: 422, error: v.error };
  const current = listGuests(eventId, db);
  if (!sameSplit(current, v.guests) && hasPaidSales(eventId, db)) {
    return {
      ok: false, code: 409,
      error: 'Des billets ont déjà été vendus pour ce concert : la répartition entre artistes ne peut plus être modifiée.',
    };
  }
  db.transaction(() => writeGuests(eventId, v.guests, db))();
  return { ok: true, data: guestsView(eventId, db) };
}

/**
 * Découpe la part artiste d'une vente entre le principal et ses invités.
 * Arrondis à 2 décimales ; le reste des arrondis va à l'artiste principal.
 * @returns {Array<{user_id:number, amount:number, pct:number, role:'main'|'guest'}>} (montants > 0 seulement)
 */
function splitArtistShare(eventId, artistShareEur, db = defaultDb) {
  const share = round2(artistShareEur);
  if (!(share > 0)) return [];
  const event = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(Number(eventId));
  if (!event || !event.artist_id) return [];
  const guests = db.prepare('SELECT user_id, share_pct FROM event_guests WHERE event_id = ? ORDER BY id ASC').all(Number(eventId));
  let rest = share;
  let pctGuests = 0;
  const parts = [];
  for (const g of guests) {
    const pct = Math.max(0, Math.min(100, num(g.share_pct)));
    const amount = round2(share * pct / 100);
    pctGuests += pct;
    if (amount > 0) {
      parts.push({ user_id: g.user_id, amount, pct: round2(pct), role: 'guest' });
      rest = round2(rest - amount);
    }
  }
  const main = { user_id: event.artist_id, amount: round2(Math.max(0, rest)), pct: round2(Math.max(0, 100 - pctGuests)), role: 'main' };
  return [main, ...parts].filter((p) => p.amount > 0);
}

function eventName(eventId, db) {
  const e = db.prepare('SELECT name FROM events WHERE id = ?').get(Number(eventId));
  return (e && e.name) || `concert #${eventId}`;
}

function addToWallet(db, userId, delta) {
  const u = db.prepare('SELECT wallet FROM users WHERE id = ?').get(userId);
  if (!u) return null;
  const wallet = parseFloat(u.wallet) || 0;
  const next = wallet + delta;
  db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(Math.max(0, round2(next)).toFixed(2), userId);
  return { before: wallet, after: Math.max(0, round2(next)), shortfall: next < -0.005 ? round2(-next) : 0 };
}

const insertTx = (db) => db.prepare(
  `INSERT INTO wallet_transactions (user_id, role, direction, type, title, description, amount, source, source_id)
   VALUES (?, 'price', ?, 'ticket_share', ?, ?, ?, ?, ?)`
);

/**
 * Crédite le wallet de chaque bénéficiaire (principal + invités) et écrit une
 * ligne `wallet_transactions` (type 'ticket_share') par bénéficiaire. À
 * appeler DANS la transaction de la vente. Rien n'est écrit pour 0 €.
 * @param {{ticketId:number, source:string}} p source = 'ticket' | 'ticket_web'
 * @returns la liste des parts créditées
 */
function creditArtistShare(db, eventId, artistShareEur, { ticketId, source } = {}) {
  const parts = splitArtistShare(eventId, artistShareEur, db);
  if (!parts.length) return parts;
  const name = eventName(eventId, db);
  const tx = insertTx(db);
  for (const p of parts) {
    addToWallet(db, p.user_id, p.amount);
    tx.run(
      p.user_id, 'credit',
      p.role === 'guest' ? 'Part artiste invité (billet)' : 'Part artiste (billet)',
      `Part sur ${name} (${fmtPct(p.pct)} %)`,
      p.amount.toFixed(2), source || 'ticket', ticketId != null ? String(ticketId) : null,
    );
  }
  return parts;
}

/**
 * Remboursement : reprend à chacun exactement ce qui lui avait été crédité
 * pour ce billet (lignes 'ticket_share' du billet ; à défaut — billet vendu
 * avant ce lot — même découpe que la vente). Jamais sous 0 : le manque est
 * journalisé pour régularisation manuelle.
 * @returns la liste des parts débitées
 */
function debitArtistShare(db, eventId, artistShareEur, { ticketId, source } = {}) {
  let parts = [];
  if (ticketId != null) {
    parts = db.prepare(
      `SELECT user_id, CAST(amount AS REAL) AS amount, description FROM wallet_transactions
        WHERE type = 'ticket_share' AND direction = 'credit' AND source_id = ? ORDER BY id ASC`
    ).all(String(ticketId)).map((l) => ({ user_id: l.user_id, amount: round2(l.amount), description: l.description }));
  }
  if (!parts.length) {
    parts = splitArtistShare(eventId, artistShareEur, db).map((p) => ({
      user_id: p.user_id, amount: p.amount, description: `Part sur ${eventName(eventId, db)} (${fmtPct(p.pct)} %)`,
    }));
  }
  const tx = insertTx(db);
  for (const p of parts) {
    const r = addToWallet(db, p.user_id, -p.amount);
    if (r && r.shortfall > 0) {
      console.warn(`[remboursement] wallet #${p.user_id} insuffisant : ${p.amount.toFixed(2)} € à reprendre, ${r.before.toFixed(2)} € disponibles (billet #${ticketId}) -> à régulariser à la main`);
    }
    tx.run(
      p.user_id, 'debit', 'Remboursement de billet',
      `Remboursement — ${p.description}`,
      p.amount.toFixed(2), source || 'ticket', ticketId != null ? String(ticketId) : null,
    );
  }
  return parts;
}

/**
 * Estimation de revenus pour UN prix de la grille, avec les MÊMES fonctions
 * que la vente réelle (apporteur_ledger.computeForSale), sans rien écrire.
 * Contrat de GET /api/pricing/estimate.
 * @returns {{ok:true, data:object}|{ok:false, error:string, grid:number[]}}
 */
function estimatePricing(artistId, rawPrice, { nowMs } = {}) {
  // Requis ici (et non en tête) : event_access dépend de ce module.
  const { ALLOWED_TICKET_PRICES, normalizeTicketPrice } = require('./event_access');
  const apporteurLedger = require('./apporteur_ledger');
  const engine = require('./apporteur');
  const grid = ALLOWED_TICKET_PRICES.slice();
  if (rawPrice == null || String(rawPrice).trim() === '') {
    return { ok: false, error: 'Paramètre price requis (prix de la grille).', grid };
  }
  const p = normalizeTicketPrice(rawPrice);
  if (!p.ok) return { ok: false, error: p.error, grid };
  const price = parseFloat(p.value) || 0;
  const now = Number.isFinite(nowMs) ? nowMs : Date.now();
  const { ctx, artistRatePct, breakdown } = apporteurLedger.computeForSale(artistId, price, { nowMs: now });
  const promo = !!(ctx.subFreeUntilMs && now < ctx.subFreeUntilMs);
  return {
    ok: true,
    data: {
      price: round2(price),
      store_fee_rate: engine.STORE_FEE_RATE,
      net: round2(breakdown.net),
      artist_rate: Math.round(artistRatePct * 10) / 1000, // 58.8 -> 0.588
      artist_share: round2(breakdown.artist),
      platform_share: round2(breakdown.platform),
      promo,
      currency: 'EUR',
      grid,
    },
  };
}

/**
 * Admin : répartition estimée de la part artiste au prix du concert, avec
 * les noms (principal + invités).
 */
function estimateForEvent(eventId, db = defaultDb) {
  const event = db.prepare('SELECT id, name, artist_id, ticket_price FROM events WHERE id = ?').get(Number(eventId));
  if (!event) return null;
  const est = estimatePricing(event.artist_id, event.ticket_price);
  const base = est.ok ? est.data : null;
  const artistShare = base ? base.artist_share : 0;
  const nameOf = (id) => {
    const u = db.prepare('SELECT artist_name, full_name FROM users WHERE id = ?').get(id);
    return (u && (u.artist_name || u.full_name)) || `#${id}`;
  };
  const guests = listGuests(eventId, db);
  const pctGuests = sumPct(guests);
  // Découpe théorique (sans dépendre d'une vente) : même arrondi que la vente.
  const parts = [];
  let rest = artistShare;
  for (const g of guests) {
    const amount = round2(artistShare * g.share_pct / 100);
    parts.push({ user_id: g.user_id, name: g.artist_name || nameOf(g.user_id), pct: g.share_pct, amount, role: 'guest' });
    rest = round2(rest - amount);
  }
  parts.unshift({ user_id: event.artist_id, name: nameOf(event.artist_id), pct: round2(100 - pctGuests), amount: round2(Math.max(0, rest)), role: 'main' });
  return {
    price: parseFloat(event.ticket_price) || 0,
    net: base ? base.net : 0,
    artist_share: artistShare,
    platform_share: base ? base.platform_share : 0,
    artist_rate: base ? base.artist_rate : null,
    promo: base ? base.promo : false,
    parts,
  };
}

module.exports = {
  MAX_GUESTS,
  listGuests, guestsView, parseGuests, validateGuests, hasPaidSales, writeGuests, replaceGuests,
  splitArtistShare, creditArtistShare, debitArtistShare,
  estimatePricing, estimateForEvent,
};

'use strict';

/**
 * Tarification dynamique d'un concert (yield management, lot 9).
 *
 * `events.price_schedule` (JSON) = liste de paliers, `hours_before`
 * STRICTEMENT décroissants, chaque prix dans la grille IAP (ticket_<n>) :
 *   [{"hours_before":72,"price":"4.99"},
 *    {"hours_before":48,"price":"6.99"},
 *    {"hours_before":0, "price":"9.99"}]
 * se lit : jusqu'à 72 h avant le début -> 4,99 ; entre 72 h et 48 h -> 6,99 ;
 * de 48 h jusqu'au début (et pendant le live / replay) -> 9,99.
 * Un palier vaut JUSQU'À `start_date_time - hours_before` (sa fin), à partir
 * de la fin du palier précédent (le premier vaut depuis toujours). Passé la
 * fin du dernier palier, son prix persiste (live, replay). Sans grille ou
 * sans date de début, le prix est le prix de base `events.ticket_price`
 * (qui reste aussi la référence des estimations admin).
 *
 * Le prix effectif est calculé côté serveur à chaque lecture : l'app continue
 * d'acheter le produit `ticket_<partie entière>` dérivé de `ticket_price`
 * (qui devient le prix effectif dans serializeEvent) — rien à changer côté app.
 */

const MAX_TIERS = 5;
const HOUR_MS = 3600 * 1000;
// Tolérance de bascule (/buy-ticket) : le fan a vu l'ancien prix, a payé le
// produit correspondant, et l'appel serveur arrive juste après le changement
// de palier -> on accepte encore l'ancien produit pendant 30 minutes.
const SWITCH_GRACE_MS = 30 * 60 * 1000;

// Requis paresseusement : event_access dépend de helpers, qui dépend d'ici.
function grid() {
  return require('./event_access');
}

/** Produit store d'un prix ('6.99' -> 'ticket_6'). */
function productIdFor(price) {
  return `ticket_${Math.floor(parseFloat(price) || 0)}`;
}

/**
 * Valide/normalise une grille (JSON string, tableau, vide/null).
 * @returns {{ok:true, schedule:Array<{hours_before:number, price:string}>}|{ok:false, error:string}}
 */
function parseSchedule(raw) {
  if (raw == null) return { ok: true, schedule: [] };
  let list = raw;
  if (typeof raw === 'string') {
    if (raw.trim() === '' || raw.trim() === '[]') return { ok: true, schedule: [] };
    try { list = JSON.parse(raw); } catch (_) {
      return { ok: false, error: 'Grille tarifaire illisible (JSON attendu : [{"hours_before":72,"price":"4.99"}, …]).' };
    }
  }
  if (!Array.isArray(list)) return { ok: false, error: 'Grille tarifaire invalide : une liste de paliers est attendue.' };
  if (list.length === 0) return { ok: true, schedule: [] };
  if (list.length > MAX_TIERS) return { ok: false, error: `Grille tarifaire : ${MAX_TIERS} paliers maximum.` };
  const { normalizeTicketPrice } = grid();
  const out = [];
  let prevHours = null;
  for (let i = 0; i < list.length; i++) {
    const t = list[i] || {};
    const hours = Number(String(t.hours_before ?? '').trim().replace(',', '.'));
    if (!Number.isFinite(hours) || hours < 0) {
      return { ok: false, error: `Palier ${i + 1} : « hours_before » doit être un nombre d'heures ≥ 0.` };
    }
    if (prevHours !== null && hours >= prevHours) {
      return { ok: false, error: `Palier ${i + 1} : les heures avant le début doivent être strictement décroissantes (${prevHours} h puis ${hours} h).` };
    }
    const p = normalizeTicketPrice(t.price);
    if (!p.ok) return { ok: false, error: `Palier ${i + 1} : ${p.error}` };
    if (parseFloat(p.value) <= 0) {
      return { ok: false, error: `Palier ${i + 1} : un palier doit avoir un prix payant de la grille (pas « gratuit »).` };
    }
    out.push({ hours_before: hours, price: p.value });
    prevHours = hours;
  }
  return { ok: true, schedule: out };
}

/** Grille stockée -> liste (tolérant : une valeur illisible vaut « pas de grille »). */
function scheduleOf(event) {
  const r = parseSchedule(event ? event.price_schedule : null);
  return r.ok ? r.schedule : [];
}

function basePriceOf(event) {
  const raw = event ? event.ticket_price : null;
  const n = parseFloat(raw);
  if (!Number.isFinite(n) || n <= 0) return '0';
  // Conserve la chaîne stockée ('4.99') ; normalise un nombre éventuel.
  return typeof raw === 'string' ? raw : n.toFixed(2);
}

/**
 * Prix EFFECTIF d'un concert à l'instant `now`.
 * @returns {{price:string, base:string, next_price:string|null, next_price_at:string|null, schedule:Array}}
 */
function effectivePrice(event, now = Date.now()) {
  const base = basePriceOf(event);
  const schedule = scheduleOf(event);
  const out = { price: base, base, next_price: null, next_price_at: null, schedule };
  if (!schedule.length) return out;
  const start = event && event.start_date_time ? Date.parse(String(event.start_date_time).replace(' ', 'T')) : NaN;
  if (!Number.isFinite(start)) return out;
  // Paliers en hours_before décroissants = fins croissantes. Le palier
  // courant est le PREMIER dont la fin (start - hours_before) est encore à
  // venir ; sa fin donne next_price_at et le palier suivant next_price.
  // Toutes les fins passées (après le début si le dernier palier est à 0 h)
  // -> le dernier palier persiste, sans « prochain prix ».
  const endOf = (t) => start - t.hours_before * HOUR_MS;
  let current = schedule.findIndex((t) => now < endOf(t));
  if (current === -1) {
    out.price = schedule[schedule.length - 1].price;
    return out;
  }
  out.price = schedule[current].price;
  const next = schedule[current + 1];
  if (next) {
    out.next_price = next.price;
    out.next_price_at = new Date(endOf(schedule[current])).toISOString();
  }
  return out;
}

/**
 * Prix acceptés à l'achat (/buy-ticket) : le prix effectif, plus le prix du
 * palier précédent pendant SWITCH_GRACE_MS après une bascule.
 * @returns {Array<{price:string, product_id:string, current:boolean}>}
 */
function acceptedPrices(event, now = Date.now()) {
  const cur = effectivePrice(event, now).price;
  const list = [{ price: cur, product_id: productIdFor(cur), current: true }];
  const before = effectivePrice(event, now - SWITCH_GRACE_MS).price;
  if (before !== cur && parseFloat(before) > 0) {
    list.push({ price: before, product_id: productIdFor(before), current: false });
  }
  return list;
}

module.exports = {
  MAX_TIERS, SWITCH_GRACE_MS,
  parseSchedule, scheduleOf, effectivePrice, acceptedPrices, productIdFor,
};

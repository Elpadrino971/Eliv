'use strict';

/**
 * Roue de la fortune — places offertes pour un concert.
 *
 * Le tirage se fait ICI, côté serveur, jamais dans le navigateur : sinon
 * n'importe qui pourrait forcer le gain et vider les places en une heure.
 * La page ne fait qu'animer la roue vers le résultat que le serveur a déjà
 * décidé.
 *
 * Règles (reprises dans le règlement public, site/roue-reglement.html) :
 *  - un seul tirage par adresse e-mail et par campagne ;
 *  - une chance sur quatre de gagner, dans la limite des places ;
 *  - une place gagnée est réservée 24 h : il faut confirmer l'e-mail via le
 *    lien reçu, sinon elle retourne dans le jeu ;
 *  - la place devient un billet du compte VybzzZ lié à cet e-mail (tout de
 *    suite si le compte existe, sinon dès qu'il est créé).
 */

const crypto = require('crypto');
const { db } = require('../db');
const access = require('./event_access');
const email = require('./email');
const pricing = require('./pricing');
const { PUBLIC_BASE_URL } = require('../uploads');

const CAMPAIGNS = {
  'dj-wilson': {
    slug: 'dj-wilson',
    title: 'DJ Wilson — Anniversaire',
    artist: 'DJ Wilson',
    guests: ['Jocelyne Labylle', 'Dominique Lorté', 'Jean-Michel Jean-Louis'],
    // 23h50 aux Antilles et à Montréal le samedi 3 octobre,
    // 5h50 à Paris le dimanche 4 : c'est le même instant.
    startsAt: '2026-10-04T03:50:00Z',
    // La roue ferme 30 minutes avant le live, pour que les gagnants aient le
    // temps de confirmer et d'ouvrir l'app.
    wheelClosesAt: '2026-10-04T03:20:00Z',
    places: 100,
    odds: 0.25,
    reserveHours: 24,
    fallbackPrice: '4.99',
  },
};

// Tirages max par IP et par campagne. 5 couvre une famille derrière la même
// box tout en coupant court aux rafales d'adresses depuis une seule
// connexion (l'e-mail est déjà normalisé Gmail + domaines jetables refusés).
const IP_CAP = Number(process.env.WHEEL_IP_CAP) || 5;

function campaign(slug) {
  return CAMPAIGNS[slug] || null;
}

function settingKey(slug) { return `campaign_event:${slug}`; }

function linkedEventId(slug) {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(settingKey(slug));
  const id = Number(row?.value);
  return Number.isFinite(id) && id > 0 ? id : null;
}

function linkEvent(slug, eventId) {
  db.prepare(
    `INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`
  ).run(settingKey(slug), String(eventId));
}

function expireReservations(c) {
  db.prepare(
    `UPDATE wheel_spins SET status = 'expired'
      WHERE campaign = ? AND status = 'reserved' AND datetime(created_at) < datetime('now', ?)`
  ).run(c.slug, `-${c.reserveHours} hours`);
}

function taken(c) {
  return db.prepare(
    `SELECT COUNT(*) n FROM wheel_spins WHERE campaign = ? AND result = 'win'
       AND status IN ('reserved','claimed','granted')`
  ).get(c.slug).n;
}

function remaining(c) {
  expireReservations(c);
  return Math.max(0, c.places - taken(c));
}

function isOpen(c) {
  return Date.now() < Date.parse(c.wheelClosesAt);
}

function publicStatus(slug) {
  const c = campaign(slug);
  if (!c) return null;
  const eventId = linkedEventId(slug);
  const event = eventId ? db.prepare('SELECT id, name, ticket_price, price_schedule, start_date_time FROM events WHERE id = ?').get(eventId) : null;
  // Prix EFFECTIF (tarification dynamique, lot 9) + prochain palier pour la
  // ligne d'urgence du site (« Passe à 9,99 € dans 5 h 12 »).
  const price = event ? pricing.effectivePrice(event) : null;
  return {
    slug: c.slug,
    title: c.title,
    artist: c.artist,
    guests: c.guests,
    starts_at: c.startsAt,
    wheel_closes_at: c.wheelClosesAt,
    wheel_open: isOpen(c),
    places: c.places,
    remaining: remaining(c),
    odds: c.odds,
    price: price ? price.price : c.fallbackPrice,
    next_price: price ? price.next_price : null,
    next_price_at: price ? price.next_price_at : null,
    ticketing_open: !!event && Date.now() < Date.parse(c.startsAt) + 3 * 3600 * 1000,
    event_id: event ? event.id : null,
  };
}

function winEmailHtml(c, link) {
  return `<!doctype html><html lang="fr"><body style="margin:0;background:#0A1226;font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#F4EFE3">
<div style="max-width:520px;margin:0 auto;padding:36px 26px;text-align:center">
  <div style="font-weight:800;letter-spacing:.12em;font-size:18px">Vybzz<span style="color:#E6C76A">Z</span></div>
  <h1 style="font-size:24px;margin:28px 0 10px">Tu as gagné ta place !</h1>
  <p style="color:#B9C0D0;line-height:1.6;margin:0 0 26px">${c.title} · en direct sur VybzzZ<br>
  Samedi 3 octobre, 23h50 aux Antilles et à Montréal · dimanche 4, 5h50 à Paris.</p>
  <a href="${link}" style="display:inline-block;background:#E6C76A;color:#0A1226;text-decoration:none;font-weight:700;padding:15px 28px;border-radius:12px">Confirmer et récupérer ma place</a>
  <p style="color:#B9C0D0;font-size:13px;line-height:1.6;margin:26px 0 0">Ce lien est valable 24 heures. Sans confirmation, ta place retourne dans le jeu.<br>
  Ta place sera ajoutée à ton compte VybzzZ lié à cette adresse e-mail : connecte-toi dans l'app avec la même adresse pour rejoindre le live.</p>
</div></body></html>`;
}

/**
 * Un tirage. Renvoie { result: 'win'|'lose', remaining } ou { error }.
 */
async function spin(slug, rawEmail, ipHash) {
  const c = campaign(slug);
  if (!c) return { error: 'Campagne introuvable.', code: 404 };
  if (!isOpen(c)) return { error: 'La roue est fermée : le live commence bientôt.', code: 410 };

  const typed = access.normEmail(rawEmail);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(typed) || typed.length > 190) {
    return { error: 'Adresse e-mail invalide.', code: 422 };
  }
  if (access.isDisposableEmail(typed)) {
    return { error: "Adresse e-mail jetable refusée : joue avec ton adresse habituelle, c'est là que ta place arrive.", code: 422 };
  }
  // Clé du tirage = adresse canonique (Gmail : points et +tag ignorés) : une
  // seule boîte = un seul tirage. On cherche aussi l'ancienne forme (tirages
  // enregistrés avant la normalisation).
  const e = access.canonEmail(typed);
  const keys = access.emailKeys(typed);

  const prev = db.prepare(
    `SELECT result, status FROM wheel_spins WHERE campaign = ? AND email IN (${keys.map(() => '?').join(',')}) ORDER BY id ASC LIMIT 1`
  ).get(c.slug, ...keys);
  if (prev) {
    return { already: true, result: prev.result, status: prev.status, remaining: remaining(c) };
  }
  if (ipHash) {
    const n = db.prepare('SELECT COUNT(*) n FROM wheel_spins WHERE campaign = ? AND ip_hash = ?').get(c.slug, ipHash).n;
    if (n >= IP_CAP) return { error: 'Trop de participations depuis cette connexion.', code: 429 };
  }

  const left = remaining(c);
  const win = left > 0 && crypto.randomInt(0, 10000) < Math.round(c.odds * 10000);
  const token = win ? crypto.randomBytes(24).toString('base64url') : null;
  try {
    db.prepare(
      `INSERT INTO wheel_spins (campaign, email, ip_hash, result, status, token) VALUES (?, ?, ?, ?, ?, ?)`
    ).run(c.slug, e, ipHash || null, win ? 'win' : 'lose', win ? 'reserved' : 'lost', token);
  } catch (err) {
    // Double clic ou deux onglets : le premier tirage fait foi.
    const again = db.prepare('SELECT result, status FROM wheel_spins WHERE campaign = ? AND email = ?').get(c.slug, e);
    if (again) return { already: true, result: again.result, status: again.status, remaining: remaining(c) };
    throw err;
  }

  let mailed = false;
  if (win) {
    const link = `${PUBLIC_BASE_URL}/api/wheel/claim?t=${token}`;
    try {
      // Envoi à l'adresse telle que saisie (même boîte que la forme canonique).
      await email.sendEmail({ to: typed, subject: `Tu as gagné ta place pour ${c.artist}`, html: winEmailHtml(c, link), kind: 'wheel' });
      mailed = true;
    } catch (err) {
      console.error(`[roue] e-mail de gain non envoyé (${access.maskEmail(typed)}) :`, err.message);
    }
  }
  return { result: win ? 'win' : 'lose', remaining: Math.max(0, left - (win ? 1 : 0)), mailed };
}

/** Confirmation du gain via le lien reçu par e-mail. */
function claim(token) {
  const row = token ? db.prepare('SELECT * FROM wheel_spins WHERE token = ?').get(String(token)) : null;
  if (!row || row.result !== 'win') return { state: 'invalid' };
  const c = campaign(row.campaign);
  if (!c) return { state: 'invalid' };

  if (row.status === 'expired') {
    // Réservation dépassée : si une place est encore libre, on la lui rend.
    if (remaining(c) <= 0) return { state: 'expired', email: row.email };
    db.prepare("UPDATE wheel_spins SET status = 'reserved' WHERE id = ?").run(row.id);
    row.status = 'reserved';
  }
  if (row.status === 'reserved') {
    db.prepare("UPDATE wheel_spins SET status = 'claimed', claimed_at = datetime('now') WHERE id = ?").run(row.id);
  }
  const granted = grantOne(c, row.id);
  return { state: 'claimed', email: row.email, ...granted };
}

/** Transforme un gain confirmé en place (billet, ou place en attente de compte). */
function grantOne(c, spinId) {
  const row = db.prepare('SELECT * FROM wheel_spins WHERE id = ?').get(spinId);
  const eventId = linkedEventId(c.slug);
  if (!row || !eventId) return { granted: false, account: !!access.findUserByEmail(row?.email) };
  const r = access.grantByEmail({ email: row.email, eventId, pricePaid: 0, source: 'wheel', ref: row.id });
  db.prepare("UPDATE wheel_spins SET status = 'granted', granted_at = COALESCE(granted_at, datetime('now')) WHERE id = ?").run(row.id);
  return { granted: true, account: r.status !== 'pending' };
}

/** Admin : attribue toutes les places confirmées (utile une fois le concert relié). */
function grantAllClaimed(slug) {
  const c = campaign(slug);
  if (!c || !linkedEventId(slug)) return 0;
  const rows = db.prepare("SELECT id FROM wheel_spins WHERE campaign = ? AND status = 'claimed'").all(c.slug);
  rows.forEach((r) => grantOne(c, r.id));
  return rows.length;
}

function adminView(slug) {
  const c = campaign(slug);
  if (!c) return null;
  expireReservations(c);
  const counts = db.prepare(
    `SELECT status, COUNT(*) n FROM wheel_spins WHERE campaign = ? GROUP BY status`
  ).all(c.slug);
  const winners = db.prepare(
    `SELECT id, email, status, created_at, claimed_at, granted_at FROM wheel_spins
      WHERE campaign = ? AND result = 'win' ORDER BY id DESC`
  ).all(c.slug);
  const eventId = linkedEventId(slug);
  const orders = eventId ? db.prepare(
    `SELECT email, amount, status, created_at, paid_at FROM web_ticket_orders WHERE event_id = ? ORDER BY id DESC LIMIT 300`
  ).all(eventId) : [];
  return { ...publicStatus(slug), counts, winners, orders };
}

module.exports = { CAMPAIGNS, campaign, publicStatus, spin, claim, linkEvent, linkedEventId, grantAllClaimed, adminView };

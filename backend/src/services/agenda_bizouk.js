'use strict';

/**
 * Agenda régional — collecte des concerts et spectacles de Guadeloupe,
 * Martinique et Guyane publiés sur bizouk.com.
 *
 * Pourquoi : la timeline de l'application ne montrait que les dates VybzzZ.
 * Un utilisateur qui l'ouvre voit désormais TOUT ce qui se passe près de chez
 * lui, et repère au passage ce que VybzzZ diffuse en direct.
 *
 * Comment, et pourquoi de cette façon :
 *  - bizouk publie des données structurées schema.org (JSON-LD `Event`) sur
 *    chaque fiche. C'est un format destiné à être lu par des machines : on le
 *    lit plutôt que de deviner la mise en page, ce qui est plus propre et ne
 *    casse pas au premier changement de design.
 *  - On respecte robots.txt : rien sous /api/, /admin/, /bo/, /account/,
 *    /login/, /compte/, /test/. L'URL /__sec/ est un piège anti-scraping,
 *    jamais appelée (voir SKIP_PREFIXES).
 *  - Une requête à la fois, espacée, et le sitemap donne un `lastmod` par
 *    fiche : on ne retélécharge que ce qui a bougé. Une synchronisation
 *    hebdomadaire ne represente donc que quelques dizaines de requêtes.
 *  - On ne conserve que des FAITS (titre, date, lieu, territoire, prix
 *    d'appel) et le lien vers la fiche d'origine. Aucune description n'est
 *    recopiée. La source est citée et cliquable côté application.
 */

const { db } = require('../db');

const SOURCE = 'bizouk';
const BASE = 'https://www.bizouk.com';
const SITEMAP_INDEX = `${BASE}/sitemap.xml`;
const USER_AGENT = 'VybzzZ-AgendaBot/1.0 (+https://vybzzz.online; contact@vybzzz.online)';

// Chemins interdits par robots.txt. /__sec/ est un piège : l'appeler signale
// le robot comme malveillant. On filtre en amont plutôt que de faire confiance
// au contenu du sitemap.
const SKIP_PREFIXES = ['/api/', '/admin/', '/bo/', '/account/', '/login/', '/compte/', '/test/', '/__sec/'];

// Territoires couverts. Le JSON-LD donne un addressCountry ISO fiable ; le code
// postal sert de filet quand il manque (971xx / 972xx / 973xx).
const TERRITORIES = { GP: 'Guadeloupe', MQ: 'Martinique', GF: 'Guyane' };
const POSTAL_PREFIX = { 971: 'GP', 972: 'MQ', 973: 'GF' };

const DELAY_MS = Number(process.env.AGENDA_DELAY_MS || 800);
const MAX_PAGES = Number(process.env.AGENDA_MAX_PAGES || 400);
const TIMEOUT_MS = 20000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,application/xml' },
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

function allowed(url) {
  try {
    const p = new URL(url).pathname;
    return !SKIP_PREFIXES.some((prefix) => p.startsWith(prefix));
  } catch {
    return false;
  }
}

/** Entrées <url> du sitemap des événements : { loc, lastmod }. */
async function fetchSitemap() {
  const index = await get(SITEMAP_INDEX);
  const sitemaps = [...index.matchAll(/<loc>([^<]+)<\/loc>/g)]
    .map((m) => m[1].trim())
    .filter((u) => /sitemap-events/i.test(u));

  const entries = [];
  for (const sm of sitemaps) {
    await sleep(DELAY_MS);
    const xml = await get(sm);
    for (const block of xml.split('<url>').slice(1)) {
      const loc = (block.match(/<loc>([^<]+)<\/loc>/) || [])[1];
      const lastmod = (block.match(/<lastmod>([^<]+)<\/lastmod>/) || [])[1] || null;
      if (loc && allowed(loc)) entries.push({ loc: loc.trim(), lastmod: lastmod && lastmod.trim() });
    }
  }
  return entries;
}

/** Extrait le bloc JSON-LD de type Event d'une fiche. */
function parseEventJsonLd(html) {
  const re = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    let data;
    try {
      data = JSON.parse(m[1]);
    } catch {
      continue; // bloc mal formé : on passe au suivant plutôt que d'échouer
    }
    const candidates = Array.isArray(data) ? data : [data];
    for (const c of candidates) {
      if (c && (c['@type'] === 'Event' || (Array.isArray(c['@type']) && c['@type'].includes('Event')))) {
        return c;
      }
    }
  }
  return null;
}

function territoryOf(address) {
  const country = String(address?.addressCountry || '').toUpperCase();
  if (TERRITORIES[country]) return country;
  const cp = String(address?.postalCode || '').replace(/\D/g, '');
  return POSTAL_PREFIX[cp.slice(0, 3)] || null;
}

function firstImage(image) {
  if (!image) return null;
  if (typeof image === 'string') return image;
  if (Array.isArray(image)) return image.find((x) => typeof x === 'string') || null;
  if (typeof image === 'object' && typeof image.url === 'string') return image.url;
  return null;
}

function offerPrice(offers) {
  const list = Array.isArray(offers) ? offers : offers ? [offers] : [];
  const prices = list
    .map((o) => parseFloat(o?.price ?? o?.lowPrice))
    .filter((n) => Number.isFinite(n) && n >= 0);
  if (!prices.length) return { price: null, currency: null };
  const cur = list.find((o) => o?.priceCurrency)?.priceCurrency || 'EUR';
  return { price: String(Math.min(...prices)), currency: cur };
}

function statusOf(eventStatus) {
  const s = String(eventStatus || '').toLowerCase();
  if (s.includes('cancelled')) return 'cancelled';
  if (s.includes('postponed')) return 'postponed';
  return 'scheduled';
}

/** Convertit un JSON-LD Event en ligne prête pour external_events, ou null. */
function toRow(ld, url, lastmod) {
  if (!ld?.name || !ld?.startDate) return null;
  const address = ld.location?.address || {};
  const territory = territoryOf(address);
  if (!territory) return null; // hors Antilles-Guyane : on ignore

  const sourceId = (url.match(/\/(\d+)\/?$/) || [])[1] || url;
  const { price, currency } = offerPrice(ld.offers);

  return {
    source: SOURCE,
    source_id: String(sourceId),
    source_url: url,
    title: String(ld.name).trim(),
    start_date: ld.startDate || null,
    end_date: ld.endDate || null,
    venue: (ld.location?.name || address.streetAddress || '').toString().trim() || null,
    city: (address.addressLocality || '').toString().trim() || null,
    postal_code: (address.postalCode || '').toString().trim() || null,
    territory,
    organizer: (ld.organizer?.name || '').toString().trim() || null,
    image: firstImage(ld.image),
    price_from: price,
    currency,
    status: statusOf(ld.eventStatus),
    source_lastmod: lastmod || null,
  };
}

function upsert(row) {
  const existing = db
    .prepare('SELECT id FROM external_events WHERE source = ? AND source_id = ?')
    .get(row.source, row.source_id);
  if (existing) {
    db.prepare(
      `UPDATE external_events SET source_url = @source_url, title = @title, start_date = @start_date,
          end_date = @end_date, venue = @venue, city = @city, postal_code = @postal_code,
          territory = @territory, organizer = @organizer, image = @image, price_from = @price_from,
          currency = @currency, status = @status, source_lastmod = @source_lastmod,
          last_seen_at = datetime('now'), updated_at = datetime('now')
        WHERE id = @id`
    ).run({ ...row, id: existing.id });
    return 'updated';
  }
  db.prepare(
    `INSERT INTO external_events
       (source, source_id, source_url, title, start_date, end_date, venue, city, postal_code,
        territory, organizer, image, price_from, currency, status, source_lastmod, last_seen_at)
     VALUES (@source, @source_id, @source_url, @title, @start_date, @end_date, @venue, @city,
             @postal_code, @territory, @organizer, @image, @price_from, @currency, @status,
             @source_lastmod, datetime('now'))`
  ).run(row);
  return 'inserted';
}

/**
 * Synchronisation. Ne télécharge une fiche que si elle est inconnue ou si son
 * `lastmod` a bougé depuis le dernier passage — une reprise hebdomadaire ne
 * coûte donc que quelques dizaines de requêtes.
 * @param {{force?: boolean, max?: number}} opts
 */
async function sync(opts = {}) {
  const started = Date.now();
  const max = Number(opts.max || MAX_PAGES);
  const stats = { vus: 0, telecharges: 0, inseres: 0, mis_a_jour: 0, ignores: 0, erreurs: 0 };

  const entries = await fetchSitemap();
  stats.vus = entries.length;

  const connus = new Map(
    db.prepare('SELECT source_id, source_lastmod FROM external_events WHERE source = ?')
      .all(SOURCE)
      .map((r) => [String(r.source_id), r.source_lastmod])
  );

  for (const { loc, lastmod } of entries) {
    if (stats.telecharges >= max) {
      console.log(`[agenda] plafond de ${max} fiches atteint, la suite au prochain passage.`);
      break;
    }
    const id = (loc.match(/\/(\d+)\/?$/) || [])[1];
    if (!opts.force && id && connus.has(id) && connus.get(id) === lastmod) {
      stats.ignores += 1;
      continue; // inchangé depuis la dernière fois
    }

    await sleep(DELAY_MS);
    try {
      const html = await get(loc);
      stats.telecharges += 1;
      const row = toRow(parseEventJsonLd(html), loc, lastmod);
      if (!row) {
        stats.ignores += 1;
        continue;
      }
      stats[upsert(row) === 'inserted' ? 'inseres' : 'mis_a_jour'] += 1;
    } catch (e) {
      stats.erreurs += 1;
      console.error(`[agenda] ${loc} : ${e.message}`);
    }
  }

  stats.duree_s = Math.round((Date.now() - started) / 1000);
  console.log('[agenda] synchronisation terminée', stats);
  return stats;
}

/**
 * Tarif VybzzZ propose a partir du prix en presentiel.
 *
 * Regle : un live coute nettement moins cher qu'un billet sur place — la
 * remise va de 50 a 70 %, 70 % par defaut.
 *
 * L'arrondi suit la grille tarifaire VybzzZ, en « ,90 » : on descend a l'euro
 * inferieur puis on retire dix centimes. 51,75 € a -70 % donne 15,52 -> 14,90.
 * Plancher a 0,90 € pour ne jamais tomber a zero ou en negatif.
 *
 * Renvoie null si la source n'annonce aucun prix : on ne devine pas un tarif.
 *
 * @param {string|number|null} prixPresentiel
 * @param {number} remisePct  entre 50 et 70
 * @returns {string|null}     ex. "14.90"
 */
function tarifVybzzz(prixPresentiel, remisePct = 70) {
  const base = parseFloat(prixPresentiel);
  if (!Number.isFinite(base) || base <= 0) return null;
  const remise = Math.min(Math.max(Number(remisePct) || 70, 50), 70);
  const brut = base * (1 - remise / 100);
  const prix = Math.max(Math.floor(brut) - 0.1, 0.9);
  return prix.toFixed(2);
}

/** Aligne un prix saisi a la main sur la meme grille en « ,90 ». */
function arrondirGrille(valeur) {
  const n = parseFloat(String(valeur).replace(',', '.'));
  if (!Number.isFinite(n) || n <= 0) return null;
  // 15 -> 14,90 ; 14,90 reste 14,90 ; 14,5 -> 13,90
  const dejaAlignee = Math.abs(n * 100 - Math.round(n * 100)) < 1e-6 && Math.round(n * 100) % 100 === 90;
  if (dejaAlignee) return n.toFixed(2);
  return Math.max(Math.floor(n) - 0.1, 0.9).toFixed(2);
}

module.exports = {
  SOURCE,
  tarifVybzzz,
  arrondirGrille,
  TERRITORIES,
  sync,
  // exportés pour les tests
  parseEventJsonLd,
  toRow,
  territoryOf,
  allowed,
};

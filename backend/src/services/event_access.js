'use strict';

/**
 * Attribution d'une place de concert à partir d'un e-mail.
 *
 * Deux sources passent par ici : le gain à la roue (place offerte) et l'achat
 * sur le site (Stripe). Dans les deux cas on ne connaît que l'e-mail, pas le
 * compte : si un compte existe avec cet e-mail, le billet est créé tout de
 * suite ; sinon la place est mise de côté (pending_tickets) et devient un vrai
 * billet dès que la personne crée son compte avec ce même e-mail.
 *
 * Les billets payés suivent exactement la répartition des achats dans l'app
 * (part artiste, part plateforme, apporteur), à ceci près que les frais ne
 * sont pas ceux d'un store mais ceux de Stripe.
 */

const { db } = require('../db');
const dbPayments = require('../db_payments');
const { genReceipt } = require('../helpers');
const apporteurLedger = require('./apporteur_ledger');

// Frais Stripe pour une carte européenne standard : 1,5 % + 0,25 €. Exprimés
// en taux effectif sur le montant, car c'est ce qu'attend le calcul de
// commission (conçu pour le taux fixe des stores).
function stripeFeeRate(gross) {
  const g = parseFloat(gross) || 0;
  if (g <= 0) return 0;
  return Math.min(1, (g * 0.015 + 0.25) / g);
}

function normEmail(e) {
  return String(e || '').trim().toLowerCase();
}

// Adresse « canonique » : pour Gmail / Googlemail, les points du nom local et
// tout ce qui suit un « + » sont ignorés par Google (j.o.h.n+roue@gmail.com =
// john@gmail.com = john@googlemail.com). Sans ça, une seule boîte peut tirer
// à la roue autant de fois qu'elle le veut. Sert de CLÉ (tirages, places en
// attente, rapprochement avec un compte), jamais d'adresse d'envoi.
const GOOGLE_DOMAINS = new Set(['gmail.com', 'googlemail.com']);
function canonEmail(e) {
  const n = normEmail(e);
  const at = n.lastIndexOf('@');
  if (at < 1) return n;
  let local = n.slice(0, at);
  let domain = n.slice(at + 1);
  if (GOOGLE_DOMAINS.has(domain)) {
    local = local.split('+')[0].replace(/\./g, '');
    domain = 'gmail.com';
  }
  return `${local}@${domain}`;
}

// Clés de recherche : la forme canonique ET la forme simplement minuscule,
// pour retrouver les lignes enregistrées avant la normalisation Gmail.
function emailKeys(e) {
  const n = normEmail(e);
  const c = canonEmail(e);
  return n === c ? [n] : [c, n];
}
const inKeys = (keys) => keys.map(() => '?').join(',');

// Domaines d'e-mail jetables les plus courants : refusés à la roue (une
// boîte à usage unique par tirage = places vidées par un seul joueur).
const DISPOSABLE_DOMAINS = [
  'mailinator.com', 'yopmail.com', 'yopmail.fr', 'yopmail.net', 'guerrillamail.com', 'guerrillamail.net',
  'guerrillamail.org', 'guerrillamail.de', 'sharklasers.com', 'grr.la', '10minutemail.com', '10minutemail.net',
  'temp-mail.org', 'temp-mail.io', 'tempmail.com', 'tempmail.net', 'tempmail.dev', 'tempmailo.com',
  'throwawaymail.com', 'trashmail.com', 'getnada.com', 'dispostable.com', 'maildrop.cc', 'mohmal.com',
  'emailondeck.com', 'fakeinbox.com', 'mailnesia.com', 'jetable.org', 'jetable.fr.nf',
];
function isDisposableEmail(e) {
  const n = normEmail(e);
  const domain = n.slice(n.lastIndexOf('@') + 1);
  if (!domain) return false;
  return DISPOSABLE_DOMAINS.some((d) => domain === d || domain.endsWith(`.${d}`));
}

// ─── Prix des billets : grille fermée ───
// Chaque palier correspond à un produit store `ticket_<partie entière>`
// (4.99 -> ticket_4). Un prix hors grille = billet impossible à acheter dans
// l'app (produit inexistant) ou vendu à un prix différent de l'IAP.
const ALLOWED_TICKET_PRICES = [0, 2.99, 4.99, 6.99, 9.99, 14.99, 19.99, 29.99, 39.99, 49.99, 59.99, 79.99, 99.99];
const PRICE_LIST_LABEL = ALLOWED_TICKET_PRICES.filter((p) => p > 0).map((p) => p.toFixed(2)).join(', ');

/**
 * Normalise un prix saisi ("4.99", "4,99 €", 4.99, "", "0", "Gratuit"…).
 * @returns {{ok:true, value:string}|{ok:false, error:string}} value = '0' ou '4.99'
 */
function normalizeTicketPrice(raw) {
  if (raw == null) return { ok: true, value: '0' };
  let s = String(raw).trim().toLowerCase();
  if (s === '' || s === 'gratuit' || s === 'free' || s === 'common_free') return { ok: true, value: '0' };
  s = s.replace(/€|eur|\s/g, '').replace(',', '.');
  const n = Number(s);
  if (!Number.isFinite(n) || n < 0) {
    return { ok: false, error: `Prix du billet invalide. Paliers acceptés : gratuit (0), ${PRICE_LIST_LABEL} €.` };
  }
  const hit = ALLOWED_TICKET_PRICES.find((p) => Math.abs(p - n) < 0.005);
  if (hit == null) {
    return { ok: false, error: `Prix ${n} € hors grille. Paliers acceptés : gratuit (0), ${PRICE_LIST_LABEL} €.` };
  }
  return { ok: true, value: hit === 0 ? '0' : hit.toFixed(2) };
}

/**
 * Date/heure fournie par un client -> ISO UTC avec « Z ». Sans fuseau
 * explicite, la valeur est lue comme UTC (c'est ce que l'app envoie, et ce
 * que SQLite stocke via datetime('now')).
 * @returns {{ok:true, value:string|null}|{ok:false, error:string}}
 */
function normalizeIsoUtc(raw, label = 'date') {
  if (raw == null || String(raw).trim() === '') return { ok: true, value: null };
  let s = String(raw).trim();
  if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2})?(\.\d+)?$/.test(s)) s = `${s.replace(' ', 'T')}Z`;
  const t = Date.parse(s);
  if (!Number.isFinite(t)) return { ok: false, error: `${label} invalide (attendu : 2026-10-04T03:50:00Z).` };
  return { ok: true, value: new Date(t).toISOString() };
}

// Journalisation : jamais l'adresse en clair (a***@domaine).
function maskEmail(e) {
  const n = normEmail(e);
  const at = n.indexOf('@');
  if (at < 1) return '***';
  return `${n[0]}***@${n.slice(at + 1)}`;
}

/**
 * Compte VybzzZ correspondant à cet e-mail (forme canonique pour Gmail). S'il
 * en existe plusieurs (ex. john.doe@ et johndoe@gmail.com), on prend d'abord
 * un compte vérifié, puis le plus ancien.
 */
function findUserByEmail(email) {
  const n = normEmail(email);
  if (!n) return null;
  const c = canonEmail(email);
  const exact = db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(n);
  if (exact && exact.is_verified) return exact;
  if (!GOOGLE_DOMAINS.has(c.slice(c.lastIndexOf('@') + 1))) return exact || null;
  const rows = db.prepare(
    "SELECT * FROM users WHERE lower(email) LIKE '%@gmail.com' OR lower(email) LIKE '%@googlemail.com'"
  ).all().filter((u) => canonEmail(u.email) === c);
  rows.sort((a, b) => (b.is_verified ? 1 : 0) - (a.is_verified ? 1 : 0) || a.id - b.id);
  return rows[0] || exact || null;
}

/** Même chose, mais uniquement un compte dont l'e-mail est VÉRIFIÉ (OTP / social). */
function findVerifiedUserByEmail(email) {
  const u = findUserByEmail(email);
  return u && u.is_verified ? u : null;
}

function hasAccess(email, eventId) {
  dbPayments.run();
  const keys = emailKeys(email);
  const user = findUserByEmail(email);
  if (user && db.prepare("SELECT 1 FROM tickets WHERE event_id = ? AND user_id = ? AND COALESCE(status, 'active') <> 'refunded'").get(eventId, user.id)) return true;
  // Place encore en attente (non remboursée), ou déjà devenue un billet actif.
  return !!db.prepare(
    `SELECT 1 FROM pending_tickets p LEFT JOIN tickets t ON t.id = p.ticket_id
      WHERE p.email IN (${inKeys(keys)}) AND p.event_id = ? AND p.refunded_at IS NULL
        AND (p.ticket_id IS NULL OR COALESCE(t.status, 'active') <> 'refunded')`
  ).get(...keys, eventId);
}

/** Une place attend-elle encore un compte vérifié pour cet e-mail ? (lot 2C : /sign-up -> requires_verification) */
function hasPendingForEmail(email) {
  dbPayments.run();
  const keys = emailKeys(email);
  if (!keys[0]) return false;
  return !!db.prepare(
    `SELECT 1 FROM pending_tickets WHERE email IN (${inKeys(keys)}) AND granted_at IS NULL AND ticket_id IS NULL AND refunded_at IS NULL`
  ).get(...keys);
}

/**
 * Remboursement d'un billet (Stripe ou store) : le billet passe 'refunded',
 * la part artiste est reprise sur son wallet (jamais sous 0 : si elle a déjà
 * été retirée, on le journalise pour traitement manuel), et le ledger reçoit
 * une ligne NÉGATIVE miroir de la vente (mêmes source/source_id) — les
 * relevés et le dashboard se compensent d'eux-mêmes. Idempotent.
 * @returns {{status:'refunded'|'already'|'not_found', ticket?:object}}
 */
function refundTicket(ticketId, { reason = 'refund' } = {}) {
  dbPayments.run();
  return db.transaction(() => {
    const t = db.prepare('SELECT * FROM tickets WHERE id = ?').get(Number(ticketId));
    if (!t) return { status: 'not_found' };
    if (t.status === 'refunded') return { status: 'already', ticket: t };
    db.prepare("UPDATE tickets SET status = 'refunded', refunded_at = datetime('now'), updated_at = datetime('now') WHERE id = ?").run(t.id);
    db.prepare("UPDATE pending_tickets SET refunded_at = datetime('now') WHERE ticket_id = ?").run(t.id);

    const sale = db.prepare(
      `SELECT * FROM platform_earnings WHERE source IN ('ticket', 'ticket_web') AND source_id = ?
        ORDER BY id ASC LIMIT 1`
    ).get(t.id);
    if (sale) {
      const alreadyReversed = db.prepare(
        `SELECT 1 FROM platform_earnings WHERE source = ? AND source_id = ? AND CAST(gross AS REAL) < 0`
      ).get(sale.source, t.id);
      if (!alreadyReversed) {
        const neg = (v) => (v == null ? null : (-(parseFloat(v) || 0)).toFixed(2));
        db.prepare(
          `INSERT INTO platform_earnings
             (artist_id, source, source_id, gross, artist_share, platform_share, commission_rate, store_fee, net, apporteur_id, apporteur_amount)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).run(
          sale.artist_id, sale.source, t.id, neg(sale.gross), neg(sale.artist_share), neg(sale.platform_share),
          sale.commission_rate, neg(sale.store_fee), neg(sale.net), sale.apporteur_id, neg(sale.apporteur_amount),
        );
        const share = parseFloat(sale.artist_share) || 0;
        if (share > 0 && sale.artist_id) {
          const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(sale.artist_id);
          const wallet = parseFloat(artist?.wallet) || 0;
          const next = Math.max(0, wallet - share);
          db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(next.toFixed(2), sale.artist_id);
          if (wallet - share < -0.005) {
            console.warn(`[remboursement] wallet artiste #${sale.artist_id} insuffisant : ${share.toFixed(2)} € à reprendre, ${wallet.toFixed(2)} € disponibles (billet #${t.id}) -> à régulariser à la main`);
          }
        }
        // Commission apporteur liée à cette vente : ligne miroir négative.
        const comm = db.prepare(
          "SELECT * FROM apporteur_commissions WHERE source_type = 'ticket' AND source_id = ? AND CAST(amount AS REAL) > 0 LIMIT 1"
        ).get(t.id);
        if (comm) {
          apporteurLedger.recordApporteurCommission({
            apporteurId: comm.apporteur_id, artistId: comm.artist_id, sourceType: 'ticket', sourceId: t.id,
            breakdown: {
              gross: neg(comm.gross), store: neg(comm.store), net: neg(comm.net),
              artist: neg(comm.artist_share), platform: neg(comm.platform_share), apporteur: neg(comm.amount),
            },
            rate: comm.rate,
          });
        }
      }
    }
    console.log(`[remboursement] billet #${t.id} (user #${t.user_id}, concert #${t.event_id}) remboursé : ${reason}`);
    return { status: 'refunded', ticket: t };
  })();
}

/** Crée le billet d'un compte existant (à appeler dans une transaction). */
function insertTicket(userId, eventId, { pricePaid = 0, storeFeeRate = 0, source, ref }) {
  dbPayments.run();
  // Un billet remboursé ne compte plus : la même personne peut en reprendre un.
  const already = db.prepare(
    "SELECT id FROM tickets WHERE event_id = ? AND user_id = ? AND COALESCE(status, 'active') <> 'refunded'"
  ).get(eventId, userId);
  if (already) return { ticketId: already.id, already: true };

  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
  if (!event) throw new Error(`concert #${eventId} introuvable`);

  const gross = parseFloat(pricePaid) || 0;
  let rate = null;
  let artistShare = '0';
  let breakdown = null;
  let ctx = null;
  let apporteurRatePct = 0;
  if (gross > 0) {
    const r = apporteurLedger.computeForSale(event.artist_id, gross, { storeFee: storeFeeRate });
    ({ ctx, apporteurRatePct, breakdown } = r);
    rate = r.artistRatePct;
    artistShare = breakdown.artist.toFixed(2);
  }

  const info = db.prepare(
    `INSERT INTO tickets (event_id, user_id, price_paid, receipt_number, status, commission_rate, artist_share, rc_transaction_id)
     VALUES (?, ?, ?, ?, 'active', ?, ?, ?)`
  ).run(eventId, userId, gross.toFixed(2), genReceipt(), rate, artistShare, `${source}:${ref}`);
  db.prepare(
    `INSERT INTO activities (user_id, event_id, type, description) VALUES (?, ?, 'ticket', ?)`
  ).run(userId, eventId, source === 'wheel' ? 'won a ticket' : 'bought a ticket on the website');

  if (breakdown && event.artist_id) {
    const artist = db.prepare('SELECT wallet FROM users WHERE id = ?').get(event.artist_id);
    const wallet = ((parseFloat(artist?.wallet) || 0) + breakdown.artist).toFixed(2);
    db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run(wallet, event.artist_id);
    db.prepare(
      `INSERT INTO platform_earnings
         (artist_id, source, source_id, gross, artist_share, platform_share, commission_rate, store_fee, net, apporteur_id, apporteur_amount)
       VALUES (?, 'ticket_web', ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      event.artist_id, info.lastInsertRowid, breakdown.gross.toFixed(2),
      breakdown.artist.toFixed(2), breakdown.platform.toFixed(2), rate,
      breakdown.store.toFixed(2), breakdown.net.toFixed(2),
      ctx.eligible ? ctx.apporteurId : null,
      ctx.eligible ? breakdown.apporteur.toFixed(2) : null,
    );
    if (ctx.eligible && apporteurRatePct > 0) {
      apporteurLedger.recordApporteurCommission({
        apporteurId: ctx.apporteurId, artistId: event.artist_id,
        sourceType: 'ticket', sourceId: info.lastInsertRowid,
        breakdown, rate: apporteurRatePct,
      });
    }
  }
  return { ticketId: info.lastInsertRowid, already: false };
}

/**
 * Donne une place à cet e-mail. Idempotent sur (source, ref) : un webhook
 * rejoué ou un double clic ne crée jamais deux places.
 * @returns {{status: 'granted'|'pending'|'already', ticketId?: number}}
 */
function grantByEmail({ email, eventId, pricePaid = 0, storeFeeRate = 0, source, ref }) {
  dbPayments.run();
  const e = canonEmail(email);
  return db.transaction(() => {
    const seen = db.prepare('SELECT * FROM pending_tickets WHERE source = ? AND ref = ?').get(source, String(ref));
    if (seen) return { status: seen.ticket_id ? 'granted' : 'pending', ticketId: seen.ticket_id || undefined, replay: true };

    // Billet immédiat UNIQUEMENT pour un compte dont l'e-mail est vérifié :
    // sinon n'importe qui pourrait créer un compte avec l'adresse d'un gagnant
    // (ou d'un acheteur) et récupérer sa place. Le compte non vérifié garde la
    // place en attente ; elle le rejoint à la vérification (ou via l'admin).
    const user = findVerifiedUserByEmail(e);
    let ticketId = null;
    let status = 'pending';
    if (user) {
      const r = insertTicket(user.id, eventId, { pricePaid, storeFeeRate, source, ref });
      ticketId = r.ticketId;
      status = r.already ? 'already' : 'granted';
    }
    // On garde toujours une trace (même si le billet est déjà créé) : c'est
    // elle qui rend l'opération idempotente et lisible dans l'admin.
    db.prepare(
      `INSERT INTO pending_tickets (email, event_id, price_paid, store_fee_rate, source, ref, ticket_id, granted_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, CASE WHEN ? IS NULL THEN NULL ELSE datetime('now') END)`
    ).run(e, eventId, String(pricePaid), storeFeeRate, source, String(ref), ticketId, ticketId);
    return { status, ticketId: ticketId || undefined };
  })();
}

/** Transforme UNE place en attente en billet pour ce compte (dans une transaction). */
function grantPendingTo(pending, userId) {
  return db.transaction(() => {
    const r = insertTicket(userId, pending.event_id, {
      pricePaid: pending.price_paid, storeFeeRate: pending.store_fee_rate || 0, source: pending.source, ref: pending.ref,
    });
    db.prepare("UPDATE pending_tickets SET ticket_id = ?, granted_at = datetime('now') WHERE id = ?").run(r.ticketId, pending.id);
    return r;
  })();
}

/**
 * À la vérification d'un compte (OTP, lien e-mail, connexion sociale) : ses
 * places en attente deviennent des billets. Un compte NON vérifié ne reçoit
 * rien (voir grantByEmail) : appeler de nouveau après vérification.
 */
function attachPendingForUser(user) {
  if (!user || !user.email) return 0;
  if (!user.is_verified) return 0;
  dbPayments.run();
  const keys = emailKeys(user.email);
  const rows = db.prepare(
    `SELECT * FROM pending_tickets WHERE email IN (${inKeys(keys)}) AND ticket_id IS NULL AND refunded_at IS NULL`
  ).all(...keys);
  let n = 0;
  for (const p of rows) {
    try {
      grantPendingTo(p, user.id);
      n += 1;
    } catch (e) {
      console.error(`[places] rattachement impossible (#${p.id}) :`, e.message);
    }
  }
  if (n) console.log(`[places] ${n} place(s) rattachée(s) au compte #${user.id}`);
  return n;
}

/**
 * Admin : attribue une place en attente à un compte choisi à la main (la
 * personne n'arrive pas à vérifier son e-mail, ou s'est inscrite avec une
 * autre adresse). Idempotent : une place déjà attribuée n'est pas rejouée.
 */
function assignPendingToUser(pendingId, userId) {
  dbPayments.run();
  const p = db.prepare('SELECT * FROM pending_tickets WHERE id = ?').get(Number(pendingId));
  if (!p) return { error: 'Place introuvable.', code: 404 };
  if (p.ticket_id) return { error: `Place déjà attribuée (billet #${p.ticket_id}).`, code: 409, ticketId: p.ticket_id };
  if (p.refunded_at) return { error: 'Place remboursée : elle ne peut plus être attribuée.', code: 409 };
  const u = db.prepare('SELECT id, email, is_verified FROM users WHERE id = ?').get(Number(userId));
  if (!u) return { error: 'Utilisateur introuvable.', code: 404 };
  const r = grantPendingTo(p, u.id);
  console.log(`[places] place #${p.id} (${maskEmail(p.email)}) attribuée à la main au compte #${u.id}${r.already ? ' (billet déjà existant)' : ''}`);
  return { ticketId: r.ticketId, already: r.already, userId: u.id };
}

/** Admin : liste des places (en attente d'abord), avec le compte correspondant s'il existe. */
function listPending({ limit = 500 } = {}) {
  dbPayments.run();
  const rows = db.prepare(
    `SELECT p.*, e.name AS event_name
       FROM pending_tickets p LEFT JOIN events e ON e.id = p.event_id
      ORDER BY (p.ticket_id IS NULL) DESC, p.id DESC LIMIT ?`
  ).all(limit);
  return rows.map((p) => {
    const u = findUserByEmail(p.email);
    return {
      id: p.id,
      email: p.email,
      event_id: p.event_id,
      event_name: p.event_name || null,
      source: p.source,
      ref: p.ref,
      price_paid: p.price_paid,
      created_at: p.created_at,
      granted_at: p.granted_at,
      refunded_at: p.refunded_at || null,
      ticket_id: p.ticket_id,
      status: p.refunded_at ? 'refunded' : p.ticket_id ? 'granted' : 'pending',
      account: u ? { id: u.id, is_verified: !!u.is_verified } : null,
    };
  });
}

// ─── Migration de données (une fois) : canonise les e-mails Gmail déjà
// enregistrés (tirages, places en attente) avant l'arrivée de canonEmail,
// pour que « a.b.c@gmail.com » (ancienne ligne) bloque bien « abc@gmail.com ».
// En cas de doublon (les deux formes existent), la ligne la plus ancienne
// est conservée telle quelle et le cas est journalisé.
const CANON_MIGRATION_KEY = 'migration:canon_emails_v1';
function migrateCanonEmails() {
  try {
    if (!db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'wheel_spins'").get()) return;
    if (db.prepare('SELECT 1 FROM settings WHERE key = ?').get(CANON_MIGRATION_KEY)) return;
    let n = 0;
    db.transaction(() => {
      for (const [table, scope] of [['wheel_spins', 'campaign'], ['pending_tickets', 'event_id']]) {
        const rows = db.prepare(
          `SELECT id, email, ${scope} AS scope FROM ${table} WHERE lower(email) LIKE '%@gmail.com' OR lower(email) LIKE '%@googlemail.com' OR email <> lower(email)`
        ).all();
        for (const r of rows) {
          const c = canonEmail(r.email);
          if (c === r.email) continue;
          const clash = db.prepare(`SELECT id FROM ${table} WHERE email = ? AND ${scope} = ? AND id <> ?`).get(c, r.scope, r.id);
          if (clash) { console.warn(`[places] ${table} #${r.id} (${maskEmail(r.email)}) : forme canonique déjà présente (#${clash.id}), ligne conservée`); continue; }
          db.prepare(`UPDATE ${table} SET email = ? WHERE id = ?`).run(c, r.id);
          n += 1;
        }
      }
      db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(CANON_MIGRATION_KEY, new Date().toISOString());
    })();
    if (n) console.log(`[places] ${n} e-mail(s) canonisé(s) (Gmail)`);
  } catch (e) {
    console.error('[places] migration e-mails canoniques :', e.message);
  }
}
// Base neuve : les tables n'existent qu'après db.init() (appelé par app.js
// dans le même tour synchrone) -> au tick suivant.
process.nextTick(migrateCanonEmails);

module.exports = {
  ALLOWED_TICKET_PRICES, normalizeTicketPrice, normalizeIsoUtc,
  normEmail, canonEmail, emailKeys, isDisposableEmail, maskEmail,
  findUserByEmail, findVerifiedUserByEmail, hasAccess, hasPendingForEmail,
  grantByEmail, attachPendingForUser, assignPendingToUser, listPending, refundTicket, stripeFeeRate,
};

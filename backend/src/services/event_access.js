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

function findUserByEmail(email) {
  return db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(normEmail(email));
}

function hasAccess(email, eventId) {
  const e = normEmail(email);
  const user = findUserByEmail(e);
  if (user && db.prepare('SELECT 1 FROM tickets WHERE event_id = ? AND user_id = ?').get(eventId, user.id)) return true;
  return !!db.prepare('SELECT 1 FROM pending_tickets WHERE email = ? AND event_id = ?').get(e, eventId);
}

/** Crée le billet d'un compte existant (à appeler dans une transaction). */
function insertTicket(userId, eventId, { pricePaid = 0, storeFeeRate = 0, source, ref }) {
  const already = db.prepare('SELECT id FROM tickets WHERE event_id = ? AND user_id = ?').get(eventId, userId);
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
  const e = normEmail(email);
  return db.transaction(() => {
    const seen = db.prepare('SELECT * FROM pending_tickets WHERE source = ? AND ref = ?').get(source, String(ref));
    if (seen) return { status: seen.ticket_id ? 'granted' : 'pending', ticketId: seen.ticket_id || undefined, replay: true };

    const user = findUserByEmail(e);
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

/** À l'inscription / la vérification d'un compte : ses places en attente deviennent des billets. */
function attachPendingForUser(user) {
  if (!user || !user.email) return 0;
  const rows = db.prepare(
    'SELECT * FROM pending_tickets WHERE email = ? AND ticket_id IS NULL'
  ).all(normEmail(user.email));
  let n = 0;
  for (const p of rows) {
    try {
      db.transaction(() => {
        const r = insertTicket(user.id, p.event_id, {
          pricePaid: p.price_paid, storeFeeRate: p.store_fee_rate || 0, source: p.source, ref: p.ref,
        });
        db.prepare("UPDATE pending_tickets SET ticket_id = ?, granted_at = datetime('now') WHERE id = ?").run(r.ticketId, p.id);
      })();
      n += 1;
    } catch (e) {
      console.error(`[places] rattachement impossible (#${p.id}) :`, e.message);
    }
  }
  if (n) console.log(`[places] ${n} place(s) rattachée(s) au compte #${user.id}`);
  return n;
}

module.exports = { normEmail, findUserByEmail, hasAccess, grantByEmail, attachPendingForUser, stripeFeeRate };

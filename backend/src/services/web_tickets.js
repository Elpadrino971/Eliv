'use strict';

/**
 * Billetterie du site (Stripe).
 *
 * Pourquoi elle existe : dans l'app, un billet s'achète via le store
 * (`ticket_<prix>`). Aucun de ces produits n'est déclaré côté Google Play, si
 * bien qu'un fan Android ne peut pas acheter sa place dans l'app. Sur le site,
 * tout le monde paie par carte — Android, iPhone, ordinateur — et la place
 * rejoint le compte VybzzZ lié à l'e-mail du paiement.
 */

const { db } = require('../db');
const dbPayments = require('../db_payments');
const stripeService = require('./stripe');
const access = require('./event_access');
const email = require('./email');
const pricing = require('./pricing');
const webWatch = require('./web_watch');

const SITE_URL = (process.env.SITE_URL || 'https://vybzzz.online').replace(/\/+$/, '');

/**
 * @param {object} o
 * @param {'page'|'live'} [o.returnTo] 'live' : retour sur live.html, qui
 *   échange la session contre l'accès et lance le concert aussitôt. Sinon
 *   retour sur la page de campagne (`page`), qui fait de même dans #billet.
 */
async function createCheckout({ eventId, rawEmail, campaign, page, returnTo }) {
  if (!stripeService.isConfigured()) return { error: 'Paiement par carte indisponible pour le moment.', code: 503 };
  const event = db.prepare('SELECT id, name, ticket_price, price_schedule, start_date_time FROM events WHERE id = ?').get(eventId);
  if (!event) return { error: 'Concert introuvable.', code: 404 };

  const e = access.normEmail(rawEmail);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e) || e.length > 190) return { error: 'Adresse e-mail invalide.', code: 422 };
  if (access.hasAccess(e, event.id)) {
    return { error: 'Cette adresse a déjà sa place pour ce concert.', code: 409 };
  }
  // Prix EFFECTIF (tarification dynamique, lot 9) : même montant que l'app.
  const amountCents = Math.round((parseFloat(pricing.effectivePrice(event).price) || 0) * 100);
  if (amountCents < 50) return { error: 'Ce concert est gratuit : rejoins-le directement dans l’app.', code: 422 };

  // {CHECKOUT_SESSION_ID} : remplacé par Stripe. La page de retour l'échange
  // contre une clé d'accès (POST /api/watch/claim) : le fan regarde tout de
  // suite, sans attendre le webhook ni installer l'app.
  const live = `${SITE_URL}/live.html?e=${event.id}`;
  const back = `${SITE_URL}/${page || 'index.html'}`;
  const session = await stripeService.createTicketCheckout({
    eventId: event.id,
    eventName: event.name,
    amountCents,
    email: e,
    campaign,
    successUrl: returnTo === 'live'
      ? `${live}&session_id={CHECKOUT_SESSION_ID}`
      : `${back}?paiement=ok&session_id={CHECKOUT_SESSION_ID}#billet`,
    cancelUrl: returnTo === 'live' ? `${live}&paiement=annule` : `${back}?paiement=annule#billet`,
  });
  db.prepare(
    `INSERT INTO web_ticket_orders (event_id, email, amount, stripe_session_id, status, campaign) VALUES (?, ?, ?, ?, 'pending', ?)`
  ).run(event.id, e, (amountCents / 100).toFixed(2), session.id, campaign || null);
  return { url: session.url };
}

/**
 * Webhook Stripe : paiement d'un billet confirmé (checkout.session.completed
 * ou checkout.session.async_payment_succeeded). Idempotent (webhook rejoué).
 * Mémorise le payment_intent sur la commande : c'est la seule clé que porte
 * ensuite un remboursement (charge.refunded) ou un litige.
 */
async function handlePaid(session) {
  if (session.payment_status !== 'paid') return;
  dbPayments.run();
  const order = db.prepare('SELECT * FROM web_ticket_orders WHERE stripe_session_id = ?').get(session.id);
  const eventId = Number(session.metadata?.event_id || order?.event_id);
  const e = access.normEmail(session.metadata?.email || order?.email || session.customer_details?.email);
  if (!eventId || !e) {
    console.warn('[billetterie] paiement sans concert ou e-mail exploitable', session.id);
    return;
  }
  const amount = ((session.amount_total || 0) / 100).toFixed(2);
  const paymentIntentId = typeof session.payment_intent === 'string'
    ? session.payment_intent
    : (session.payment_intent && session.payment_intent.id) || null;
  const r = access.grantByEmail({
    email: e, eventId, pricePaid: amount, storeFeeRate: access.stripeFeeRate(amount), source: 'stripe', ref: session.id,
  });
  if (order) {
    db.prepare(
      `UPDATE web_ticket_orders SET status = CASE WHEN status = 'refunded' THEN status ELSE 'paid' END,
          paid_at = COALESCE(paid_at, datetime('now')), payment_intent_id = COALESCE(payment_intent_id, ?)
        WHERE id = ?`
    ).run(paymentIntentId, order.id);
  } else {
    db.prepare(
      `INSERT OR IGNORE INTO web_ticket_orders (event_id, email, amount, stripe_session_id, status, paid_at, payment_intent_id)
       VALUES (?, ?, ?, ?, 'paid', datetime('now'), ?)`
    ).run(eventId, e, amount, session.id, paymentIntentId);
  }
  if (r.status === 'already') console.warn(`[billetterie] ${access.maskEmail(e)} avait déjà une place pour #${eventId} (session ${session.id})`);
  if (!r.replay) {
    const ev = db.prepare('SELECT name FROM events WHERE id = ?').get(eventId);
    try {
      // Lien « Regarder le live » avec sa propre clé : le fan retrouve le
      // concert depuis n'importe quel appareil, sans compte.
      const url = webWatch.watchUrl(eventId, webWatch.issue(e, eventId, 'stripe_email'));
      await email.sendEmail({ to: e, subject: 'Ta place pour le live est réservée', html: webWatch.watchEmailHtml(ev?.name, url, { paid: true }), kind: 'ticket_web' });
    } catch (err) {
      console.error('[billetterie] e-mail de confirmation non envoyé :', err.message);
    }
  }
  console.log(`[billetterie] place ${r.status} pour ${access.maskEmail(e)} (concert #${eventId}, ${amount} €)`);
}

/**
 * Webhook Stripe : remboursement (charge.refunded) ou litige
 * (charge.dispute.created) sur un billet. Retrouve la commande par
 * payment_intent (mémorisé au paiement ; sinon via l'API Stripe pour les
 * commandes antérieures), puis :
 *  - billet -> status 'refunded' (part artiste reprise, ledger négatif),
 *  - place encore en attente -> marquée remboursée (jamais rattachée),
 *  - commande -> status 'refunded'.
 * Un remboursement PARTIEL ne retire pas l'accès : journalisé pour décision
 * manuelle. Idempotent.
 * @param {object} obj charge (charge.refunded) ou dispute (charge.dispute.created)
 * @param {string} kind 'refund' | 'dispute'
 */
async function handleRefund(obj, kind = 'refund') {
  dbPayments.run();
  const paymentIntentId = typeof obj.payment_intent === 'string' ? obj.payment_intent : obj.payment_intent?.id || null;
  if (!paymentIntentId) {
    console.warn(`[billetterie] ${kind} sans payment_intent (${obj.id}) : ignoré`);
    return { status: 'ignored' };
  }
  if (kind === 'refund' && obj.amount && obj.amount_refunded != null && obj.amount_refunded < obj.amount) {
    console.warn(`[billetterie] remboursement PARTIEL (${obj.amount_refunded}/${obj.amount} c) sur ${paymentIntentId} : accès conservé, à traiter à la main`);
    return { status: 'partial' };
  }

  let order = db.prepare('SELECT * FROM web_ticket_orders WHERE payment_intent_id = ?').get(paymentIntentId);
  if (!order) {
    // Commande payée avant la mémorisation du payment_intent : on remonte à
    // la session Checkout via l'API Stripe.
    let session = null;
    try { session = await stripeService.findSessionByPaymentIntent(paymentIntentId); } catch (e) {
      console.error('[billetterie] session introuvable via Stripe :', e.message);
    }
    if (session) {
      order = db.prepare('SELECT * FROM web_ticket_orders WHERE stripe_session_id = ?').get(session.id);
      if (order) db.prepare('UPDATE web_ticket_orders SET payment_intent_id = ? WHERE id = ?').run(paymentIntentId, order.id);
    }
  }
  if (!order) {
    // Pas une vente de billet du site (abonnement, autre) ou commande inconnue.
    const isTicket = obj.metadata?.kind === 'ticket';
    if (isTicket) console.warn(`[billetterie] ${kind} ${paymentIntentId} : commande introuvable -> vérifier à la main`);
    return { status: 'not_found' };
  }

  const pending = db.prepare("SELECT * FROM pending_tickets WHERE source = 'stripe' AND ref = ?").get(order.stripe_session_id);
  let result = { status: 'no_ticket' };
  db.transaction(() => {
    if (pending && pending.ticket_id) {
      result = access.refundTicket(pending.ticket_id, { reason: kind === 'dispute' ? 'litige Stripe' : 'remboursement Stripe' });
    } else if (pending) {
      db.prepare("UPDATE pending_tickets SET refunded_at = COALESCE(refunded_at, datetime('now')) WHERE id = ?").run(pending.id);
      result = { status: 'pending_refunded' };
    }
    db.prepare("UPDATE web_ticket_orders SET status = 'refunded', refunded_at = COALESCE(refunded_at, datetime('now')) WHERE id = ?").run(order.id);
  })();
  console.log(`[billetterie] ${kind} ${paymentIntentId} -> commande #${order.id} (${access.maskEmail(order.email)}, concert #${order.event_id}) : ${result.status}`);
  return { ...result, orderId: order.id };
}

module.exports = { createCheckout, handlePaid, handleRefund };

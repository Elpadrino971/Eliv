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
const stripeService = require('./stripe');
const access = require('./event_access');
const email = require('./email');

const SITE_URL = (process.env.SITE_URL || 'https://vybzzz.online').replace(/\/+$/, '');

async function createCheckout({ eventId, rawEmail, campaign, page }) {
  if (!stripeService.isConfigured()) return { error: 'Paiement par carte indisponible pour le moment.', code: 503 };
  const event = db.prepare('SELECT id, name, ticket_price, start_date_time FROM events WHERE id = ?').get(eventId);
  if (!event) return { error: 'Concert introuvable.', code: 404 };

  const e = access.normEmail(rawEmail);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e) || e.length > 190) return { error: 'Adresse e-mail invalide.', code: 422 };
  if (access.hasAccess(e, event.id)) {
    return { error: 'Cette adresse a déjà sa place pour ce concert.', code: 409 };
  }
  const amountCents = Math.round((parseFloat(event.ticket_price) || 0) * 100);
  if (amountCents < 50) return { error: 'Ce concert est gratuit : rejoins-le directement dans l’app.', code: 422 };

  const back = `${SITE_URL}/${page || 'index.html'}`;
  const session = await stripeService.createTicketCheckout({
    eventId: event.id,
    eventName: event.name,
    amountCents,
    email: e,
    campaign,
    successUrl: `${back}?paiement=ok#billet`,
    cancelUrl: `${back}?paiement=annule#billet`,
  });
  db.prepare(
    `INSERT INTO web_ticket_orders (event_id, email, amount, stripe_session_id, status, campaign) VALUES (?, ?, ?, ?, 'pending', ?)`
  ).run(event.id, e, (amountCents / 100).toFixed(2), session.id, campaign || null);
  return { url: session.url };
}

function confirmationHtml(eventName) {
  return `<!doctype html><html lang="fr"><body style="margin:0;background:#0A1226;font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#F4EFE3">
<div style="max-width:520px;margin:0 auto;padding:36px 26px;text-align:center">
  <div style="font-weight:800;letter-spacing:.12em;font-size:18px">Vybzz<span style="color:#E6C76A">Z</span></div>
  <h1 style="font-size:24px;margin:28px 0 10px">Ta place est réservée</h1>
  <p style="color:#B9C0D0;line-height:1.6;margin:0 0 24px">${eventName}, en direct sur VybzzZ.</p>
  <p style="color:#B9C0D0;line-height:1.6;margin:0 0 26px">Pour rejoindre le live, ouvre l'application VybzzZ et connecte-toi <b style="color:#F4EFE3">avec cette même adresse e-mail</b>. Pas encore de compte ? Crée-le avec cette adresse : ta place y sera automatiquement.</p>
  <a href="${SITE_URL}/app.html" style="display:inline-block;background:#E6C76A;color:#0A1226;text-decoration:none;font-weight:700;padding:15px 28px;border-radius:12px">Télécharger l'application</a>
</div></body></html>`;
}

/** Webhook Stripe : paiement d'un billet confirmé. Idempotent (webhook rejoué). */
async function handlePaid(session) {
  if (session.payment_status !== 'paid') return;
  const order = db.prepare('SELECT * FROM web_ticket_orders WHERE stripe_session_id = ?').get(session.id);
  const eventId = Number(session.metadata?.event_id || order?.event_id);
  const e = access.normEmail(session.metadata?.email || order?.email || session.customer_details?.email);
  if (!eventId || !e) {
    console.warn('[billetterie] paiement sans concert ou e-mail exploitable', session.id);
    return;
  }
  const amount = ((session.amount_total || 0) / 100).toFixed(2);
  const r = access.grantByEmail({
    email: e, eventId, pricePaid: amount, storeFeeRate: access.stripeFeeRate(amount), source: 'stripe', ref: session.id,
  });
  if (order) {
    db.prepare("UPDATE web_ticket_orders SET status = 'paid', paid_at = COALESCE(paid_at, datetime('now')) WHERE id = ?").run(order.id);
  } else {
    db.prepare(
      `INSERT OR IGNORE INTO web_ticket_orders (event_id, email, amount, stripe_session_id, status, paid_at) VALUES (?, ?, ?, ?, 'paid', datetime('now'))`
    ).run(eventId, e, amount, session.id);
  }
  if (r.status === 'already') console.warn(`[billetterie] ${e} avait déjà une place pour #${eventId} (session ${session.id})`);
  if (!r.replay) {
    const ev = db.prepare('SELECT name FROM events WHERE id = ?').get(eventId);
    try {
      await email.sendEmail({ to: e, subject: 'Ta place pour le live est réservée', html: confirmationHtml(ev?.name || 'Ton concert'), kind: 'ticket_web' });
    } catch (err) {
      console.error('[billetterie] e-mail de confirmation non envoyé :', err.message);
    }
  }
  console.log(`[billetterie] place ${r.status} pour ${e} (concert #${eventId}, ${amount} €)`);
}

module.exports = { createCheckout, handlePaid };

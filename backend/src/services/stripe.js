'use strict';

/**
 * Client Stripe (SDK officiel). Auth via STRIPE_SECRET_KEY (jamais exposée
 * à l'app). Flux : Checkout Session (abonnement) + webhook pour activer
 * l'accès une fois le paiement confirmé (voir routes/stripe.routes.js).
 */

const Stripe = require('stripe');

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
let stripe = null;

function isConfigured() {
  return Boolean(STRIPE_SECRET_KEY);
}

function client() {
  if (!stripe) {
    if (!isConfigured()) {
      const err = new Error('Stripe non configuré (STRIPE_SECRET_KEY manquant).');
      err.code = 'STRIPE_NOT_CONFIGURED';
      throw err;
    }
    stripe = new Stripe(STRIPE_SECRET_KEY);
  }
  return stripe;
}

/**
 * Session Checkout pour un abonnement. client_reference_id + metadata
 * portent user_id/subscriptions_id : c'est ce que le webhook relit pour
 * savoir qui vient de payer quoi (voir stripe.routes.js).
 */
function createSubscriptionCheckout({ priceId, userId, subscriptionsId, customerEmail, successUrl, cancelUrl }) {
  return client().checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    client_reference_id: String(userId),
    customer_email: customerEmail || undefined,
    metadata: { user_id: String(userId), subscriptions_id: String(subscriptionsId) },
    subscription_data: { metadata: { user_id: String(userId), subscriptions_id: String(subscriptionsId) } },
    success_url: successUrl,
    cancel_url: cancelUrl,
  });
}

/**
 * Session Checkout pour UN billet de concert, payé sur le site. Le montant
 * vient du concert en base (jamais du navigateur). metadata.kind = 'ticket'
 * permet au webhook de distinguer ce paiement d'un abonnement.
 */
function createTicketCheckout({ eventId, eventName, amountCents, email, campaign, successUrl, cancelUrl }) {
  return client().checkout.sessions.create({
    mode: 'payment',
    // Carte uniquement : les moyens de paiement différés (virement, SEPA…)
    // confirment des heures/jours plus tard — trop tard pour un live.
    payment_method_types: ['card'],
    line_items: [{
      quantity: 1,
      price_data: {
        currency: 'eur',
        unit_amount: amountCents,
        product_data: { name: `Accès live · ${eventName}`, description: 'Place pour le concert en direct sur VybzzZ' },
      },
    }],
    customer_email: email,
    metadata: { kind: 'ticket', event_id: String(eventId), email, campaign: campaign || '' },
    payment_intent_data: { metadata: { kind: 'ticket', event_id: String(eventId), email } },
    locale: 'fr',
    success_url: successUrl,
    cancel_url: cancelUrl,
  });
}

function constructWebhookEvent(rawBody, signatureHeader, secret) {
  return client().webhooks.constructEvent(rawBody, signatureHeader, secret);
}

function retrieveSubscription(subscriptionId) {
  return client().subscriptions.retrieve(subscriptionId);
}

/**
 * Session Checkout à l'origine d'un PaymentIntent (repli pour un remboursement
 * dont la commande n'a pas encore de payment_intent_id mémorisé : commandes
 * payées avant le lot 2D). Renvoie null si introuvable.
 */
async function findSessionByPaymentIntent(paymentIntentId) {
  if (!paymentIntentId) return null;
  const r = await client().checkout.sessions.list({ payment_intent: paymentIntentId, limit: 1 });
  return r && r.data && r.data[0] ? r.data[0] : null;
}

module.exports = {
  isConfigured,
  createSubscriptionCheckout,
  createTicketCheckout,
  constructWebhookEvent,
  retrieveSubscription,
  findSessionByPaymentIntent,
};

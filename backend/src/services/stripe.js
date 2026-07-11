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

function constructWebhookEvent(rawBody, signatureHeader, secret) {
  return client().webhooks.constructEvent(rawBody, signatureHeader, secret);
}

function retrieveSubscription(subscriptionId) {
  return client().subscriptions.retrieve(subscriptionId);
}

module.exports = {
  isConfigured,
  createSubscriptionCheckout,
  constructWebhookEvent,
  retrieveSubscription,
};

'use strict';

/**
 * Webhook Stripe uniquement (POST /api/stripe/webhook). Mounté à part dans
 * app.js avec `express.raw` : la vérification de signature Stripe a besoin
 * du corps brut exact, pas du JSON déjà parsé (même logique que Mux).
 *
 * checkout.session.completed -> active l'abonnement (seule façon légitime
 * de le faire ; /api/subscription/buy ne fait plus rien tout seul).
 * customer.subscription.deleted / .updated -> suit le cycle de vie réel.
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const stripeService = require('../services/stripe');

if (!process.env.STRIPE_WEBHOOK_SECRET) {
  const msg =
    '[stripe webhook] STRIPE_WEBHOOK_SECRET absent : signature non vérifiée, ' +
    'n\'importe qui pourrait simuler un paiement et activer un abonnement gratuitement.';
  if (process.env.NODE_ENV === 'production') throw new Error(msg);
  console.error('⚠️⚠️ ' + msg + ' (toléré en dev uniquement)');
}

router.post('/', (req, res) => {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  const sig = req.headers['stripe-signature'];
  const raw = req.body; // Buffer (express.raw)

  let event;
  try {
    if (secret) {
      event = stripeService.constructWebhookEvent(raw, sig, secret);
    } else {
      event = JSON.parse(raw.toString('utf8'));
      console.warn('[stripe webhook] STRIPE_WEBHOOK_SECRET absent : signature non vérifiée (dev uniquement).');
    }
  } catch (e) {
    console.warn('[stripe webhook] signature/payload invalide :', e.message);
    return res.status(400).json({ status: 'error', message: 'Payload invalide.' });
  }

  console.log(`[stripe webhook] ${event.type}`);

  try {
    const obj = event.data.object;

    if (event.type === 'checkout.session.completed') {
      const userId = Number(obj.client_reference_id || obj.metadata?.user_id);
      const subscriptionsId = Number(obj.metadata?.subscriptions_id);
      if (userId && subscriptionsId) {
        db.prepare(
          `INSERT INTO user_subscriptions
             (user_id, subscriptions_id, status, stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id)
           VALUES (?, ?, 'active', ?, ?, ?)`
        ).run(userId, subscriptionsId, obj.customer || null, obj.subscription || null, obj.id);
      } else {
        console.warn('[stripe webhook] checkout.session.completed sans user_id/subscriptions_id exploitable', obj.id);
      }
    } else if (event.type === 'customer.subscription.deleted') {
      db.prepare(
        "UPDATE user_subscriptions SET status = 'cancelled' WHERE stripe_subscription_id = ?"
      ).run(obj.id);
    } else if (event.type === 'customer.subscription.updated') {
      const status = obj.status === 'active' || obj.status === 'trialing' ? 'active'
        : obj.status === 'past_due' ? 'past_due' : 'cancelled';
      db.prepare(
        'UPDATE user_subscriptions SET status = ? WHERE stripe_subscription_id = ?'
      ).run(status, obj.id);
    }
  } catch (e) {
    console.error('[stripe webhook] erreur traitement', e.message);
  }

  return res.json({ received: true });
});

module.exports = router;

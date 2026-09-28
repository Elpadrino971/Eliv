'use strict';

/**
 * Webhook Stripe uniquement (POST /api/stripe/webhook). Mounté à part dans
 * app.js avec `express.raw` : la vérification de signature Stripe a besoin
 * du corps brut exact, pas du JSON déjà parsé (même logique que Mux).
 *
 * checkout.session.completed / .async_payment_succeeded -> active
 * l'abonnement (seule façon légitime de le faire ; /api/subscription/buy ne
 * fait plus rien tout seul) ou attribue un billet du site (metadata.kind).
 * charge.refunded / charge.dispute.created -> retire le billet remboursé.
 * customer.subscription.deleted / .updated -> suit le cycle de vie réel.
 * Chaque event.id n'est traité qu'une fois (stripe_processed_events).
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const dbPayments = require('../db_payments');
const stripeService = require('../services/stripe');
const webTickets = require('../services/web_tickets');

if (!process.env.STRIPE_WEBHOOK_SECRET) {
  const msg =
    '[stripe webhook] STRIPE_WEBHOOK_SECRET absent : signature non vérifiée, ' +
    'n\'importe qui pourrait simuler un paiement et activer un abonnement gratuitement.';
  if (process.env.NODE_ENV === 'production') throw new Error(msg);
  console.error('⚠️⚠️ ' + msg + ' (toléré en dev uniquement)');
}

router.post('/', async (req, res) => {
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
  dbPayments.run();

  // Dédup : Stripe rejoue les évènements (timeout, 5xx, replay manuel). Un
  // event.id ne doit produire qu'un seul effet. On ne le marque « traité »
  // qu'après succès, pour qu'un rejeu répare un échec transitoire.
  const evId = String(event.id || '');
  if (evId && db.prepare('SELECT 1 FROM stripe_processed_events WHERE event_id = ?').get(evId)) {
    return res.json({ received: true, duplicate: true });
  }
  const markProcessed = () => {
    if (evId) db.prepare('INSERT OR IGNORE INTO stripe_processed_events (event_id, type) VALUES (?, ?)').run(evId, event.type);
  };

  try {
    const obj = event.data.object;
    const isCheckoutPaid = event.type === 'checkout.session.completed' || event.type === 'checkout.session.async_payment_succeeded';

    if (isCheckoutPaid && obj.metadata?.kind === 'ticket') {
      // Billet de concert acheté sur le site (voir services/web_tickets.js).
      // En cas d'échec on répond 500 : Stripe rejouera l'événement, et
      // l'attribution est idempotente, donc aucun risque de double place.
      try {
        await webTickets.handlePaid(obj);
      } catch (e) {
        console.error('[stripe webhook] billet non attribué, Stripe rejouera :', e.message);
        return res.status(500).json({ received: false });
      }
    } else if (isCheckoutPaid) {
      const userId = Number(obj.client_reference_id || obj.metadata?.user_id);
      const subscriptionsId = Number(obj.metadata?.subscriptions_id);
      if (userId && subscriptionsId) {
        // Idempotence : un rejeu (ou completed + async_payment_succeeded sur
        // la même session) ne doit pas créer un 2e abonnement.
        const existing = db.prepare('SELECT id FROM user_subscriptions WHERE stripe_checkout_session_id = ?').get(obj.id);
        if (existing) {
          db.prepare("UPDATE user_subscriptions SET status = 'active' WHERE id = ?").run(existing.id);
        } else {
          db.prepare(
            `INSERT INTO user_subscriptions
               (user_id, subscriptions_id, status, stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id)
             VALUES (?, ?, 'active', ?, ?, ?)`
          ).run(userId, subscriptionsId, obj.customer || null, obj.subscription || null, obj.id);
        }
      } else {
        console.warn(`[stripe webhook] ${event.type} sans user_id/subscriptions_id exploitable`, obj.id);
      }
    } else if (event.type === 'charge.refunded' || event.type === 'charge.dispute.created') {
      // Remboursement / litige sur un billet du site : accès retiré, part
      // artiste reprise, commande passée 'refunded' (voir web_tickets.js).
      // Un abonnement remboursé n'est pas géré ici (customer.subscription.*).
      try {
        await webTickets.handleRefund(obj, event.type === 'charge.refunded' ? 'refund' : 'dispute');
      } catch (e) {
        console.error('[stripe webhook] remboursement non appliqué, Stripe rejouera :', e.message);
        return res.status(500).json({ received: false });
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
    return res.json({ received: true });
  }

  markProcessed();
  return res.json({ received: true });
});

module.exports = router;

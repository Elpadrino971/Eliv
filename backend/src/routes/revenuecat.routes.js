'use strict';

/**
 * Webhook RevenueCat (POST /api/revenuecat/webhook). Contrairement à
 * Mux/Stripe, RevenueCat n'utilise pas de signature HMAC : l'authenticité se
 * vérifie via un simple header `Authorization: Bearer <secret>` fixé à la
 * création du webhook (Dashboard RevenueCat ou API). Body JSON normal, pas
 * besoin de corps brut -> monté comme une route classique (pas dans app.js
 * avant express.json()).
 *
 * app_user_id doit correspondre à notre users.id : l'app appelle
 * `Purchases.logIn(userId)` après connexion (voir spalash_screen.dart /
 * auth_controller.dart) pour aligner l'identité RevenueCat sur la nôtre.
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');

const ACTIVE_EVENTS = new Set([
  'INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION', 'SUBSCRIPTION_EXTENDED',
]);

router.post('/', (req, res) => {
  const secret = process.env.REVENUECAT_WEBHOOK_AUTH;
  if (secret) {
    const header = req.headers['authorization'] || '';
    if (header !== `Bearer ${secret}`) {
      console.warn('[revenuecat webhook] Authorization invalide, rejeté');
      return res.status(401).json({ status: 'error', message: 'Unauthorized.' });
    }
  }

  const event = req.body?.event || {};
  console.log(`[revenuecat webhook] ${event.type}`);

  try {
    const userId = Number(event.app_user_id);
    const productId = event.product_id;
    const sub = productId
      ? db.prepare('SELECT id FROM subscriptions WHERE revenuecat_product_id = ?').get(productId)
      : null;

    if (userId && sub) {
      if (ACTIVE_EVENTS.has(event.type)) {
        const existing = db.prepare(
          'SELECT id FROM user_subscriptions WHERE user_id = ? AND subscriptions_id = ?'
        ).get(userId, sub.id);
        if (existing) {
          db.prepare("UPDATE user_subscriptions SET status = 'active' WHERE id = ?").run(existing.id);
        } else {
          db.prepare(
            "INSERT INTO user_subscriptions (user_id, subscriptions_id, status) VALUES (?, ?, 'active')"
          ).run(userId, sub.id);
        }
      } else if (event.type === 'EXPIRATION') {
        db.prepare(
          "UPDATE user_subscriptions SET status = 'cancelled' WHERE user_id = ? AND subscriptions_id = ?"
        ).run(userId, sub.id);
      } else if (event.type === 'BILLING_ISSUE') {
        db.prepare(
          "UPDATE user_subscriptions SET status = 'past_due' WHERE user_id = ? AND subscriptions_id = ?"
        ).run(userId, sub.id);
      }
      // CANCELLATION = auto-renouvellement coupé mais accès actif jusqu'à la
      // fin de période -> RevenueCat enverra EXPIRATION à ce moment-là.
    } else if (event.type && productId) {
      console.warn(`[revenuecat webhook] produit "${productId}" non mappé à un abonnement admin`);
    }
  } catch (e) {
    console.error('[revenuecat webhook] erreur traitement', e.message);
  }

  return res.json({ received: true });
});

module.exports = router;

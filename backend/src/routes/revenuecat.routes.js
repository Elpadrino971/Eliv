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

// Évènements d'achat qui créditent des points (packs consommables).
const PURCHASE_EVENTS = new Set(['INITIAL_PURCHASE', 'NON_RENEWING_PURCHASE']);

// Résout NOTRE users.id à partir des identifiants RevenueCat de l'évènement.
// L'app appelle `Purchases.logIn(userId)` pour aligner l'identité RevenueCat
// sur la nôtre, mais si l'achat a lieu AVANT que ce logIn ait pris effet
// (ancienne version de l'app, ou logIn asynchrone pas encore terminé), la
// transaction reste rattachée à un identifiant anonyme `$RCAnonymousID:...`.
// Dans ce cas `Number(app_user_id)` = NaN -> aucun crédit -> échec silencieux
// (argent pris, 0 point). Pour éviter ça, on cherche le PREMIER identifiant qui
// est un vrai numéro d'utilisateur parmi app_user_id, original_app_user_id et
// aliases (RevenueCat liste tous les ID d'un même client). Retourne null si
// aucun n'est numérique (achat réellement anonyme -> crédit manuel requis).
function resolveUserId(event) {
  const candidates = [
    event.app_user_id,
    event.original_app_user_id,
    ...(Array.isArray(event.aliases) ? event.aliases : []),
  ];
  for (const c of candidates) {
    if (c == null) continue;
    const s = String(c).trim();
    if (/^\d+$/.test(s)) {
      const n = Number(s);
      if (Number.isInteger(n) && n > 0) return n;
    }
  }
  return null;
}

// Dernier filet : si l'identité RevenueCat est purement anonyme (aucun ID
// numérique), on tente de retrouver l'utilisateur par son EMAIL. L'app publie
// l'email via `Purchases.setEmail(...)` -> RevenueCat le renvoie dans
// `event.subscriber_attributes.$email.value`. On matche alors `users.email`.
// Sans email publié (anciennes versions), retourne null -> crédit manuel.
function resolveUserIdByEmail(event) {
  const attrs = event.subscriber_attributes || {};
  const raw = attrs['$email'] && attrs['$email'].value != null ? attrs['$email'].value : null;
  const email = raw ? String(raw).trim().toLowerCase() : '';
  if (!email) return null;
  const row = db.prepare('SELECT id FROM users WHERE lower(email) = ?').get(email);
  return row ? row.id : null;
}

// Sans REVENUECAT_WEBHOOK_AUTH, n'importe qui peut POSTer ce endpoint avec un
// faux event INITIAL_PURCHASE et s'auto-créditer des points/un abonnement
// gratuitement -> vérifier au démarrage que le secret est bien configuré.
if (!process.env.REVENUECAT_WEBHOOK_AUTH) {
  const msg =
    '[revenuecat webhook] REVENUECAT_WEBHOOK_AUTH absent : ce webhook accepterait ' +
    'N\'IMPORTE QUEL appel non authentifié (faux achats/abonnements gratuits). ' +
    'Configure ce secret côté serveur ET dans le dashboard RevenueCat.';
  // En production : refus de démarrer (fail-closed), comme le JWT_SECRET.
  if (process.env.NODE_ENV === 'production') throw new Error(msg);
  console.error('⚠️⚠️ ' + msg + ' (toléré en dev uniquement)');
}

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
    // 1) ID numérique (app_user_id / original / alias) ; 2) sinon, repli par
    //    email publié via subscriber_attributes. Un des deux suffit à créditer.
    let userId = resolveUserId(event);
    if (!userId) userId = resolveUserIdByEmail(event);
    const productId = event.product_id;

    // ── Pack de points (recharge portefeuille via IAP) ──
    const pack = productId
      ? db.prepare('SELECT id, points FROM packages WHERE revenuecat_product_id = ?').get(productId)
      : null;
    if (pack && PURCHASE_EVENTS.has(event.type)) {
      // Achat de points reconnu mais impossible à rattacher à un utilisateur
      // (identité anonyme) : on le LOG explicitement pour crédit manuel plutôt
      // que de l'avaler en silence (l'argent a bien été pris côté store).
      if (!userId) {
        console.warn(
          `[revenuecat webhook] ACHAT DE POINTS NON ATTRIBUÉ : app_user_id="${event.app_user_id}" ` +
            `non numérique (identité anonyme). pack=${productId} tx=${event.transaction_id || '?'} ` +
            `-> crédit manuel requis.`
        );
        return res.json({ received: true });
      }
      // Dédup : les webhooks RevenueCat sont ré-émis, ne créditer qu'une fois.
      const evId = String(event.id || `${event.app_user_id}:${event.transaction_id || productId}:${event.purchased_at_ms || ''}`);
      const seen = db.prepare('SELECT event_id FROM rc_processed_events WHERE event_id = ?').get(evId);
      if (!seen) {
        const credit = db.transaction(() => {
          db.prepare('INSERT INTO rc_processed_events (event_id) VALUES (?)').run(evId);
          const user = db.prepare('SELECT points FROM users WHERE id = ?').get(userId);
          if (user) {
            const newBal = ((parseFloat(user.points) || 0) + (parseFloat(pack.points) || 0)).toFixed(2);
            db.prepare('UPDATE users SET points = ? WHERE id = ?').run(newBal, userId);
          }
        });
        credit();
        console.log(`[revenuecat webhook] +${pack.points} points -> user ${userId} (pack ${productId})`);
      }
      return res.json({ received: true });
    }

    const sub = productId
      ? db.prepare('SELECT id FROM subscriptions WHERE revenuecat_product_id = ?').get(productId)
      : null;

    // Abonnement reconnu mais identité anonyme : même problème que les points,
    // on le signale au lieu de l'ignorer (l'abonnement ne serait pas activé).
    if (sub && !userId && (ACTIVE_EVENTS.has(event.type) || event.type === 'EXPIRATION' || event.type === 'BILLING_ISSUE')) {
      console.warn(
        `[revenuecat webhook] ABONNEMENT NON ATTRIBUÉ : app_user_id="${event.app_user_id}" ` +
          `non numérique (identité anonyme). product=${productId} event=${event.type} -> action manuelle requise.`
      );
    }

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

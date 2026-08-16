'use strict';

/**
 * Vérification serveur-à-serveur des achats via l'API REST RevenueCat.
 * Sert à NE PLUS faire confiance aveuglément à l'app : avant de créditer un
 * portefeuille (billet) ou d'activer un abonnement, on confirme l'achat auprès
 * de RevenueCat (source de vérité). Utilise REVENUECAT_API_KEY (clé SECRÈTE
 * "v1", lecture des subscribers) — à mettre dans le .env de prod.
 *
 * app_user_id = users.id (l'app fait Purchases.logIn(userId) après connexion).
 */

const API_BASE = 'https://api.revenuecat.com/v1';

function isConfigured() {
  return !!process.env.REVENUECAT_API_KEY;
}

async function _getSubscriber(userId) {
  const res = await fetch(
    `${API_BASE}/subscribers/${encodeURIComponent(String(userId))}`,
    {
      headers: {
        Authorization: `Bearer ${process.env.REVENUECAT_API_KEY}`,
        'Content-Type': 'application/json',
      },
    }
  );
  if (!res.ok) {
    throw new Error(`RevenueCat API ${res.status}`);
  }
  const json = await res.json();
  return json?.subscriber || {};
}

/**
 * Un abonnement (productId) est-il actif pour ce user chez RevenueCat ?
 */
async function hasActiveSubscription(userId, productId) {
  if (!userId || !productId) return false;
  const sub = await _getSubscriber(userId);
  const subs = sub.subscriptions || {};
  const s = subs[productId];
  if (!s) return false;
  if (!s.expires_date) return true; // non-expirant / lifetime
  return new Date(s.expires_date).getTime() > Date.now();
}

/**
 * Achats consommables (non_subscriptions) d'un productId pour ce user.
 * Renvoie un tableau d'objets { id (store_transaction_id), purchase_date, ... }.
 */
async function nonSubscriptionPurchases(userId, productId) {
  if (!userId || !productId) return [];
  const sub = await _getSubscriber(userId);
  const ns = sub.non_subscriptions || {};
  return Array.isArray(ns[productId]) ? ns[productId] : [];
}

module.exports = {
  isConfigured,
  hasActiveSubscription,
  nonSubscriptionPurchases,
};

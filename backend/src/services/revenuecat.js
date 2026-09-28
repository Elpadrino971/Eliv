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

// Surchargeable (REVENUECAT_API_BASE) uniquement pour les tests locaux avec un
// faux serveur ; en production, laisser la valeur par défaut.
const API_BASE = (process.env.REVENUECAT_API_BASE || 'https://api.revenuecat.com/v1').replace(/\/+$/, '');

function isConfigured() {
  return !!process.env.REVENUECAT_API_KEY;
}

// Délai max d'un appel RevenueCat. Sans borne, un incident chez eux bloquait
// /buy-ticket indéfiniment (et donc l'entrée en salle le soir du concert).
const TIMEOUT_MS = Number(process.env.REVENUECAT_TIMEOUT_MS) || 8000;

async function _getSubscriber(userId) {
  let res;
  try {
    res = await fetch(
      `${API_BASE}/subscribers/${encodeURIComponent(String(userId))}`,
      {
        headers: {
          Authorization: `Bearer ${process.env.REVENUECAT_API_KEY}`,
          'Content-Type': 'application/json',
        },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      }
    );
  } catch (e) {
    const timedOut = e && (e.name === 'TimeoutError' || e.name === 'AbortError');
    const err = new Error(timedOut ? `RevenueCat API timeout (${TIMEOUT_MS} ms)` : `RevenueCat API injoignable : ${e.message}`);
    err.code = timedOut ? 'RC_TIMEOUT' : 'RC_UNREACHABLE';
    throw err;
  }
  if (!res.ok) {
    const err = new Error(`RevenueCat API ${res.status}`);
    err.code = 'RC_HTTP';
    err.status = res.status;
    throw err;
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
 * Renvoie un tableau d'objets { id (store_transaction_id), purchase_date,
 * is_sandbox, store, ... }. En production, les achats sandbox (TestFlight /
 * comptes testeurs) sont écartés : ils ne correspondent à aucun encaissement
 * et ne doivent jamais créditer un wallet artiste.
 */
async function nonSubscriptionPurchases(userId, productId, { includeSandbox = process.env.NODE_ENV !== 'production' } = {}) {
  if (!userId || !productId) return [];
  const sub = await _getSubscriber(userId);
  const ns = sub.non_subscriptions || {};
  const list = Array.isArray(ns[productId]) ? ns[productId] : [];
  return includeSandbox ? list : list.filter((p) => !p || !p.is_sandbox);
}

module.exports = {
  isConfigured,
  hasActiveSubscription,
  nonSubscriptionPurchases,
  TIMEOUT_MS,
};

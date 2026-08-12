'use strict';

/**
 * Primes apporteur (« primes de signature » du contrat AXEN DIGITAL / Amandine) :
 *   - Pionnier   : 150 € par artiste, au 1er live effectivement diffusé (art 6.1)
 *   - Fondateur  : 300 € par artiste, à l'encaissement de la 3e mensualité (art 6.2)
 * Non-cumul (art 6.3) : une seule prime par artiste — la plus élevée (qualité
 * retenue) l'emporte. Elles se cumulent avec la commission récurrente (art 6.4).
 *
 * La commission court « 24 mois à compter du premier live » (art 7.2) : le
 * premier live (re)positionne donc `commission_end` quand le deal le précise
 * (`commission_from = 'first_live'`).
 *
 * Tous les montants / durées vivent dans `apporteurs.deal_params` — rien en dur.
 */

const { db } = require('../db');

function dealOf(apporteurId) {
  const a = db.prepare('SELECT * FROM apporteurs WHERE id = ?').get(apporteurId);
  if (!a) return null;
  let p = {};
  try { p = JSON.parse(a.deal_params || '{}'); } catch (_) { p = {}; }
  return { a, p };
}

/**
 * Enregistre une prime — UNE SEULE par artiste (non-cumul art 6.3). Si une prime
 * existe déjà pour cet artiste, on ne garde que la plus élevée (upgrade Pionnier
 * -> Fondateur), jamais les deux.
 */
function recordBonusOnce({ apporteurId, artistId, type, amount, status = 'exigible' }) {
  if (!apporteurId || !artistId || !(Number(amount) > 0)) return;
  const existing = db.prepare(
    'SELECT id, amount FROM apporteur_bonuses WHERE apporteur_id = ? AND artist_id = ?'
  ).get(apporteurId, artistId);
  if (existing) {
    if (Number(amount) > Number(existing.amount)) {
      db.prepare("UPDATE apporteur_bonuses SET type = ?, amount = ?, status = ?, triggered_at = datetime('now') WHERE id = ?")
        .run(type, String(amount), status, existing.id);
    }
    return;
  }
  db.prepare('INSERT INTO apporteur_bonuses (apporteur_id, artist_id, type, amount, status) VALUES (?, ?, ?, ?, ?)')
    .run(apporteurId, artistId, type, String(amount), status);
}

/**
 * À appeler quand un artiste passe EN DIRECT. Idempotent via `users.first_live_at`
 * (seul le TOUT PREMIER live déclenche la prime + le départ des 24 mois).
 */
function onFirstLive(artistId) {
  const u = db.prepare(
    'SELECT id, apporteur_id, first_live_at FROM users WHERE id = ?'
  ).get(artistId);
  if (!u) return;
  const isFirst = !u.first_live_at;
  if (isFirst) db.prepare("UPDATE users SET first_live_at = datetime('now') WHERE id = ?").run(artistId);
  if (!isFirst || !u.apporteur_id) return;

  const d = dealOf(u.apporteur_id);
  if (!d) return;

  // Commission « 24 mois à compter du premier live » (art 7.2).
  if (d.p.commission_from === 'first_live' && d.p.commission_months) {
    db.prepare("UPDATE users SET commission_end = datetime('now', '+' || ? || ' months') WHERE id = ?")
      .run(d.p.commission_months, artistId);
  }
  // Prime Pionnier (art 6.1), exigible à la date du premier live.
  const pio = d.p.primes && d.p.primes.pionnier;
  if (pio && pio.amount) {
    recordBonusOnce({ apporteurId: u.apporteur_id, artistId, type: 'pionnier', amount: pio.amount, status: 'exigible' });
  }
}

/**
 * À appeler à l'encaissement de la 3e mensualité d'abonnement Fondateur (art 6.2).
 * Upgrade la prime Pionnier -> Fondateur si besoin (non-cumul).
 */
function onFondateurThirdPayment(artistId) {
  const u = db.prepare('SELECT apporteur_id FROM users WHERE id = ?').get(artistId);
  if (!u || !u.apporteur_id) return;
  const d = dealOf(u.apporteur_id);
  if (!d) return;
  const fon = d.p.primes && d.p.primes.fondateur;
  if (fon && fon.amount) {
    recordBonusOnce({ apporteurId: u.apporteur_id, artistId, type: 'fondateur', amount: fon.amount, status: 'exigible' });
  }
}

module.exports = { onFirstLive, onFondateurThirdPayment, recordBonusOnce };

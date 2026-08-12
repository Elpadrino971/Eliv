'use strict';

/**
 * Orchestration APPORTEUR (accès base). Fait le lien entre le moteur pur
 * (services/apporteur.js) et la base : lit la phase de l'artiste + le deal de
 * son apporteur, décide de l'éligibilité, et enregistre les lignes de commission.
 * Voir APPORTEURS.md.
 */

const { db } = require('../db');
const engine = require('./apporteur');
const { resolveArtistCommission } = require('../helpers');

// SQLite stocke les dates en 'YYYY-MM-DD HH:MM:SS' (UTC). -> ms epoch.
function parseTs(s) {
  if (!s) return null;
  const t = Date.parse(String(s).replace(' ', 'T') + 'Z');
  return Number.isFinite(t) ? t : null;
}

/**
 * Contexte de commission d'un artiste à un instant donné : son apporteur (s'il
 * en a un), l'éligibilité (apporteur actif, non suspendu, dans la période, pas
 * un parrain), le deal, la métrique de la jauge (nb d'artistes rattachés), et
 * le taux de partage artiste courant (promo 50% / offre).
 */
function artistContext(artistId, nowMs) {
  const offerRate = resolveArtistCommission(artistId); // % part artiste (offre/60)
  const u = db.prepare(
    'SELECT id, apporteur_id, artist_regime, sub_free_until, commission_end FROM users WHERE id = ?'
  ).get(artistId);
  const subFreeUntilMs = parseTs(u?.sub_free_until);
  if (!u || !u.apporteur_id) {
    return { eligible: false, apporteurId: null, deal: null, metricValue: 0, offerRate, subFreeUntilMs };
  }
  const ap = db.prepare('SELECT * FROM apporteurs WHERE id = ?').get(u.apporteur_id);
  const suspended = !!db
    .prepare('SELECT 1 FROM apporteur_reports WHERE artist_id = ? AND apporteur_id = ? LIMIT 1')
    .get(artistId, u.apporteur_id);
  const commissionEndMs = parseTs(u.commission_end);
  const withinPeriod = commissionEndMs == null || nowMs < commissionEndMs;
  const isParrain = (u.artist_regime || 'normal') === 'parrain';
  const active = !!ap && ap.status === 'active';
  const eligible = !!(active && !suspended && withinPeriod && !isParrain);
  const metricValue = db.prepare('SELECT COUNT(*) c FROM users WHERE apporteur_id = ?').get(u.apporteur_id).c;
  let deal = null;
  if (ap) {
    let params = {};
    try { params = JSON.parse(ap.deal_params || '{}'); } catch (_) { params = {}; }
    deal = { type: ap.deal_type, params };
  }
  return { eligible, apporteurId: u.apporteur_id, deal, metricValue, offerRate, subFreeUntilMs, artistRegime: u.artist_regime };
}

/**
 * Décompose une vente (brut EUR pour un billet) selon la formule unique, en
 * tenant compte de la phase artiste + du deal apporteur. Renvoie le détail + le
 * contexte. Ne touche pas la base (le caller enregistre dans sa transaction).
 * @param {number} storeFee override (0 pour un cadeau en points : la commission
 *   store a déjà été prélevée à l'achat du pack).
 */
function computeForSale(artistId, gross, { nowMs, storeFee } = {}) {
  const now = Number.isFinite(nowMs) ? nowMs : Date.now();
  const ctx = artistContext(artistId, now);
  const artistRatePct = engine.artistShareRate({
    subFreeUntilMs: ctx.subFreeUntilMs, offerRate: ctx.offerRate, nowMs: now,
  });
  const apporteurRatePct = ctx.eligible
    ? engine.apporteurRateFromDeal(ctx.deal, { metricValue: ctx.metricValue, eligible: true })
    : 0;
  const opts = { gross, artistRatePct, apporteurRatePct };
  if (storeFee != null) opts.storeFee = storeFee;
  const breakdown = engine.computeCommission(opts);
  return { ctx, artistRatePct, apporteurRatePct, breakdown };
}

/** Enregistre la ligne de commission apporteur (à appeler DANS la transaction). */
function recordApporteurCommission({ apporteurId, artistId, sourceType, sourceId, breakdown, rate }) {
  db.prepare(
    `INSERT INTO apporteur_commissions
       (apporteur_id, artist_id, source_type, source_id, gross, store, net, artist_share, platform_share, rate, amount, encaissed, invoice_status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'due')`
  ).run(
    apporteurId, artistId, sourceType, sourceId,
    String(breakdown.gross), String(breakdown.store), String(breakdown.net),
    String(breakdown.artist), String(breakdown.platform), rate, String(breakdown.apporteur),
  );
}

module.exports = { artistContext, computeForSale, recordApporteurCommission };

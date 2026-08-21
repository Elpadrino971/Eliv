'use strict';

/**
 * Moteur de commission APPORTEUR (imprésario / manager / partenaire).
 *
 * Un apporteur amène des artistes et touche une commission sur LA PART
 * PLATEFORME NETTE générée par SES artistes. Chaque apporteur a un deal
 * différent → aucune valeur métier n'est codée en dur : le deal vit en base
 * (`apporteurs.deal_type` + `apporteurs.deal_params` JSON) et ce module ne fait
 * que L'APPLIQUER. Nouveau contrat = de la donnée, pas du code (voir APPORTEURS.md).
 *
 * Ce fichier est PUR (aucun accès base) → entièrement testable. L'orchestration
 * (enregistrer les lignes de commission, gating encaissement/facture) vit
 * ailleurs et appelle ces fonctions.
 *
 * LA FORMULE UNIQUE (on divise sur le NET, jamais sur le brut) :
 *   brut → −store(15%) = net → −part artiste = PART PLATEFORME
 *   commission apporteur = taux_apporteur × PART PLATEFORME
 */

// Configurable par env (les prix/taux peuvent évoluer sans redéploiement).
const STORE_FEE_RATE = clampRate(numEnv('STORE_FEE_RATE', 0.15), 0, 1); // Apple/Google
const PROMO_ARTIST_RATE = numEnv('PROMO_ARTIST_RATE', 50);   // % artiste pendant les 3 mois offerts
const DEFAULT_ARTIST_RATE = numEnv('DEFAULT_ARTIST_RATE', 58.8); // % artiste du net (modèle unifié gratuit : ~50% du brut à 15% de frais)

function numEnv(key, dflt) {
  const v = parseFloat(process.env[`APPORTEUR_${key}`] ?? process.env[key]);
  return Number.isFinite(v) ? v : dflt;
}
function num(v, dflt = 0) { const n = typeof v === 'number' ? v : parseFloat(v); return Number.isFinite(n) ? n : dflt; }
function round2(n) { return Math.round((num(n) + Number.EPSILON) * 100) / 100; }
function clampRate(v, lo, hi) { return Math.max(lo, Math.min(hi, num(v))); }

/** Montant réellement reçu après la commission du store (Apple/Google). */
function netAfterStore(gross, storeFee = STORE_FEE_RATE) {
  return round2(num(gross) * (1 - clampRate(storeFee, 0, 1)));
}

/**
 * Taux de partage ARTISTE (%) à un instant donné. Pendant les 3 mois offerts :
 * PROMO (50%). Après : le taux de son offre en cours (abonnement), sinon défaut.
 * @param {{subFreeUntilMs?:number, offerRate?:number, nowMs:number}} ctx
 */
function artistShareRate({ subFreeUntilMs, offerRate, nowMs }) {
  if (subFreeUntilMs && nowMs < subFreeUntilMs) return PROMO_ARTIST_RATE;
  const r = num(offerRate, DEFAULT_ARTIST_RATE);
  return clampRate(r, 0, 100);
}

/**
 * Taux APPORTEUR (%) à appliquer, selon son deal.
 *  - 'simple'      : params.rate (taux fixe)
 *  - 'fixe_primes' : params.rate (taux fixe ; les primes sont gérées à part)
 *  - 'paliers'     : JAUGE. params.tiers = [{min, rate}] (min = seuil de la
 *                    métrique, ex nb d'artistes). On prend le palier le plus
 *                    haut dont le seuil est atteint, borné par params.floor /
 *                    params.cap. ctx.metricValue = valeur courante de la métrique.
 * Renvoie 0 si le deal ne s'applique pas (hors période / suspendu / parrain) —
 * ces conditions sont passées via ctx.eligible (calculé par l'orchestration).
 * @returns {number} pourcentage 0..100
 */
function apporteurRateFromDeal(deal, ctx = {}) {
  if (ctx.eligible === false) return 0;
  if (!deal || !deal.type) return 0;
  const p = deal.params || {};
  switch (deal.type) {
    case 'simple':
    case 'fixe_primes':
      return clampRate(num(p.rate), 0, 100);
    case 'paliers': {
      const tiers = Array.isArray(p.tiers) ? [...p.tiers].sort((a, b) => num(a.min) - num(b.min)) : [];
      const metric = num(ctx.metricValue);
      let rate = num(p.floor, tiers[0] ? num(tiers[0].rate) : 0);
      for (const t of tiers) if (metric >= num(t.min)) rate = num(t.rate);
      const floor = p.floor != null ? num(p.floor) : rate;
      const cap = p.cap != null ? num(p.cap) : rate;
      return clampRate(Math.max(floor, Math.min(cap, rate)), 0, 100);
    }
    default:
      return 0;
  }
}

/**
 * Décompose une vente selon la formule unique.
 * @param {{gross:number, storeFee?:number, artistRatePct:number, apporteurRatePct?:number}} p
 * @returns {{gross,store,net,artist,platform,apporteur,kept}} tous en unité d'entrée
 */
function computeCommission({ gross, storeFee = STORE_FEE_RATE, artistRatePct, apporteurRatePct = 0 }) {
  const g = num(gross);
  const net = netAfterStore(g, storeFee);
  const store = round2(g - net);
  const artist = round2(net * clampRate(artistRatePct, 0, 100) / 100);
  const platform = round2(net - artist);
  const apporteur = round2(platform * clampRate(apporteurRatePct, 0, 100) / 100);
  const kept = round2(platform - apporteur);
  return { gross: round2(g), store, net, artist, platform, apporteur, kept };
}

module.exports = {
  STORE_FEE_RATE, PROMO_ARTIST_RATE, DEFAULT_ARTIST_RATE,
  netAfterStore, artistShareRate, apporteurRateFromDeal, computeCommission,
  round2,
};

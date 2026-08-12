'use strict';

/**
 * Relevés mensuels (transparence de la redistribution). Source de vérité : le
 * ledger `platform_earnings` (une ligne par vente : billet en EUR, cadeau en
 * POINTS). Sert les relevés artiste ET apporteur.
 *
 * Unités : billets en €, cadeaux/tips en points (1 € = 100 points).
 */

const { db } = require('../db');

function round2(n) { const v = parseFloat(n); return Number.isFinite(v) ? Math.round(v * 100) / 100 : 0; }
const pad = (n) => String(n).padStart(2, '0');

/** 'YYYY-MM' -> { from, to (mois suivant), label 'MM/YYYY' }. Défaut : mois courant (UTC). */
function monthRange(month) {
  let y, m;
  if (/^\d{4}-\d{2}$/.test(month || '')) { const p = String(month).split('-'); y = +p[0]; m = +p[1]; }
  else { const d = new Date(); y = d.getUTCFullYear(); m = d.getUTCMonth() + 1; }
  const from = `${y}-${pad(m)}-01 00:00:00`;
  const ny = m === 12 ? y + 1 : y;
  const nm = m === 12 ? 1 : m + 1;
  const to = `${ny}-${pad(nm)}-01 00:00:00`;
  return { from, to, label: `${pad(m)}/${y}`, month: `${y}-${pad(m)}` };
}

/** Relevé mensuel d'un ARTISTE : billets (nb + brut + net) + tips (nb + points + net) + total net €. */
function artistStatement(artistId, month) {
  const r = monthRange(month);
  const t = db.prepare(
    `SELECT COUNT(*) n, COALESCE(SUM(CAST(gross AS REAL)),0) gross, COALESCE(SUM(CAST(artist_share AS REAL)),0) net
     FROM platform_earnings WHERE artist_id = ? AND source = 'ticket' AND created_at >= ? AND created_at < ?`
  ).get(artistId, r.from, r.to);
  const g = db.prepare(
    `SELECT COUNT(*) n, COALESCE(SUM(CAST(gross AS REAL)),0) pts, COALESCE(SUM(CAST(artist_share AS REAL)),0) netpts
     FROM platform_earnings WHERE artist_id = ? AND source = 'gift' AND created_at >= ? AND created_at < ?`
  ).get(artistId, r.from, r.to);
  const u = db.prepare('SELECT artist_name, full_name FROM users WHERE id = ?').get(artistId);
  const ticketsNet = round2(t.net);
  const tipsNet = round2(g.netpts / 100); // points -> €
  return {
    period: r.label, month: r.month,
    artist: u ? (u.artist_name || u.full_name || ('#' + artistId)) : ('#' + artistId),
    artist_id: Number(artistId),
    tickets: { count: t.n, gross_eur: round2(t.gross), net_eur: ticketsNet },
    tips: { count: g.n, points: Math.round(g.pts), net_eur: tipsNet },
    total_net_eur: round2(ticketsNet + tipsNet),
  };
}

/** Relevé mensuel d'un APPORTEUR : commissions + primes du mois (art. 7.3). */
function apporteurStatement(apporteurId, month) {
  const r = monthRange(month);
  const c = db.prepare(
    `SELECT COUNT(*) n, COALESCE(SUM(CAST(amount AS REAL)),0) amt, COALESCE(SUM(CAST(platform_share AS REAL)),0) base
     FROM apporteur_commissions WHERE apporteur_id = ? AND created_at >= ? AND created_at < ?`
  ).get(apporteurId, r.from, r.to);
  const b = db.prepare(
    `SELECT COUNT(*) n, COALESCE(SUM(CAST(amount AS REAL)),0) amt
     FROM apporteur_bonuses WHERE apporteur_id = ? AND triggered_at >= ? AND triggered_at < ?`
  ).get(apporteurId, r.from, r.to);
  const a = db.prepare('SELECT name, structure FROM apporteurs WHERE id = ?').get(apporteurId);
  return {
    period: r.label, month: r.month,
    apporteur: a ? (a.structure || a.name) : ('#' + apporteurId),
    apporteur_id: Number(apporteurId),
    commission: { count: c.n, base_eur: round2(c.base), eur: round2(c.amt) },
    primes: { count: b.n, eur: round2(b.amt) },
    total_eur: round2(c.amt + b.amt),
  };
}

module.exports = { artistStatement, apporteurStatement, monthRange };

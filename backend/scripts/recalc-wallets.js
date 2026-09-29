#!/usr/bin/env node
'use strict';

/**
 * Recalcule le portefeuille (users.wallet, en EUROS) de chaque artiste à
 * partir du ledger, et affiche les écarts avec la valeur stockée.
 *
 *   wallet attendu = Σ platform_earnings.artist_share (source ticket / ticket_web, en €)
 *                    pour les billets SANS lignes wallet_transactions 'ticket_share'
 *                    (ventes antérieures au lot 7)
 *                  + Σ wallet_transactions 'ticket_share' (crédits − débits, en €)
 *                    (lot 7 : part artiste partagée entre principal et invités —
 *                    platform_earnings porte la part artiste TOTALE sur le
 *                    principal, les lignes ticket_share portent ce que chacun touche)
 *                  + Σ platform_earnings.artist_share (source gift, en POINTS) / 100
 *                  − Σ withdrawals.amount (hors statut rejected / refused / cancelled)
 *
 * Les lignes de remboursement sont des lignes NÉGATIVES du ledger : elles
 * sont donc soustraites naturellement.
 *
 * Pourquoi : jusqu'au lot 2D, /event-gift créditait la part artiste EN POINTS
 * directement dans le wallet EN EUROS (×100). Ce script sert d'abord à
 * constater les écarts (dry-run, comportement par défaut) puis à corriger
 * (`--apply`).
 *
 *   VYBZZZ_DB=/chemin/vybzzz.sqlite node scripts/recalc-wallets.js
 *   VYBZZZ_DB=/chemin/vybzzz.sqlite node scripts/recalc-wallets.js --apply
 *   ... --artist=42   (un seul artiste)
 *
 * Faire une sauvegarde AVANT --apply (scripts/backup-db.js).
 */

const path = require('path');
const Database = require('better-sqlite3');

const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const onlyArg = args.find((a) => a.startsWith('--artist='));
const ONLY = onlyArg ? Number(onlyArg.split('=')[1]) : null;

const DB_PATH = process.env.VYBZZZ_DB || path.join(__dirname, '..', 'vybzzz.sqlite');
const db = new Database(DB_PATH);

const REJECTED = "('rejected','refused','cancelled','canceled','declined')";

const artists = db.prepare(
  `SELECT id, email, artist_name, full_name, wallet FROM users
    WHERE is_artist = 1 ${ONLY ? 'AND id = ?' : ''} ORDER BY id`
).all(...(ONLY ? [ONLY] : []));

const qTickets = db.prepare(
  `SELECT COALESCE(SUM(CAST(p.artist_share AS REAL)), 0) s FROM platform_earnings p
    WHERE p.artist_id = ? AND p.source IN ('ticket', 'ticket_web')
      AND NOT EXISTS (SELECT 1 FROM wallet_transactions w
                       WHERE w.type = 'ticket_share' AND w.source_id = CAST(p.source_id AS TEXT))`
);
const qShares = db.prepare(
  `SELECT COALESCE(SUM(CASE WHEN direction = 'credit' THEN CAST(amount AS REAL) ELSE -CAST(amount AS REAL) END), 0) s
     FROM wallet_transactions WHERE user_id = ? AND type = 'ticket_share'`
);
const qGifts = db.prepare(
  `SELECT COALESCE(SUM(CAST(artist_share AS REAL)), 0) s FROM platform_earnings
    WHERE artist_id = ? AND source = 'gift'`
);
const qWithdrawals = db.prepare(
  `SELECT COALESCE(SUM(CAST(amount AS REAL)), 0) s FROM withdrawals
    WHERE user_id = ? AND COALESCE(status, '') NOT IN ${REJECTED}`
);
const qUpdate = db.prepare('UPDATE users SET wallet = ? WHERE id = ?');

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const mask = (e) => {
  const s = String(e || '');
  const at = s.indexOf('@');
  return at > 0 ? `${s[0]}***@${s.slice(at + 1)}` : '***';
};

console.log(`[recalc-wallets] base : ${DB_PATH}`);
console.log(`[recalc-wallets] mode : ${APPLY ? 'APPLICATION (--apply)' : 'dry-run (aucune écriture)'}`);
console.log('');

let diffs = 0;
const rows = [];
for (const a of artists) {
  const tickets = round2(qTickets.get(a.id).s + qShares.get(a.id).s); // €
  const giftsPts = qGifts.get(a.id).s;           // points
  const withdrawn = qWithdrawals.get(a.id).s;    // €
  const raw = round2(tickets + giftsPts / 100 - withdrawn);
  // Un wallet ne descend jamais sous 0 : si les retraits dépassent le ledger
  // (données antérieures au ledger, ou retrait accordé à la main), on plafonne
  // à 0 et on le signale — à vérifier à la main, jamais corrigé en aveugle.
  const expected = Math.max(0, raw);
  const current = round2(parseFloat(a.wallet) || 0);
  const delta = round2(current - expected);
  const flag = Math.abs(delta) >= 0.01;
  if (flag) diffs += 1;
  rows.push({
    id: a.id,
    artiste: (a.artist_name || a.full_name || mask(a.email)).slice(0, 24),
    billets_eur: round2(tickets),
    tips_pts: Math.round(giftsPts),
    tips_eur: round2(giftsPts / 100),
    retraits_eur: round2(withdrawn),
    attendu_eur: expected,
    stocke_eur: current,
    ecart_eur: delta,
    action: (raw < 0 ? 'NÉGATIF (retraits > ledger, vérifier) · ' : '') + (flag ? (APPLY ? 'CORRIGÉ' : 'à corriger') : 'ok'),
  });
  if (flag && APPLY) qUpdate.run(expected.toFixed(2), a.id);
}

if (rows.length) console.table(rows);
else console.log('Aucun artiste.');

console.log('');
console.log(`[recalc-wallets] ${artists.length} artiste(s), ${diffs} écart(s)${APPLY ? ' corrigé(s)' : ''}.`);
if (!APPLY && diffs) console.log('[recalc-wallets] Relance avec --apply pour écrire les valeurs attendues.');

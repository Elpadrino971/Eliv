'use strict';

/**
 * Supprime les comptes de DÉMO créés par l'ancien seed (mots de passe connus)
 * sans toucher aux vrais comptes.
 *
 *   node scripts/purge-demo-accounts.js            -> dry-run (liste ce qui serait supprimé)
 *   node scripts/purge-demo-accounts.js --apply    -> exécute la suppression
 *
 * Périmètre : demo@vybzzz.com, fan1..14@vybzzz.com, artist1..5@vybzzz.com
 * (liste FERMÉE, comparaison exacte sur l'e-mail ; un compte admin n'est
 * jamais supprimé). Sont supprimés avec eux : leurs billets, suivis, activités,
 * abonnements, avis, retraits, parrainages, et les concerts fictifs dont ils
 * sont l'artiste (avec les billets/activités liés à ces concerts).
 *
 * Variables : VYBZZZ_DB (chemin de la base, défaut ../vybzzz.sqlite).
 * Fais une sauvegarde avant (scripts/backup-db.js).
 */

const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = process.env.VYBZZZ_DB || path.join(__dirname, '..', 'vybzzz.sqlite');
const APPLY = process.argv.includes('--apply');

const DEMO_EMAILS = [
  'demo@vybzzz.com',
  ...Array.from({ length: 14 }, (_, i) => `fan${i + 1}@vybzzz.com`),
  ...Array.from({ length: 5 }, (_, i) => `artist${i + 1}@vybzzz.com`),
];

const db = new Database(DB_PATH);
const placeholders = DEMO_EMAILS.map(() => '?').join(',');
const users = db.prepare(
  `SELECT id, email, role, full_name, artist_name FROM users
   WHERE lower(email) IN (${placeholders}) AND role != 'admin' ORDER BY id`
).all(...DEMO_EMAILS);

if (!users.length) {
  console.log(`[purge] aucun compte de démo dans ${DB_PATH}. Rien à faire.`);
  process.exit(0);
}
const ids = users.map((u) => u.id);
const idList = ids.join(',');
const events = db.prepare(`SELECT id, name, artist_id FROM events WHERE artist_id IN (${idList})`).all();
const eventIds = events.map((e) => e.id);
const evList = eventIds.length ? eventIds.join(',') : '-1';

function count(sql) { try { return db.prepare(sql).get().c; } catch (_) { return 0; } }
const plan = [
  ['tickets (billets des comptes démo)', `DELETE FROM tickets WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM tickets WHERE user_id IN (${idList})`],
  ['tickets (billets sur les concerts fictifs)', `DELETE FROM tickets WHERE event_id IN (${evList})`, `SELECT COUNT(*) c FROM tickets WHERE event_id IN (${evList})`],
  ['activities', `DELETE FROM activities WHERE user_id IN (${idList}) OR event_id IN (${evList})`, `SELECT COUNT(*) c FROM activities WHERE user_id IN (${idList}) OR event_id IN (${evList})`],
  ['follows', `DELETE FROM follows WHERE follower_id IN (${idList}) OR artist_id IN (${idList})`, `SELECT COUNT(*) c FROM follows WHERE follower_id IN (${idList}) OR artist_id IN (${idList})`],
  ['saved_artists', `DELETE FROM saved_artists WHERE user_id IN (${idList}) OR artist_id IN (${idList})`, `SELECT COUNT(*) c FROM saved_artists WHERE user_id IN (${idList}) OR artist_id IN (${idList})`],
  ['user_genres', `DELETE FROM user_genres WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM user_genres WHERE user_id IN (${idList})`],
  ['user_subscriptions', `DELETE FROM user_subscriptions WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM user_subscriptions WHERE user_id IN (${idList})`],
  ['reviews', `DELETE FROM reviews WHERE user_id IN (${idList}) OR event_id IN (${evList})`, `SELECT COUNT(*) c FROM reviews WHERE user_id IN (${idList}) OR event_id IN (${evList})`],
  ['withdrawals', `DELETE FROM withdrawals WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM withdrawals WHERE user_id IN (${idList})`],
  ['referrals', `DELETE FROM referrals WHERE referrer_id IN (${idList}) OR referee_id IN (${idList})`, `SELECT COUNT(*) c FROM referrals WHERE referrer_id IN (${idList}) OR referee_id IN (${idList})`],
  ['ghost_passes', `DELETE FROM ghost_passes WHERE user_id IN (${idList}) OR event_id IN (${evList})`, `SELECT COUNT(*) c FROM ghost_passes WHERE user_id IN (${idList}) OR event_id IN (${evList})`],
  ['event_signals', `DELETE FROM event_signals WHERE user_id IN (${idList}) OR event_id IN (${evList})`, `SELECT COUNT(*) c FROM event_signals WHERE user_id IN (${idList}) OR event_id IN (${evList})`],
  ['banks', `DELETE FROM banks WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM banks WHERE user_id IN (${idList})`],
  ['ideas', `DELETE FROM ideas WHERE user_id IN (${idList})`, `SELECT COUNT(*) c FROM ideas WHERE user_id IN (${idList})`],
  ['platform_earnings (ledger des artistes fictifs)', `DELETE FROM platform_earnings WHERE artist_id IN (${idList})`, `SELECT COUNT(*) c FROM platform_earnings WHERE artist_id IN (${idList})`],
  ['events (concerts fictifs)', `DELETE FROM events WHERE id IN (${evList})`, `SELECT COUNT(*) c FROM events WHERE id IN (${evList})`],
  ['users', `DELETE FROM users WHERE id IN (${idList})`, `SELECT COUNT(*) c FROM users WHERE id IN (${idList})`],
];

console.log(`[purge] base : ${DB_PATH}`);
console.log(`[purge] ${users.length} compte(s) de démo trouvé(s) :`);
for (const u of users) console.log(`  #${u.id}  ${u.email}  (${u.role}${u.artist_name ? ', ' + u.artist_name : ''})`);
if (events.length) {
  console.log(`[purge] ${events.length} concert(s) fictif(s) de ces artistes :`);
  for (const e of events) console.log(`  event #${e.id}  ${e.name}`);
}
console.log('[purge] lignes concernées :');
for (const [label, , countSql] of plan) console.log(`  ${String(count(countSql)).padStart(5)}  ${label}`);

if (!APPLY) {
  console.log('\n[purge] DRY-RUN : rien n\'a été supprimé. Relance avec --apply pour exécuter.');
  process.exit(0);
}

const run = db.transaction(() => {
  for (const [label, sql] of plan) {
    try {
      const r = db.prepare(sql).run();
      console.log(`  supprimé ${String(r.changes).padStart(5)}  ${label}`);
    } catch (e) {
      // table absente sur une vieille base : on continue
      console.log(`  ignoré         ${label} (${e.message})`);
    }
  }
});
run();
console.log('[purge] terminé.');

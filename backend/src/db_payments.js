'use strict';

/**
 * Migrations « paiements » (lot 2D). Séparées de db.js pour ne pas entrer en
 * conflit avec les autres chantiers : chaque instruction est idempotente
 * (ALTER TABLE ignoré si la colonne existe déjà, CREATE … IF NOT EXISTS) et
 * s'exécute au chargement du premier module qui `require` ce fichier
 * (events.routes.js, stripe.routes.js, event_access.js…).
 */

const { db } = require('./db');

let done = false;

// app.js `require` les routes AVANT d'appeler db.init() : sur une base neuve,
// les tables n'existent pas encore au chargement. On ne marque donc la
// migration comme faite qu'une fois les tables présentes ; les appelants
// (webhooks, billetterie) rappellent run() qui devient alors un no-op.
function run() {
  if (done) return;
  const ready = db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'web_ticket_orders'").get();
  if (!ready) return;
  done = true;

  // Dédup des évènements Stripe (les webhooks sont rejoués) : un event_id ne
  // doit produire qu'UN effet (abonnement, billet, remboursement).
  db.exec(`
    CREATE TABLE IF NOT EXISTS stripe_processed_events (
      event_id TEXT PRIMARY KEY,
      type TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  for (const sql of [
    // Remboursement Stripe : charge.refunded ne porte que le payment_intent,
    // pas la session Checkout -> on le mémorise sur la commande au paiement.
    "ALTER TABLE web_ticket_orders ADD COLUMN payment_intent_id TEXT",
    "ALTER TABLE web_ticket_orders ADD COLUMN refunded_at TEXT",
    // Billets remboursés (Stripe ou store) : status = 'refunded'.
    "ALTER TABLE tickets ADD COLUMN refunded_at TEXT",
    // Place remboursée AVANT d'avoir rejoint un compte : ne doit plus être
    // rattachée ni proposée à l'attribution manuelle.
    "ALTER TABLE pending_tickets ADD COLUMN refunded_at TEXT",
    "CREATE INDEX IF NOT EXISTS idx_web_ticket_orders_pi ON web_ticket_orders (payment_intent_id)",
    "CREATE INDEX IF NOT EXISTS idx_tickets_event_user ON tickets (event_id, user_id)",
    "CREATE INDEX IF NOT EXISTS idx_pending_tickets_ticket ON pending_tickets (ticket_id)",
  ]) {
    try { db.exec(sql); } catch (e) { /* colonne / index déjà présent */ }
  }
}

run();
// Base neuve : app.js appelle db.init() juste après ses require, dans le même
// tour synchrone -> au tick suivant les tables existent et la migration passe.
process.nextTick(run);

module.exports = { run };

'use strict';

// Filets de sécurité process : une promesse rejetée sans catch ou une
// exception hors requête ne doivent pas tuer le serveur en silence pendant un
// concert. unhandledRejection : on journalise et on continue.
// uncaughtException : l'état du process n'est plus fiable -> on journalise
// puis on sort (code 1) une fois les logs vidés ; le superviseur (Docker /
// systemd) relance.
process.on('unhandledRejection', (reason) => {
  const msg = reason && reason.stack ? reason.stack : String(reason);
  console.error('[process] promesse rejetée non gérée :', msg);
});
process.on('uncaughtException', (err) => {
  console.error('[process] exception non gérée, arrêt :', err && err.stack ? err.stack : err);
  setTimeout(() => process.exit(1), 250).unref();
  // Laisse le temps à stderr de se vider (flux non bloquant en pipe/Docker).
  if (process.stderr.writableLength === 0) process.exit(1);
});

const app = require('./app');
const { db } = require('./db');
const { startMuxCleanupJob } = require('./jobs/muxCleanup');
const { startFirebaseCleanupJob } = require('./jobs/firebaseCleanup');
const { startAgendaSyncJob } = require('./jobs/agendaSync');
const { purgeOrphanUploads } = require('./uploads');

const PORT = process.env.PORT || 8002;
const IS_PROD = process.env.NODE_ENV === 'production';

// Seed automatique si la base est vide (premier démarrage). En production :
// données de référence + compte admin uniquement (mot de passe fourni par
// ADMIN_INITIAL_PASSWORD) — jamais les comptes de démo aux mots de passe
// connus (demo@…/password, admin@…/admin123).
const userCount = db.prepare('SELECT COUNT(*) c FROM users').get().c;
if (userCount === 0) {
  const seed = require('./seed');
  if (IS_PROD) {
    console.log('[seed] base vide (production) -> référentiel + compte admin…');
    seed.runProduction(); // lève une erreur claire si ADMIN_INITIAL_PASSWORD manque
  } else {
    console.log('[seed] base vide -> initialisation des données de démo…');
    seed.run();
  }
}

// Fichiers temporaires d'upload (multer) jamais consommés : purge au démarrage.
purgeOrphanUploads();

startMuxCleanupJob();
startFirebaseCleanupJob();
startAgendaSyncJob();

app.listen(PORT, () => {
  console.log(`\n  VYBZZZ backend en écoute sur http://localhost:${PORT}`);
  console.log(`  API base: http://localhost:${PORT}/api`);
  console.log(`  (pointe l'app dessus via APIs.mainIP)\n`);
});

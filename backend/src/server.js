'use strict';

const app = require('./app');
const { db } = require('./db');

const PORT = process.env.PORT || 8002;

// Seed automatique si la base est vide (premier démarrage)
const userCount = db.prepare('SELECT COUNT(*) c FROM users').get().c;
if (userCount === 0) {
  console.log('[seed] base vide -> initialisation des données de démo…');
  require('./seed').run();
}

app.listen(PORT, () => {
  console.log(`\n  VYBZZZ backend en écoute sur http://localhost:${PORT}`);
  console.log(`  API base: http://localhost:${PORT}/api`);
  console.log(`  (pointe l'app dessus via APIs.mainIP)\n`);
});

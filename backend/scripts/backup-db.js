'use strict';

/**
 * Sauvegarde automatique de la base SQLite (better-sqlite3).
 *
 * Utilise l'API .backup() de SQLite : copie COHÉRENTE même si l'API écrit
 * pendant la sauvegarde (pas de fichier corrompu). Rotation : conserve les
 * VYBZZZ_BACKUP_KEEP dernières sauvegardes (14 par défaut) et supprime le reste.
 *
 * Lancement manuel :
 *   node scripts/backup-db.js
 *
 * Automatisation (cron sur le VPS) — tous les jours à 3h du matin :
 *   0 3 * * * cd /chemin/vers/backend && /usr/bin/node scripts/backup-db.js >> /var/log/vybzzz-backup.log 2>&1
 *
 * Variables d'environnement (optionnelles) :
 *   VYBZZZ_DB          chemin de la base (défaut : ../vybzzz.sqlite)
 *   VYBZZZ_BACKUP_DIR  dossier des sauvegardes (défaut : ../backups)
 *   VYBZZZ_BACKUP_KEEP nombre de sauvegardes à conserver (défaut : 14)
 */

const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = process.env.VYBZZZ_DB || path.join(__dirname, '..', 'vybzzz.sqlite');
const BACKUP_DIR = process.env.VYBZZZ_BACKUP_DIR || path.join(__dirname, '..', 'backups');
const KEEP = parseInt(process.env.VYBZZZ_BACKUP_KEEP || '14', 10);

if (!fs.existsSync(DB_PATH)) {
  console.error(`[backup] base introuvable : ${DB_PATH}`);
  process.exit(1);
}

fs.mkdirSync(BACKUP_DIR, { recursive: true });

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const dest = path.join(BACKUP_DIR, `vybzzz-${stamp}.sqlite`);

const db = new Database(DB_PATH, { readonly: true });

db.backup(dest)
  .then(() => {
    db.close();
    // Rotation : on ne garde que les KEEP plus récentes (tri par nom = par date).
    const files = fs
      .readdirSync(BACKUP_DIR)
      .filter((f) => f.startsWith('vybzzz-') && f.endsWith('.sqlite'))
      .sort();
    while (files.length > KEEP) {
      const old = files.shift();
      fs.unlinkSync(path.join(BACKUP_DIR, old));
      console.log(`[backup] ancienne sauvegarde supprimée : ${old}`);
    }
    const sizeMb = (fs.statSync(dest).size / (1024 * 1024)).toFixed(1);
    console.log(`[backup] OK -> ${dest} (${sizeMb} Mo, ${files.length} sauvegardes conservées)`);
  })
  .catch((e) => {
    console.error('[backup] échec :', e.message);
    try { db.close(); } catch (_) { /* ignore */ }
    process.exit(1);
  });

'use strict';

/**
 * Purge quotidienne des clips Firebase Storage expirés (fenêtre
 * CLIP_RETENTION_DAYS, 30j par défaut) — supprime le fichier du bucket
 * (arrête la facturation stockage) et vide les colonnes locales.
 */

const { db } = require('../db');
const firebase = require('../services/firebase');

async function purgeExpiredFirebaseClips() {
  const rows = db.prepare(
    `SELECT id, firebase_path FROM feed_clips
     WHERE firebase_path IS NOT NULL AND expires_at IS NOT NULL
       AND datetime(expires_at) < datetime('now')`
  ).all();
  for (const row of rows) {
    try {
      await firebase.deleteFile(row.firebase_path);
    } catch (e) {
      console.error(`[firebase cleanup] échec suppression clip #${row.id}:`, e.message);
      continue;
    }
    db.prepare(
      `UPDATE feed_clips SET firebase_path = NULL, video_url = NULL, active = 0, upload_status = 'expired'
       WHERE id = ?`
    ).run(row.id);
    console.log(`[firebase cleanup] clip #${row.id} supprimé (fenêtre ${process.env.CLIP_RETENTION_DAYS || 30}j écoulée).`);
  }
}

async function runCleanup() {
  if (!firebase.isConfigured()) return;
  try {
    await purgeExpiredFirebaseClips();
  } catch (e) {
    console.error('[firebase cleanup] erreur générale', e.message);
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;

function startFirebaseCleanupJob() {
  setTimeout(runCleanup, 90 * 1000);
  setInterval(runCleanup, DAY_MS);
}

module.exports = { startFirebaseCleanupJob, runCleanup };

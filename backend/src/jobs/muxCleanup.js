'use strict';

/**
 * Purge quotidienne des assets Mux expirés :
 *  - events.replay_expires_at dépassé  -> replay concert (fenêtre 60j, cf. Apple)
 *  - feed_clips.expires_at dépassé     -> clips du feed (fenêtre 30j par défaut)
 * On supprime l'asset côté Mux (arrête la facturation stockage/delivery) ET on
 * vide les colonnes locales pour que l'app arrête d'afficher un lecteur mort.
 */

const { db } = require('../db');
const mux = require('../services/mux');

async function purgeExpiredEvents() {
  const rows = db.prepare(
    `SELECT id, mux_asset_id FROM events
     WHERE mux_asset_id IS NOT NULL AND replay_expires_at IS NOT NULL
       AND datetime(replay_expires_at) < datetime('now')`
  ).all();
  for (const row of rows) {
    try {
      await mux.deleteAsset(row.mux_asset_id);
    } catch (e) {
      console.error(`[mux cleanup] échec suppression asset event #${row.id}:`, e.message);
      continue; // on retentera au prochain passage plutôt que de perdre la référence
    }
    db.prepare(
      `UPDATE events SET mux_asset_id = NULL, mux_playback_id = NULL, mux_live_playback_id = NULL,
          video_reel = NULL, mux_upload_status = 'expired'
       WHERE id = ?`
    ).run(row.id);
    console.log(`[mux cleanup] replay event #${row.id} supprimé (fenêtre ${process.env.REPLAY_RETENTION_DAYS || 60}j écoulée).`);
  }
}

async function purgeExpiredClips() {
  const rows = db.prepare(
    `SELECT id, mux_asset_id FROM feed_clips
     WHERE mux_asset_id IS NOT NULL AND expires_at IS NOT NULL
       AND datetime(expires_at) < datetime('now')`
  ).all();
  for (const row of rows) {
    try {
      await mux.deleteAsset(row.mux_asset_id);
    } catch (e) {
      console.error(`[mux cleanup] échec suppression asset clip #${row.id}:`, e.message);
      continue;
    }
    db.prepare(
      `UPDATE feed_clips SET mux_asset_id = NULL, mux_playback_id = NULL, active = 0, upload_status = 'expired'
       WHERE id = ?`
    ).run(row.id);
    console.log(`[mux cleanup] clip #${row.id} supprimé (fenêtre ${process.env.CLIP_RETENTION_DAYS || 30}j écoulée).`);
  }
}

async function runCleanup() {
  if (!mux.isConfigured()) return; // rien à purger côté Mux tant que les clés ne sont pas en place
  try {
    await purgeExpiredEvents();
    await purgeExpiredClips();
  } catch (e) {
    console.error('[mux cleanup] erreur générale', e.message);
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** À appeler une fois au démarrage du serveur. */
function startMuxCleanupJob() {
  // premier passage peu après le boot (laisse le serveur finir de démarrer),
  // puis une fois par jour.
  setTimeout(runCleanup, 60 * 1000);
  setInterval(runCleanup, DAY_MS);
}

module.exports = { startMuxCleanupJob, runCleanup };

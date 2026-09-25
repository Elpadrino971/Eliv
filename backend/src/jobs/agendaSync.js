'use strict';

/**
 * Collecte hebdomadaire de l'agenda régional (voir services/agenda_bizouk.js).
 *
 * Rythme : le week-end, comme demandé — les programmations de la semaine
 * suivante sont en place à ce moment-là, et la charge sur la source tombe un
 * jour creux. Le planificateur se réveille toutes les heures et déclenche la
 * synchronisation au premier passage du créneau choisi ; il ne la relance pas
 * si elle a déjà tourné dans les six jours.
 *
 * Le repère de dernier passage est en base (settings) et non en mémoire : un
 * redémarrage du conteneur ne doit pas provoquer une nouvelle collecte, ni en
 * sauter une.
 */

const { db } = require('../db');
const agenda = require('../services/agenda_bizouk');

const CLE = 'agenda_last_sync_at';
const HEURE_MS = 60 * 60 * 1000;
const SIX_JOURS_MS = 6 * 24 * HEURE_MS;

// 0 = dimanche … 6 = samedi. Samedi par défaut, 4 h du matin heure des Antilles
// (UTC-4), soit 8 h UTC : personne n'utilise l'application à ce moment-là.
const JOUR = Number(process.env.AGENDA_SYNC_DAY ?? 6);
const HEURE_UTC = Number(process.env.AGENDA_SYNC_HOUR_UTC ?? 8);

function dernierPassage() {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(CLE);
  const t = row?.value ? Date.parse(row.value) : NaN;
  return Number.isFinite(t) ? t : 0;
}

function noterPassage() {
  db.prepare(
    `INSERT INTO settings (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`
  ).run(CLE, new Date().toISOString());
}

async function runAgendaSync(opts = {}) {
  try {
    const stats = await agenda.sync(opts);
    noterPassage();
    return stats;
  } catch (e) {
    // Une source indisponible ne doit jamais faire tomber le serveur : on
    // réessaiera au prochain créneau, les données déjà collectées restent.
    console.error('[agenda] synchronisation échouée :', e.message);
    return null;
  }
}

function tick() {
  const now = new Date();
  if (now.getUTCDay() !== JOUR || now.getUTCHours() !== HEURE_UTC) return;
  if (Date.now() - dernierPassage() < SIX_JOURS_MS) return;
  console.log('[agenda] créneau hebdomadaire atteint, collecte en cours…');
  runAgendaSync();
}

/** À appeler une fois au démarrage du serveur. */
function startAgendaSyncJob() {
  if (process.env.AGENDA_SYNC_DISABLED === '1') {
    console.log('[agenda] collecte désactivée (AGENDA_SYNC_DISABLED=1).');
    return;
  }
  // Premier remplissage si la table est vide : sans lui, la timeline resterait
  // vide jusqu'au prochain week-end après une mise en service.
  setTimeout(() => {
    const vide = db.prepare('SELECT COUNT(*) c FROM external_events').get().c === 0;
    if (vide) {
      console.log('[agenda] agenda vide au démarrage, première collecte…');
      runAgendaSync();
    }
  }, 2 * 60 * 1000);

  setInterval(tick, HEURE_MS);
}

module.exports = { startAgendaSyncJob, runAgendaSync };

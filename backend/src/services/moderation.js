'use strict';

/**
 * Orchestration de la modération : fait le lien entre l'API Sightengine
 * (services/sightengine.js, pur) et le reste du backend (base + actions).
 *
 * Rôles :
 *  - journaliser chaque détection dans `moderation_flags` (revue / audit),
 *  - décider en synchrone pour le TEXTE (bloquer un commentaire avant insertion),
 *  - lancer en asynchrone la modération IMAGE (fire-and-forget) et VIDÉO/LIVE
 *    (Sightengine rappelle notre webhook /api/moderation/callback),
 *  - appliquer une ACTION sur blocage (masquer un replay, désactiver un clip…).
 *
 * Tout est "fail-open" : si Sightengine n'est pas configuré ou répond en erreur,
 * on LAISSE PASSER (et on log). La modération ne doit jamais casser l'app ; au
 * pire elle ne filtre pas, elle ne bloque jamais du contenu sain par accident.
 */

const { db } = require('../db');
const sightengine = require('./sightengine');
const { PUBLIC_BASE_URL } = require('../uploads');

const CALLBACK_TOKEN = process.env.SIGHTENGINE_CALLBACK_TOKEN || '';
// Couper automatiquement un live sur détection grave ? Désactivé par défaut :
// un faux positif ne doit pas tuer un concert légitime. À activer une fois les
// seuils calibrés (SIGHTENGINE_LIVE_AUTOSTOP=1).
const LIVE_AUTOSTOP = process.env.SIGHTENGINE_LIVE_AUTOSTOP === '1';

if (sightengine.isConfigured() && !CALLBACK_TOKEN) {
  console.warn(
    '[moderation] ⚠️  SIGHTENGINE_CALLBACK_TOKEN absent : le webhook de callback ' +
    'vidéo/live n\'est pas authentifié. Définis ce jeton pour sécuriser.'
  );
}

function isEnabled() { return sightengine.isConfigured(); }

// ─────────────────────────── Journalisation ───────────────────────────

function recordFlag({ surface, targetType, targetId, decision, extra }) {
  try {
    db.prepare(
      `INSERT INTO moderation_flags (surface, target_type, target_id, action, score, categories, extra, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'open')`
    ).run(
      surface,
      targetType,
      targetId != null ? String(targetId) : null,
      decision.action,
      decision.score ?? null,
      JSON.stringify(decision.categories || []),
      extra ? JSON.stringify(extra) : null,
    );
  } catch (e) {
    console.error('[moderation] recordFlag échec:', e.message);
  }
}

// ─────────────────────────── Texte (synchrone) ───────────────────────────

/**
 * Modère un texte. Renvoie toujours une décision { action, ... }. Ne throw
 * jamais : en cas d'erreur/timeout/non-configuré -> { action:'allow', skipped }.
 */
async function reviewText(text, { lang = 'fr', targetType = 'text', targetId = null } = {}) {
  if (!text || !String(text).trim() || !sightengine.isConfigured()) {
    return { action: 'allow', skipped: true };
  }
  try {
    const json = await sightengine.checkText(String(text), { lang });
    const decision = sightengine.decideText(json);
    if (decision.action !== 'allow') {
      recordFlag({ surface: 'text', targetType, targetId, decision, extra: { text: String(text).slice(0, 280) } });
    }
    return decision;
  } catch (e) {
    console.error('[moderation] reviewText échec (laisse passer):', e.message);
    return { action: 'allow', skipped: true, error: e.message };
  }
}

// ─────────────────────────── Image (asynchrone) ───────────────────────────

/**
 * Modère une image (URL publique) sans bloquer l'appelant : on répond tout de
 * suite à l'utilisateur, la vérification tourne en tâche de fond. Sur blocage,
 * `onBlock(decision)` est appelé (l'appelant décide quoi masquer/supprimer).
 */
function moderateImage({ url, targetType, targetId, onBlock }) {
  if (!url || !sightengine.isConfigured()) return;
  sightengine.checkImageUrl(url)
    .then((json) => {
      const decision = sightengine.decideImage(json);
      if (decision.action !== 'allow') {
        recordFlag({ surface: 'image', targetType, targetId, decision, extra: { url } });
      }
      if (decision.action === 'block' && typeof onBlock === 'function') {
        try { onBlock(decision); } catch (e) { console.error('[moderation] onBlock image:', e.message); }
      }
    })
    .catch((e) => console.error('[moderation] moderateImage échec:', e.message));
}

// ─────────────────────────── Vidéo / Live (callback) ───────────────────────────

function callbackUrl(targetType, targetId) {
  const base = PUBLIC_BASE_URL.replace(/\/+$/, '');
  const q = new URLSearchParams({ tt: targetType, tid: String(targetId ?? '') });
  if (CALLBACK_TOKEN) q.append('token', CALLBACK_TOKEN);
  return `${base}/api/moderation/callback?${q.toString()}`;
}

/** Lance la modération d'une vidéo enregistrée (replay concert / clip). */
function moderateVideo({ url, targetType, targetId }) {
  if (!url || !sightengine.isConfigured()) return;
  sightengine.checkVideoUrl(url, callbackUrl(targetType, targetId))
    .then((json) => console.log(`[moderation] vidéo soumise (${targetType}#${targetId}) req=${json.request?.id || '?'}`))
    .catch((e) => console.error('[moderation] moderateVideo échec:', e.message));
}

/** Démarre la surveillance d'un flux live (HLS Mux du concert en direct). */
function startLiveMonitor({ url, targetType = 'live', targetId }) {
  if (!url || !sightengine.isConfigured()) return;
  sightengine.checkLiveStream(url, callbackUrl(targetType, targetId))
    .then((json) => console.log(`[moderation] live surveillé (${targetType}#${targetId}) req=${json.request?.id || '?'}`))
    .catch((e) => console.error('[moderation] startLiveMonitor échec:', e.message));
}

function verifyCallbackToken(token) {
  if (!CALLBACK_TOKEN) return true; // pas de jeton configuré -> on accepte (avec warning au boot)
  return token === CALLBACK_TOKEN;
}

/**
 * Traite un callback Sightengine (vidéo enregistrée OU live). `query` porte le
 * type/id de la cible (tt/tid), `body` le résultat par frames.
 */
function handleCallback(query, body) {
  const targetType = query.tt || 'video';
  const targetId = query.tid || null;
  const decision = sightengine.decideVideoFrames(body || {});
  if (decision.action === 'allow') return { ok: true, action: 'allow' };

  recordFlag({ surface: (targetType === 'live' ? 'live' : 'video'), targetType, targetId, decision,
    extra: { framePosition: decision.framePosition, frameCount: decision.frameCount } });

  if (decision.action === 'block') applyBlockAction(targetType, targetId, decision);
  return { ok: true, action: decision.action };
}

/** Action concrète appliquée sur un contenu bloqué, selon son type. */
function applyBlockAction(targetType, targetId, decision) {
  if (!targetId) return;
  try {
    switch (targetType) {
      case 'event': // replay de concert : on masque le replay immédiatement
        db.prepare(
          "UPDATE events SET mux_upload_status = 'blocked', replay_expires_at = datetime('now') WHERE id = ?"
        ).run(targetId);
        break;
      case 'clip': // clip feed : on le retire de la diffusion
        db.prepare('UPDATE feed_clips SET active = 0 WHERE id = ?').run(targetId);
        break;
      case 'live': // concert EN DIRECT : coupe seulement si explicitement activé
        if (LIVE_AUTOSTOP) {
          db.prepare("UPDATE events SET status = 'completed' WHERE id = ? AND status = 'live'").run(targetId);
          console.warn(`[moderation] LIVE #${targetId} coupé automatiquement (score ${decision.score}).`);
        } else {
          console.warn(`[moderation] LIVE #${targetId} signalé (score ${decision.score}) — coupure manuelle requise (autostop off).`);
        }
        break;
      default:
        break;
    }
  } catch (e) {
    console.error('[moderation] applyBlockAction échec:', e.message);
  }
}

module.exports = {
  isEnabled,
  recordFlag,
  reviewText,
  moderateImage,
  moderateVideo,
  startLiveMonitor,
  verifyCallbackToken,
  handleCallback,
};

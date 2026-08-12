'use strict';

/**
 * Modération de contenu via Sightengine (image, vidéo, live, texte).
 * Appels REST directs (fetch natif Node 22, aucune dépendance ajoutée).
 * Les clés (SIGHTENGINE_API_USER / SIGHTENGINE_API_SECRET) restent côté serveur,
 * jamais exposées à l'app.
 *
 * PHILOSOPHIE (voir aussi services/moderation.js qui orchestre) :
 *  - Non configuré (clés absentes) -> no-op qui LAISSE PASSER (`skipped:true`).
 *    La modération ne doit jamais casser l'app tant qu'elle n'est pas branchée.
 *  - Strict sur l'illégal grave (mineurs + sexuel = tolérance zéro, seuil bas),
 *    souple sur le borderline (langage, alcool… -> revue plutôt que blocage).
 *  - Ce fichier ne fait QUE parler à l'API et décider (allow/review/block).
 *    Il ne touche pas la base : c'est moderation.js qui journalise et agit.
 */

const API = 'https://api.sightengine.com/1.0';
const API_USER = process.env.SIGHTENGINE_API_USER;
const API_SECRET = process.env.SIGHTENGINE_API_SECRET;

// Modèles surveillés (configurables par env pour "calibrer" sans redéployer).
// Défauts = l'illégal/grave. On n'active pas les 110+ classes, juste l'essentiel.
const IMAGE_MODELS = process.env.SIGHTENGINE_IMAGE_MODELS
  || 'nudity-2.1,weapon,recreational_drug,gore-2.0,violence,self-harm,offensive-2.0';
const VIDEO_MODELS = process.env.SIGHTENGINE_VIDEO_MODELS || IMAGE_MODELS;
// Texte : `ml` = classification par IA (toxicité, sexuel, haineux, violent,
// self-harm) ; `rules` = détection à base de règles (insultes, coordonnées,
// arnaques, liens). On peut passer l'un ou l'autre via env.
const TEXT_MODE = process.env.SIGHTENGINE_TEXT_MODE || 'ml';
const TEXT_MODELS = process.env.SIGHTENGINE_TEXT_MODELS || 'general';

// Seuils (0..1). >= block -> bloqué ; entre review et block -> revue humaine.
const T = {
  block: num(process.env.SIGHTENGINE_BLOCK_THRESHOLD, 0.6),
  review: num(process.env.SIGHTENGINE_REVIEW_THRESHOLD, 0.35),
  // Ligne rouge CSAM : mineur détecté + contenu sexuel = seuil très bas.
  minor: num(process.env.SIGHTENGINE_MINOR_THRESHOLD, 0.3),
};

function isConfigured() { return Boolean(API_USER && API_SECRET); }

function num(v, dflt = 0) {
  const n = typeof v === 'number' ? v : parseFloat(v);
  return Number.isFinite(n) ? n : dflt;
}
function maxOf(obj) {
  if (!obj || typeof obj !== 'object') return 0;
  let m = 0;
  for (const v of Object.values(obj)) { const n = num(v); if (n > m) m = n; }
  return m;
}

/**
 * POST form-urlencoded vers Sightengine, avec timeout (ne jamais bloquer une
 * requête utilisateur si l'API traîne) et détection des erreurs API.
 */
async function post(endpoint, params, { timeoutMs = 8000 } = {}) {
  if (!isConfigured()) {
    const err = new Error('Sightengine non configuré (SIGHTENGINE_API_USER/SECRET manquants).');
    err.code = 'SIGHTENGINE_NOT_CONFIGURED';
    throw err;
  }
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const body = new URLSearchParams(params);
    body.append('api_user', API_USER);
    body.append('api_secret', API_SECRET);
    const res = await fetch(`${API}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
      signal: ctrl.signal,
    });
    const text = await res.text();
    let json;
    try { json = text ? JSON.parse(text) : {}; } catch (_) { json = { raw: text }; }
    if (json.status === 'failure') {
      const err = new Error(`Sightengine ${endpoint}: ${json.error?.message || 'failure'}`);
      err.body = json;
      throw err;
    }
    return json;
  } finally {
    clearTimeout(timer);
  }
}

// ─────────────────────────── Décisions ───────────────────────────

/** Extrait un score "mineur détecté" de façon défensive (formats variables). */
function minorScore(json) {
  let m = num(json.minor?.prob);
  if (Array.isArray(json.faces)) {
    for (const f of json.faces) m = Math.max(m, num(f.attributes?.minor), num(f.minor));
  }
  return m;
}

/** Scores de risque d'une image (ou d'une frame vidéo) — lecture défensive. */
function imageRisks(json) {
  const n = json.nudity || {};
  const nuditySexual = Math.max(
    num(n.sexual_activity), num(n.sexual_display), num(n.erotica),
    num(n.very_suggestive) * 0.5, // suggestif = moins grave, on pondère
  );
  return {
    nudity_sexual: nuditySexual,
    gore: num(json.gore?.prob),
    violence: num(json.violence?.prob),
    weapon: Math.max(num(json.weapon?.prob), maxOf(json.weapon?.classes)),
    drug: num(json.recreational_drug?.prob),
    self_harm: num(json['self-harm']?.prob, num(json.self_harm?.prob)),
    offensive: Math.max(num(json.offensive?.prob), maxOf(json.offensive?.classes)),
  };
}

/** allow | review | block, à partir des scores image/frame. */
function decideImage(json) {
  const s = imageRisks(json);
  const minor = minorScore(json);
  const categories = [];
  let max = 0;
  for (const [k, v] of Object.entries(s)) {
    if (v > max) max = v;
    if (v >= T.review) categories.push({ name: k, score: round(v) });
  }
  // Ligne rouge : mineur + sexuel -> blocage immédiat (seuil très bas).
  if (minor >= T.minor && s.nudity_sexual >= T.minor) {
    return { action: 'block', hard: true, score: 1,
      categories: [{ name: 'minor_sexual', score: round(Math.min(minor, s.nudity_sexual)) }, ...categories] };
  }
  const action = max >= T.block ? 'block' : max >= T.review ? 'review' : 'allow';
  return { action, hard: false, score: round(max), categories };
}

/** allow | review | block, à partir d'une réponse texte (ml OU rules). */
function decideText(json) {
  const categories = [];
  let max = 0;
  // Mode ML : json.moderation_classes = { available:[...], sexual:0.x, ... }
  const mc = json.moderation_classes || {};
  for (const k of mc.available || []) {
    const v = num(mc[k]);
    if (v > max) max = v;
    if (v >= T.review) categories.push({ name: k, score: round(v) });
  }
  // Mode rules : chaque modèle renvoie un tableau `matches`. Les catégories
  // graves bloquent, les insultes/coordonnées passent en revue (souple).
  const HARD = new Set(['extremism', 'self-harm', 'weapon', 'drug', 'violence']);
  for (const model of ['profanity', 'personal', 'link', 'drug', 'weapon',
    'extremism', 'self-harm', 'violence', 'medical', 'money-transaction', 'spam', 'content-trade']) {
    const m = json[model];
    if (m && Array.isArray(m.matches) && m.matches.length) {
      const score = HARD.has(model) ? 1 : 0.5;
      if (score > max) max = score;
      categories.push({ name: model, score, matches: m.matches.length });
    }
  }
  const action = max >= T.block ? 'block' : max >= T.review ? 'review' : 'allow';
  return { action, hard: max >= 1, score: round(max), categories };
}

/** Agrège les frames d'un callback vidéo/live en une seule décision (pire cas). */
function decideVideoFrames(json) {
  const frames = json?.data?.frames || json?.frames || [];
  let worst = { action: 'allow', hard: false, score: 0, categories: [] };
  let worstPos = null;
  for (const fr of frames) {
    const d = decideImage(fr);
    if (rank(d.action) > rank(worst.action) || (rank(d.action) === rank(worst.action) && d.score > worst.score)) {
      worst = d;
      worstPos = fr.info?.position ?? fr.position ?? null;
    }
  }
  return { ...worst, framePosition: worstPos, frameCount: frames.length };
}

function rank(action) { return action === 'block' ? 2 : action === 'review' ? 1 : 0; }
function round(v) { return Math.round(num(v) * 1000) / 1000; }

// ─────────────────────────── Appels API ───────────────────────────

/** Image (URL publique) — synchrone, réponse immédiate. */
function checkImageUrl(url) {
  return post('/check.json', { url, models: IMAGE_MODELS });
}

/**
 * Vidéo enregistrée (URL HLS/MP4) — ASYNCHRONE : Sightengine échantillonne des
 * frames et POST le résultat sur `callbackUrl`. Renvoie l'id de requête.
 */
function checkVideoUrl(streamUrl, callbackUrl) {
  return post('/video/check.json', {
    stream_url: streamUrl,
    models: VIDEO_MODELS,
    callback_url: callbackUrl,
  });
}

/**
 * Live (URL HLS du flux en direct) — même endpoint asynchrone : Sightengine
 * surveille le flux en continu et envoie une alerte sur `callbackUrl` dès qu'il
 * détecte un problème, ce qui permet de couper en quelques secondes.
 */
function checkLiveStream(streamUrl, callbackUrl) {
  return post('/video/check.json', {
    stream_url: streamUrl,
    models: VIDEO_MODELS,
    callback_url: callbackUrl,
  });
}

module.exports = {
  isConfigured,
  thresholds: T,
  IMAGE_MODELS, VIDEO_MODELS, TEXT_MODE, TEXT_MODELS,
  checkImageUrl, checkVideoUrl, checkLiveStream,
  checkText,
  decideImage, decideText, decideVideoFrames,
};

/** Texte (chat, bio, titres…). `lang` = code langue ('fr','en',…). */
function checkText(text, { lang = 'fr' } = {}) {
  return post('/text/check.json', { text, lang, mode: TEXT_MODE, models: TEXT_MODELS });
}

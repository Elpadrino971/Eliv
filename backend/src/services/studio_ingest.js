'use strict';

/**
 * Studio web : l'artiste lance son concert depuis le navigateur (webcam + micro),
 * sans application.
 *
 *   navigateur --(WebSocket, morceaux MediaRecorder)--> ce serveur
 *     --(stdin)--> ffmpeg --(RTMP)--> Mux Live --(HLS)--> fans (app + site)
 *
 * L'évènement est créé en live_mode='pro' : tout le monde (app mobile via le
 * lecteur HLS « pro », site via /api/watch/stream) lit le HLS Mux. Rien à
 * changer côté app.
 *
 * Fonction désactivée tant que STUDIO_WEB != '1'. Aucune clé Mux (stream key)
 * ni jeton n'est jamais journalisé ni renvoyé au navigateur.
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { spawn, spawnSync } = require('child_process');
const { WebSocketServer } = require('ws');
const { db } = require('../db');
const mux = require('./mux');
const { SECRET } = require('../auth');
const { maskEmail } = require('../helpers');

// ─── Réglages ────────────────────────────────────────────────────────────
const WS_PATH = '/api/studio/ingest';
const FFMPEG_BIN = process.env.STUDIO_FFMPEG || 'ffmpeg';
const TOKEN_TTL_S = 30 * 60;                 // jeton d'ingest : 30 min
const TOKEN_PURPOSE = 'studio_ingest';
const MAX_LIVE_MS = 6 * 3600 * 1000;         // plafond dur : 6 h de direct
const PREPARED_TTL_MIN = 60;                 // session préparée mais jamais lancée : annulée après 60 min
const RECONNECT_GRACE_MS = 90 * 1000;        // sans retour du navigateur : concert terminé
const graceMs = () => Number(process.env.STUDIO_GRACE_MS) || RECONNECT_GRACE_MS; // surcharge : tests uniquement
const MAX_BACKLOG_BYTES = 6 * 1024 * 1024;   // retard toléré dans le pipe ffmpeg (~20 s à 2,5 Mb/s)
const IDLE_DATA_MS = 20 * 1000;              // aucun octet reçu pendant 20 s : connexion morte
const PING_MS = 15 * 1000;
const STATS_MS = 5 * 1000;
const MAX_MESSAGE_BYTES = 8 * 1024 * 1024;

const enabled = () => process.env.STUDIO_WEB === '1';
const rtmpBase = () => String(process.env.STUDIO_RTMP_BASE || mux.LIVE_INGEST_URL).replace(/\/+$/, '');
const siteUrl = () => String(process.env.SITE_URL || 'https://vybzzz.online').replace(/\/+$/, '');
function wsUrl() {
  if (process.env.STUDIO_WS_URL) return process.env.STUDIO_WS_URL;
  const pub = process.env.PUBLIC_BASE_URL;
  if (pub && /^https?:\/\//.test(pub)) return pub.replace(/^http/, 'ws').replace(/\/+$/, '') + WS_PATH;
  return `wss://api.vybzzz.online${WS_PATH}`;
}

// ffmpeg présent ? Vérifié une fois au chargement (démarrage du serveur).
let ffmpegOk = false;
function checkFfmpeg() {
  try {
    const r = spawnSync(FFMPEG_BIN, ['-version'], { timeout: 5000, stdio: 'ignore' });
    ffmpegOk = r.status === 0;
  } catch (_) { ffmpegOk = false; }
  return ffmpegOk;
}
checkFfmpeg();
const hasFfmpeg = () => ffmpegOk;

// ─── Schéma : repère les évènements créés par le studio web ─────────────────
let schemaReady = false;
function ensureSchema() {
  if (schemaReady) return;
  try { db.exec('ALTER TABLE events ADD COLUMN studio_web INTEGER DEFAULT 0'); } catch (_) { /* déjà présente */ }
  schemaReady = true;
}
ensureSchema();

// ─── Jetons d'ingest ──────────────────────────────────────────────────────
function signIngestToken(eventId, userId) {
  return jwt.sign(
    { purpose: TOKEN_PURPOSE, event_id: Number(eventId), user_id: Number(userId) },
    SECRET,
    { expiresIn: TOKEN_TTL_S, algorithm: 'HS256' }
  );
}
function verifyIngestToken(token) {
  try {
    const p = jwt.verify(String(token || ''), SECRET, { algorithms: ['HS256'] });
    if (p.purpose !== TOKEN_PURPOSE || !p.event_id || !p.user_id) return null;
    return { eventId: Number(p.event_id), userId: Number(p.user_id) };
  } catch (_) { return null; }
}
function ingestInfo(eventId, userId) {
  return { ws_url: wsUrl(), token: signIngestToken(eventId, userId) };
}
function urlsFor(eventId) {
  return {
    watch_url: `${siteUrl()}/live.html?e=${eventId}`,
    web_url: `${siteUrl()}/web/#/event/${eventId}`,
  };
}

// ─── État en mémoire ────────────────────────────────────────────────────────
const sessions = new Map();   // eventId -> session (connexion d'ingest active)
const graces = new Map();     // eventId -> timer (attente d'un retour du navigateur)
let wss = null;

const log = (...a) => console.log('[studio]', ...a);
const warn = (...a) => console.warn('[studio]', ...a);

function userTag(userId) {
  try {
    const u = db.prepare('SELECT email FROM users WHERE id = ?').get(userId);
    return `user#${userId} (${maskEmail(u && u.email)})`;
  } catch (_) { return `user#${userId}`; }
}

function send(ws, obj) {
  try { if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj)); } catch (_) { /* socket fermé */ }
}

// ─── Sessions en base ───────────────────────────────────────────────────────
function getEvent(id) { return db.prepare('SELECT * FROM events WHERE id = ?').get(id); }

/** Session studio active (préparée ou en direct) de cet artiste, ou undefined. */
function activeSessionOf(userId) {
  reapStalePrepared();
  return db.prepare(
    `SELECT * FROM events WHERE artist_id = ? AND studio_web = 1 AND status IN ('published','live')
     ORDER BY id DESC LIMIT 1`
  ).get(userId);
}

/** Sessions préparées jamais lancées depuis > 60 min : annulées (flux Mux supprimé). */
function reapStalePrepared() {
  const rows = db.prepare(
    `SELECT id, mux_live_stream_id FROM events
     WHERE studio_web = 1 AND status = 'published'
       AND created_at < datetime('now', ?)`
  ).all(`-${PREPARED_TTL_MIN} minutes`);
  for (const r of rows) {
    if (sessions.has(r.id)) continue; // un navigateur est connecté : on attend
    endEvent(r.id, 'préparation expirée');
  }
}

/**
 * Termine un évènement du studio : coupe ffmpeg/WebSocket, passe l'event en
 * « completed » (même effet que recording/stop de l'app) ou « cancelled » s'il
 * n'a jamais été en direct, et signale la fin à Mux. Idempotent.
 */
function endEvent(eventId, why) {
  clearGrace(eventId);
  const s = sessions.get(eventId);
  if (s) closeSession(s, { notify: { type: 'ended' }, code: 1000, reason: 'ended', grace: false });

  const ev = getEvent(eventId);
  if (!ev || Number(ev.studio_web) !== 1) return null;
  const wasLive = ev.status === 'live';
  if (wasLive) {
    db.prepare("UPDATE events SET status = 'completed', end_date_time = ? WHERE id = ? AND status = 'live'")
      .run(new Date().toISOString(), eventId);
  } else if (ev.status === 'published') {
    db.prepare("UPDATE events SET status = 'cancelled' WHERE id = ? AND status = 'published'").run(eventId);
  }
  if (ev.mux_live_stream_id && mux.isConfigured()) {
    if (wasLive) {
      // Mux finalise tout de suite le replay ; 400 si déjà idle -> ignoré.
      Promise.resolve().then(() => mux.completeLiveStream(ev.mux_live_stream_id))
        .catch((e) => warn(`event #${eventId} : complete Mux ignoré (${String(e.message).slice(0, 120)})`));
    } else if (ev.status === 'published') {
      Promise.resolve().then(() => mux.deleteLiveStream(ev.mux_live_stream_id))
        .catch((e) => warn(`event #${eventId} : suppression flux Mux ignorée (${String(e.message).slice(0, 120)})`));
      db.prepare('UPDATE events SET mux_live_stream_id = NULL, mux_stream_key = NULL, mux_live_playback_id = NULL WHERE id = ?')
        .run(eventId);
    }
  }
  log(`event #${eventId} terminé (${why}) ${wasLive ? 'completed' : 'cancelled'}`);
  return { wasLive };
}

function clearGrace(eventId) {
  const t = graces.get(eventId);
  if (t) { clearTimeout(t); graces.delete(eventId); }
}
function startGrace(eventId, ms = graceMs()) {
  clearGrace(eventId);
  const t = setTimeout(() => {
    graces.delete(eventId);
    if (sessions.has(eventId)) return;
    endEvent(eventId, 'pas de reconnexion');
  }, ms);
  if (t.unref) t.unref();
  graces.set(eventId, t);
}

// ─── ffmpeg ─────────────────────────────────────────────────────────────────
const isH264 = (mime) => /h\.?264|avc1/i.test(mime || '');
function containerFromMime(mime) {
  const m = String(mime || '').toLowerCase();
  if (m.includes('webm') || m.includes('matroska')) return 'matroska';
  if (m.includes('mp4')) return 'mp4';
  return null;
}
function containerFromMagic(buf) {
  if (buf.length >= 4 && buf[0] === 0x1a && buf[1] === 0x45 && buf[2] === 0xdf && buf[3] === 0xa3) return 'matroska';
  if (buf.length >= 8 && buf.toString('latin1', 4, 8) === 'ftyp') return 'mp4';
  return null;
}

/** Arguments ffmpeg (exporté pour les tests). `fmt` explicite : jamais de détection auto (anti-SSRF/concat). */
function buildFfmpegArgs({ fmt, copyVideo, outUrl }) {
  const args = [
    '-hide_banner', '-loglevel', 'warning', '-nostats', '-progress', 'pipe:1',
    '-fflags', '+genpts+nobuffer', '-flags', 'low_delay',
    '-probesize', '1000000', '-analyzeduration', '1000000',
    '-protocol_whitelist', 'pipe',
    '-f', fmt, '-i', 'pipe:0',
    '-map', '0:v:0', '-map', '0:a:0?',
  ];
  if (copyVideo) {
    args.push('-c:v', 'copy');
  } else {
    args.push(
      '-c:v', 'libx264', '-preset', 'veryfast', '-tune', 'zerolatency',
      '-g', '60', '-force_key_frames', 'expr:gte(t,n_forced*2)',
      '-b:v', '2500k', '-maxrate', '2800k', '-bufsize', '5000k',
      '-pix_fmt', 'yuv420p',
      '-vf', 'scale=-2:min(720\\,ih)'
    );
  }
  args.push('-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2');
  args.push('-max_muxing_queue_size', '1024', '-f', 'flv', '-flvflags', 'no_duration_filesize', outUrl);
  return args;
}

// ─── Cycle de vie d'une connexion ────────────────────────────────────────
function killFfmpeg(s) {
  const ff = s.ff;
  if (!ff) return;
  s.ff = null;
  try { ff.stdin.destroy(); } catch (_) { /* déjà fermé */ }
  try { ff.kill('SIGTERM'); } catch (_) { /* déjà mort */ }
  const t = setTimeout(() => { try { ff.kill('SIGKILL'); } catch (_) { /* mort */ } }, 3000);
  if (t.unref) t.unref();
  ff.once('exit', () => clearTimeout(t));
}

/** Ferme proprement une connexion : minuteries, ffmpeg, WebSocket. */
function closeSession(s, { notify, code = 1000, reason = '', grace = true } = {}) {
  if (s.closed) return;
  s.closed = true;
  const wasCurrent = sessions.get(s.eventId) === s;
  for (const t of [s.pingTimer, s.statsTimer, s.maxTimer]) if (t) { clearInterval(t); clearTimeout(t); }
  killFfmpeg(s);
  if (sessions.get(s.eventId) === s) sessions.delete(s.eventId);
  if (notify) send(s.ws, notify);
  try { s.ws.close(code, String(reason).slice(0, 100)); } catch (_) { /* déjà fermé */ }
  setTimeout(() => { try { s.ws.terminate(); } catch (_) { /* fermé */ } }, 2000).unref();
  // Coupure subie (réseau, ffmpeg, silence) pendant un direct : le navigateur a
  // 90 s pour revenir (Mux garde le flux 60 s), sinon le concert est terminé.
  if (grace && wasCurrent) {
    const cur = getEvent(s.eventId);
    if (cur && cur.status === 'live') {
      log(`event #${s.eventId} : flux coupé, attente ${graceMs() / 1000} s d'une reconnexion`);
      startGrace(s.eventId);
    }
  }
}

function startFfmpeg(s, fmt) {
  const ev = getEvent(s.eventId);
  const outUrl = `${rtmpBase()}/${ev.mux_stream_key}`;
  const key = ev.mux_stream_key;
  const redact = (txt) => String(txt).split(key).join('***');
  const copyVideo = isH264(s.mime);
  s.fmt = fmt;
  s.copyVideo = copyVideo;
  const args = buildFfmpegArgs({ fmt, copyVideo, outUrl });
  const ff = spawn(FFMPEG_BIN, args, { stdio: ['pipe', 'pipe', 'pipe'] });
  s.ff = ff;
  s.ffPid = ff.pid;
  s.stderrTail = '';
  ff.stdin.on('error', () => { /* EPIPE : ffmpeg est mort, géré par 'exit' */ });
  ff.stderr.on('data', (d) => { s.stderrTail = (s.stderrTail + redact(d)).slice(-1500); });

  let buf = '';
  ff.stdout.on('data', (d) => {
    buf += d.toString('utf8');
    let i;
    while ((i = buf.indexOf('progress=')) !== -1) {
      const end = buf.indexOf('\n', i);
      if (end === -1) break;
      const block = buf.slice(0, end + 1);
      buf = buf.slice(end + 1);
      const m = /total_size=(\d+)/.exec(block);
      if (m && Number(m[1]) > 0) onFirstOutput(s);
    }
    if (buf.length > 10000) buf = buf.slice(-2000);
  });

  ff.on('error', (e) => {
    warn(`event #${s.eventId} : ffmpeg impossible à lancer (${e.code || e.message})`);
    if (!s.closed) closeSession(s, { notify: { type: 'error', message: "Le moteur de diffusion n'est pas disponible. Réessaie plus tard." }, code: 1011, reason: 'ffmpeg' });
  });
  ff.on('exit', (code, signal) => {
    if (s.ff !== ff) return; // arrêt voulu (killFfmpeg a vidé s.ff)
    s.ff = null;
    if (s.closed) return;
    warn(`event #${s.eventId} : ffmpeg terminé code=${code} signal=${signal}${s.stderrTail ? ' | ' + s.stderrTail.replace(/\s+/g, ' ').slice(-300) : ''}`);
    const msg = s.liveSent
      ? 'Le flux vidéo a été interrompu. Reconnecte-toi pour reprendre le direct.'
      : 'Impossible de joindre le serveur de diffusion. Réessaie dans un instant.';
    closeSession(s, { notify: { type: 'error', message: msg }, code: 1011, reason: 'ffmpeg exit' });
  });
  log(`event #${s.eventId} ${userTag(s.userId)} : ffmpeg lancé (${fmt}, vidéo ${copyVideo ? 'copy' : 'transcodée'})`);
  send(s.ws, { type: 'ready' });
}

function onFirstOutput(s) {
  if (s.liveSent || s.closed) return;
  s.liveSent = true;
  s.liveAt = Date.now();
  const nowIso = new Date().toISOString();
  db.prepare("UPDATE events SET status = 'live' WHERE id = ? AND status = 'published'").run(s.eventId);
  // Plafond dur : 6 h à partir du premier direct.
  const ev = getEvent(s.eventId);
  if (ev && !s.resumed) {
    db.prepare('UPDATE events SET end_date_time = ? WHERE id = ?').run(new Date(Date.now() + MAX_LIVE_MS).toISOString(), s.eventId);
  }
  log(`event #${s.eventId} en direct (${nowIso})`);
  send(s.ws, { type: 'live' });
}

function onConnection(ws, ctx) {
  const { eventId, userId, mime, ev } = ctx;

  const prev = sessions.get(eventId);
  if (prev) {
    // Doublon (ex. ancien onglet, connexion à moitié morte) : le nouveau gagne.
    log(`event #${eventId} : connexion précédente remplacée`);
    closeSession(prev, { notify: { type: 'error', message: 'Remplacé par une autre connexion.' }, code: 4000, reason: 'replaced', grace: false });
  }
  for (const other of sessions.values()) {
    if (other.userId === userId && other.eventId !== eventId) {
      send(ws, { type: 'error', message: 'Un autre direct est déjà en cours sur ton compte.' });
      ws.close(4409, 'one ingest per artist');
      return;
    }
  }

  clearGrace(eventId);
  const s = {
    eventId, userId, mime, ws,
    ff: null, closed: false, liveSent: false,
    resumed: ev.status === 'live',
    bytesIn: 0, lastStatBytes: 0, lastStatAt: Date.now(), lastDataAt: Date.now(),
    chunks: 0, alive: true,
  };
  sessions.set(eventId, s);

  // Durée max : 6 h après le premier direct (end_date_time), sinon 6 h.
  let remaining = MAX_LIVE_MS;
  if (ev.status === 'live' && ev.end_date_time) {
    const t = new Date(ev.end_date_time).getTime() - Date.now();
    if (Number.isFinite(t)) remaining = Math.min(MAX_LIVE_MS, t);
  }
  if (remaining <= 0) {
    sessions.delete(eventId);
    send(ws, { type: 'error', message: 'Durée maximale de 6 h atteinte.' });
    ws.close(4410, 'max duration');
    endEvent(eventId, 'durée max');
    return;
  }
  s.maxTimer = setTimeout(() => {
    log(`event #${eventId} : durée max atteinte`);
    endEvent(eventId, 'durée max 6 h');
  }, remaining);
  s.maxTimer.unref();

  s.pingTimer = setInterval(() => {
    if (!s.alive) { warn(`event #${eventId} : navigateur muet (pong), coupure`); return closeSession(s, { code: 1001, reason: 'timeout' }); }
    s.alive = false;
    try { ws.ping(); } catch (_) { /* fermé */ }
    if (Date.now() - s.lastDataAt > IDLE_DATA_MS) {
      warn(`event #${eventId} : aucune donnée depuis ${IDLE_DATA_MS / 1000} s, coupure`);
      closeSession(s, { notify: { type: 'error', message: 'Plus aucune image reçue. Reconnecte-toi.' }, code: 4408, reason: 'idle' });
    }
  }, PING_MS);
  s.statsTimer = setInterval(() => {
    const now = Date.now();
    const dt = (now - s.lastStatAt) / 1000;
    const kbps = dt > 0 ? Math.round(((s.bytesIn - s.lastStatBytes) * 8) / 1000 / dt) : 0;
    s.lastStatBytes = s.bytesIn; s.lastStatAt = now;
    send(ws, { type: 'stats', bitrate_kbps: kbps, seconds: Math.round((now - (s.liveAt || s.startedAt || now)) / 1000) });
  }, STATS_MS);
  s.startedAt = Date.now();

  ws.on('pong', () => { s.alive = true; });
  ws.on('message', (data, isBinary) => {
    if (s.closed) return;
    s.alive = true;
    if (!isBinary) return; // les messages texte du client sont ignorés (ping applicatif éventuel)
    const chunk = Buffer.isBuffer(data) ? data : Buffer.concat(Array.isArray(data) ? data : [Buffer.from(data)]);
    s.lastDataAt = Date.now();
    if (s.chunks === 0) {
      const magic = containerFromMagic(chunk);
      const declared = containerFromMime(s.mime);
      if (!magic || (declared && declared !== magic)) {
        return closeSession(s, { notify: { type: 'error', message: 'Format vidéo non reconnu.' }, code: 4415, reason: 'format' });
      }
      if (!s.ff) startFfmpeg(s, magic); // mime inconnu : on démarre au premier morceau
    }
    s.chunks += 1;
    s.bytesIn += chunk.length;
    if (!s.ff) return;
    if (s.ff.stdin.writableLength > MAX_BACKLOG_BYTES) {
      warn(`event #${eventId} : ffmpeg trop lent (${Math.round(s.ff.stdin.writableLength / 1024)} Ko en attente), coupure`);
      return closeSession(s, { notify: { type: 'error', message: 'Connexion ou serveur trop lent : le flux a été coupé. Réessaie avec une qualité plus basse.' }, code: 4413, reason: 'backpressure' });
    }
    s.ff.stdin.write(chunk);
  });
  ws.on('close', () => closeSession(s));
  ws.on('error', (e) => warn(`event #${eventId} : erreur WebSocket (${e.message})`));

  log(`event #${eventId} ${userTag(userId)} : navigateur connecté (mime=${String(mime).slice(0, 60) || '?'})`);
  const fmt = containerFromMime(mime);
  if (fmt) startFfmpeg(s, fmt);
}

// ─── Mise à niveau HTTP -> WebSocket ───────────────────────────────────────
function refuseWs(ws, code, message) {
  send(ws, { type: 'error', message });
  try { ws.close(code, 'refused'); } catch (_) { /* fermé */ }
}

function handleUpgrade(req, socket, head) {
  let url;
  try { url = new URL(req.url, 'http://localhost'); } catch (_) { return socket.destroy(); }
  if (url.pathname !== WS_PATH) return socket.destroy();
  if (!enabled()) {
    socket.write('HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
    return socket.destroy();
  }
  if (!wss) wss = new WebSocketServer({ noServer: true, maxPayload: MAX_MESSAGE_BYTES, perMessageDeflate: false });
  socket.on('error', () => { /* client parti pendant la mise à niveau */ });

  const mime = (url.searchParams.get('mime') || '').slice(0, 200);
  const claims = verifyIngestToken(url.searchParams.get('t'));
  wss.handleUpgrade(req, socket, head, (ws) => {
    // Les refus sont envoyés APRÈS la mise à niveau (message JSON + code de
    // fermeture 44xx) : le navigateur ne voit pas le statut HTTP d'une
    // connexion WebSocket refusée, il verrait seulement « 1006 ».
    if (!claims) return refuseWs(ws, 4401, 'Jeton invalide ou expiré. Relance le live.');
    if (!hasFfmpeg()) return refuseWs(ws, 4503, "Le moteur de diffusion n'est pas disponible sur ce serveur.");
    const ev = getEvent(claims.eventId);
    if (!ev || Number(ev.studio_web) !== 1 || Number(ev.artist_id) !== claims.userId) {
      return refuseWs(ws, 4404, 'Live introuvable.');
    }
    const user = db.prepare('SELECT id, status FROM users WHERE id = ?').get(claims.userId);
    if (!user || (user.status && user.status !== 'active')) return refuseWs(ws, 4403, 'Compte indisponible.');
    if (!['published', 'live'].includes(ev.status) || !ev.mux_stream_key) {
      return refuseWs(ws, 4409, 'Ce live est terminé. Crée-en un nouveau.');
    }
    if (!mux.isConfigured() && !process.env.STUDIO_RTMP_BASE) {
      return refuseWs(ws, 4503, 'Diffusion indisponible pour le moment.');
    }
    onConnection(ws, { eventId: ev.id, userId: claims.userId, mime, ev });
  });
}

// ─── Démarrage / arrêt du serveur ─────────────────────────────────────────
let sweeper = null;
function init() {
  if (!enabled()) return;
  log(`activé (ffmpeg ${ffmpegOk ? 'présent' : 'ABSENT'}, sortie RTMP ${rtmpBase().replace(/\/\/[^/]*@/, '//***@')})`);
  // Directs laissés « live » par un redémarrage du serveur : le navigateur a 90 s pour revenir.
  const orphans = db.prepare("SELECT id FROM events WHERE studio_web = 1 AND status = 'live'").all();
  for (const o of orphans) startGrace(o.id);
  reapStalePrepared();
  sweeper = setInterval(() => { try { reapStalePrepared(); } catch (e) { warn(`balayage : ${e.message}`); } }, 60 * 1000);
  sweeper.unref();
}

/** Coupe tout (arrêt propre du process / tests). Ne touche pas aux évènements. */
function shutdown() {
  if (sweeper) { clearInterval(sweeper); sweeper = null; }
  for (const t of graces.values()) clearTimeout(t);
  graces.clear();
  for (const s of [...sessions.values()]) closeSession(s, { code: 1001, reason: 'server shutdown', grace: false });
}

module.exports = {
  WS_PATH, TOKEN_TTL_S, RECONNECT_GRACE_MS,
  enabled, hasFfmpeg, checkFfmpeg, rtmpBase,
  signIngestToken, verifyIngestToken, ingestInfo, urlsFor,
  activeSessionOf, endEvent, getEvent,
  handleUpgrade, init, shutdown,
  buildFfmpegArgs, containerFromMime, containerFromMagic, isH264,
  _sessions: sessions,
};

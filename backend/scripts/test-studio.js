'use strict';

/**
 * Test de bout en bout du studio web, SANS Mux réel.
 *
 *   node scripts/test-studio.js
 *
 * - Mux est remplacé par un faux (createLiveStream / completeLiveStream /
 *   deleteLiveStream) et les variables MUX_* sont retirées de l'environnement :
 *   un appel non remplacé échouerait au lieu de toucher le compte de production.
 * - La sortie RTMP de ffmpeg pointe sur un récepteur local (ffmpeg -listen),
 *   via STUDIO_RTMP_BASE.
 * - Base jetable : VYBZZZ_DB (défaut : dossier temporaire du système).
 * Prérequis : ffmpeg + ffprobe dans le PATH.
 */

const os = require('os');
const fs = require('fs');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const TMP = fs.mkdtempSync(path.join(process.env.TEST_TMP || os.tmpdir(), 'studio-test-'));
const PORT = Number(process.env.PORT || 8127);
const RTMP_PORT = 19350;
process.env.VYBZZZ_DB = process.env.VYBZZZ_DB || path.join(TMP, 'studio.sqlite');
process.env.PORT = String(PORT);
process.env.JWT_SECRET = 'test-secret-test-secret-test-secret-123456';
process.env.STUDIO_WEB = '1';
process.env.STUDIO_RTMP_BASE = `rtmp://127.0.0.1:${RTMP_PORT}/live`;
process.env.STUDIO_WS_URL = `ws://127.0.0.1:${PORT}/api/studio/ingest`;
process.env.STUDIO_GRACE_MS = '6000';
process.env.SITE_URL = 'https://vybzzz.online';
for (const k of Object.keys(process.env)) if (k.startsWith('MUX_')) delete process.env[k];
delete process.env.SIGHTENGINE_API_USER;
delete process.env.NODE_ENV;
try { fs.unlinkSync(process.env.VYBZZZ_DB); } catch (_) { /* absent */ }

// ─── Faux Mux ─────────────────────────────────────────────────────────────
const mux = require('../src/services/mux');
let streamSeq = 0;
const muxCalls = { create: [], complete: [], del: [] };
mux.isConfigured = () => true;
mux.createLiveStream = async (opts) => {
  streamSeq += 1;
  muxCalls.create.push(opts);
  return { liveStreamId: `ls_fake_${streamSeq}`, streamKey: `sk_test_${streamSeq}_secret`, playbackId: `pb_fake_${streamSeq}`, ingestUrl: 'x' };
};
mux.completeLiveStream = async (id) => { muxCalls.complete.push(id); return {}; };
mux.deleteLiveStream = async (id) => { muxCalls.del.push(id); return {}; };

// Capture des journaux : on vérifie plus bas qu'aucune clé/jeton n'y figure.
const logs = [];
for (const m of ['log', 'warn', 'error']) {
  const orig = console[m].bind(console);
  console[m] = (...a) => { logs.push(a.map(String).join(' ')); if (process.env.VERBOSE) orig(...a); };
}

const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const { SECRET } = require('../src/auth');
const { db } = require('../src/db');
require('../src/server');
const studio = require('../src/services/studio_ingest');

// ─── Petit harnais ───────────────────────────────────────────────────────
let pass = 0; let failN = 0;
const out = (s) => process.stdout.write(s + '\n');
function check(name, cond, extra) {
  if (cond) { pass += 1; out(`  ok   ${name}${extra ? '  [' + extra + ']' : ''}`); }
  else { failN += 1; out(`  FAIL ${name}${extra ? '  [' + extra + ']' : ''}`); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const BASE = `http://127.0.0.1:${PORT}/api`;
async function api(method, p, { token, body } = {}) {
  const res = await fetch(BASE + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch (_) { /* vide */ }
  return { status: res.status, json };
}
async function login(email, password = 'password') {
  const r = await api('POST', '/login', { body: { email, password } });
  const t = (r.json && (r.json.token || (r.json.data && r.json.data.token))) || null;
  if (!t) throw new Error(`login ${email} : ${r.status} ${JSON.stringify(r.json).slice(0, 200)}`);
  return t;
}

// ─── Récepteur RTMP local (remplace Mux) ─────────────────────────────────
function startSink(key) {
  const sink = { files: [], stopped: false, firstFrameAt: [], procs: new Set() };
  const spawnOne = () => {
    if (sink.stopped) return;
    const file = path.join(TMP, `${key}_${sink.files.length}.flv`);
    sink.files.push(file);
    const p = spawn('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-nostats',
      '-listen', '1', '-i', `rtmp://127.0.0.1:${RTMP_PORT}/live/${key}`, '-c', 'copy', '-flush_packets', '1', '-f', 'flv', file]);
    sink.procs.add(p);
    // 1re image reçue : le fichier du récepteur dépasse 3 Ko (en-têtes FLV passés
    // = au moins une image clé vidéo écrite). Sondé toutes les 15 ms.
    let got = false;
    const poll = setInterval(() => {
      try {
        if (!got && fs.statSync(file).size >= 3000) { got = true; sink.firstFrameAt.push(Date.now()); clearInterval(poll); }
      } catch (_) { /* fichier pas encore créé */ }
    }, 15);
    p.on('exit', () => clearInterval(poll));
    p.stderr.on('data', () => {});
    p.on('exit', () => { sink.procs.delete(p); if (!sink.stopped) setTimeout(spawnOne, 100); });
  };
  spawnOne();
  sink.stop = () => { sink.stopped = true; for (const p of sink.procs) p.kill('SIGINT'); };
  return sink;
}
function probe(file) {
  const r = spawnSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=codec_type,codec_name,width,height:format=duration', '-of', 'json', file], { encoding: 'utf8' });
  try {
    const j = JSON.parse(r.stdout);
    return {
      video: (j.streams || []).find((s) => s.codec_type === 'video'),
      audio: (j.streams || []).find((s) => s.codec_type === 'audio'),
      duration: Number((j.format || {}).duration) || 0,
    };
  } catch (_) { return { duration: 0 }; }
}

// ─── Générateurs de flux navigateur (ce que produit MediaRecorder) ───────────
const SRC = ['-re', '-f', 'lavfi', '-i', `testsrc=size=${process.env.TEST_SIZE || '640x360'}:rate=${process.env.TEST_FPS || 25}`, '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000'];
const VARIANTS = {
  vp8: { mime: 'video/webm;codecs=vp8,opus', args: ['-c:v', 'libvpx', '-deadline', 'realtime', '-cpu-used', '8', '-b:v', '1M', '-g', '25', '-c:a', 'libopus', '-b:a', '64k', '-f', 'webm', '-cluster_time_limit', '1000'] },
  h264webm: { mime: 'video/webm;codecs=h264,opus', args: ['-c:v', 'libx264', '-preset', 'ultrafast', '-tune', 'zerolatency', '-g', '25', '-pix_fmt', 'yuv420p', '-c:a', 'libopus', '-b:a', '64k', '-f', 'matroska', '-cluster_time_limit', '1000'] },
  mp4: { mime: 'video/mp4;codecs=avc1.42E01E,mp4a.40.2', args: ['-c:v', 'libx264', '-preset', 'ultrafast', '-tune', 'zerolatency', '-g', '25', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k', '-movflags', 'frag_keyframe+empty_moov+default_base_moof', '-f', 'mp4'] },
};
function startGen(variant, ws) {
  const g = spawn('ffmpeg', ['-hide_banner', '-loglevel', 'error', ...SRC, ...VARIANTS[variant].args, '-flush_packets', '1', 'pipe:1']);
  const gen = { firstChunkAt: 0, bytes: 0 };
  g.stdout.on('data', (d) => {
    if (ws.readyState !== 1) return;
    if (!gen.firstChunkAt) gen.firstChunkAt = Date.now();
    gen.bytes += d.length;
    ws.send(d, { binary: true });
  });
  g.stderr.on('data', () => {});
  gen.stop = () => { try { g.kill('SIGKILL'); } catch (_) { /* mort */ } };
  return gen;
}

// ─── Client WebSocket ──────────────────────────────────────────────────────
function connect(token, mime) {
  const url = `${process.env.STUDIO_WS_URL}?t=${encodeURIComponent(token)}&mime=${encodeURIComponent(mime || '')}`;
  const ws = new WebSocket(url);
  const c = { ws, msgs: [], closeCode: null, opened: false, t0: Date.now() };
  ws.on('open', () => { c.opened = true; });
  ws.on('message', (d, isBin) => { if (!isBin) { try { c.msgs.push({ ...JSON.parse(d.toString()), at: Date.now() }); } catch (_) { /* ignoré */ } } });
  ws.on('close', (code) => { c.closeCode = code; });
  ws.on('error', () => {});
  c.waitFor = async (type, ms = 15000) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      const m = c.msgs.find((x) => x.type === type);
      if (m) return m;
      if (c.closeCode !== null && !c.msgs.some((x) => x.type === type)) await sleep(50);
      await sleep(30);
    }
    return null;
  };
  c.waitClose = async (ms = 8000) => { const end = Date.now() + ms; while (c.closeCode === null && Date.now() < end) await sleep(30); return c.closeCode; };
  return c;
}
function cpuSeconds(pid) {
  try {
    const f = fs.readFileSync(`/proc/${pid}/stat`, 'utf8').split(') ')[1].split(' ');
    return (Number(f[11]) + Number(f[12])) / 100; // utime + stime (ticks de 100 Hz)
  } catch (_) { return null; }
}

// ─── Scénarios ────────────────────────────────────────────────────────────
async function createLive(token, body) {
  return api('POST', '/studio/live', { token, body: body || { title: 'Concert test', price: 0 } });
}

async function runVariant(title, variant, artistEmail, seconds, expectCopy) {
  out(`\n== ${title} (${variant}) ==`);
  const tok = await login(artistEmail);
  const r = await createLive(tok, { title: `Live ${variant}`, price: 0, replay: true });
  check('POST /live -> 200', r.status === 200 && r.json.status === 'success', `status ${r.status}`);
  const d = r.json.data;
  const evRow = db.prepare('SELECT * FROM events WHERE id = ?').get(d.event_id);
  const key = evRow.mux_stream_key;
  const sink = startSink(key);
  await sleep(900);
  const c = connect(d.ingest.token, VARIANTS[variant].mime);
  const ready = await c.waitFor('ready', 5000);
  check('message ready', !!ready);
  const gen = startGen(variant, c.ws);
  const tStart = Date.now();
  const live = await c.waitFor('live', 15000);
  check('message live', !!live, live ? `${live.at - tStart} ms après le 1er morceau` : '');
  const sess = studio._sessions.get(d.event_id);
  check(`ffmpeg ${expectCopy ? 'copy' : 'transcode'}`, !!sess && sess.copyVideo === expectCopy);
  const pid = sess && sess.ffPid;
  const cpu0 = cpuSeconds(pid); const w0 = Date.now();
  await sleep(seconds * 1000);
  const cpu1 = cpuSeconds(pid); const w1 = Date.now();
  const cpuPct = cpu0 != null && cpu1 != null ? ((cpu1 - cpu0) / ((w1 - w0) / 1000)) * 100 : null;
  const stats = c.msgs.filter((m) => m.type === 'stats');
  check('messages stats reçus', stats.length >= 1, stats.length ? `${stats[stats.length - 1].bitrate_kbps} kb/s, ${stats[stats.length - 1].seconds} s` : '');
  const st = db.prepare('SELECT status FROM events WHERE id = ?').get(d.event_id).status;
  check("event passé 'live'", st === 'live', st);
  const cur = await api('GET', '/studio/live/current', { token: tok });
  check('GET /live/current -> state live', cur.json.data && cur.json.data.state === 'live' && cur.json.data.event_id === d.event_id);
  const ff1 = sink.firstFrameAt[0] ? sink.firstFrameAt[0] - gen.firstChunkAt : null;
  out(`  mesure latence : 1er morceau envoyé -> 1re image reçue par le récepteur = ${ff1} ms`);
  out(`  mesure CPU ffmpeg (${expectCopy ? 'copy' : 'transcode'}) : ${cpuPct == null ? 'n/d' : cpuPct.toFixed(1) + ' % d\'un coeur'}`);

  const s = await api('POST', `/studio/live/${d.event_id}/stop`, { token: tok });
  check('POST /stop -> stopped', s.status === 200 && s.json.data.stopped === true);
  const ended = await c.waitFor('ended', 5000);
  check('message ended', !!ended);
  gen.stop();
  const st2 = db.prepare('SELECT status FROM events WHERE id = ?').get(d.event_id).status;
  check("event passé 'completed'", st2 === 'completed', st2);
  check('Mux complete appelé', muxCalls.complete.includes(evRow.mux_live_stream_id));
  await sleep(1500);
  sink.stop();
  await sleep(800);
  const pr = probe(sink.files[0]);
  check('récepteur : vidéo h264', pr.video && pr.video.codec_name === 'h264', pr.video && `${pr.video.width}x${pr.video.height}`);
  check('récepteur : audio aac', pr.audio && pr.audio.codec_name === 'aac');
  check(`récepteur : durée >= ${Math.round(seconds * 0.6)} s`, pr.duration >= seconds * 0.6, `${pr.duration.toFixed(1)} s`);
  check('ffmpeg tué après stop', !studio._sessions.has(d.event_id) && (pid == null || cpuSeconds(pid) === null));
  return { eventId: d.event_id, ff1, cpuPct };
}

async function main() {
  out('== Pré-requis ==');
  const ffv = spawnSync('ffmpeg', ['-version'], { encoding: 'utf8' });
  check('ffmpeg présent', ffv.status === 0, (ffv.stdout || '').split('\n')[0]);
  const status = await api('GET', '/studio/status');
  check('GET /status', status.json.data.enabled === true && status.json.data.ffmpeg === true, JSON.stringify(status.json.data));

  out('\n== Droits et validation ==');
  const anon = await api('POST', '/studio/live', { body: { title: 'x' } });
  check('sans jeton -> 401', anon.status === 401);
  const fanTok = await login('demo@vybzzz.com');
  const fan = await createLive(fanTok);
  check('non artiste -> 403', fan.status === 403, fan.json && fan.json.message);
  const a1 = await login('artist1@vybzzz.com');
  const noTitle = await createLive(a1, { price: 0 });
  check('titre manquant -> 422', noTitle.status === 422);
  const longTitle = await createLive(a1, { title: 'x'.repeat(81) });
  check('titre > 80 -> 422', longTitle.status === 422);
  const badPrice = await createLive(a1, { title: 'ok', price: 3 });
  check('prix hors grille -> 422', badPrice.status === 422, badPrice.json && badPrice.json.message.slice(0, 50));
  check('aucune création Mux sur validation en échec', muxCalls.create.length === 0);

  out('\n== Création : champs de l\'évènement ==');
  const created = await createLive(a1, { title: '  Mon concert  ', price: 4.99, replay: false, cover_url: 'http://x/y.jpg' });
  check('POST /live payant -> 200', created.status === 200, `${created.status}`);
  const cd = created.json.data;
  const row = db.prepare('SELECT * FROM events WHERE id = ?').get(cd.event_id);
  check("live_mode='pro', status published, studio", row.live_mode === 'pro' && row.status === 'published' && row.studio_web === 1);
  check('titre nettoyé, prix 4.99, replay 0, chat 1', row.name === 'Mon concert' && row.ticket_price === '4.99' && row.replay_enabled === 0 && row.has_live_chat === 1);
  const winH = (new Date(row.end_date_time) - new Date(row.start_date_time)) / 3600000;
  check('fenêtre 6 h', Math.abs(winH - 6) < 0.01, `${winH} h`);
  check('Mux : latency low', muxCalls.create[0] && muxCalls.create[0].latencyMode === 'low' && muxCalls.create[0].passthrough.id === cd.event_id);
  check('réponse : ingest.ws_url + jeton', cd.ingest && cd.ingest.ws_url === process.env.STUDIO_WS_URL && typeof cd.ingest.token === 'string');
  check('réponse : watch_url / web_url', cd.watch_url === `https://vybzzz.online/live.html?e=${cd.event_id}` && cd.web_url === `https://vybzzz.online/web/#/event/${cd.event_id}`);
  check('réponse : event sérialisé (pro, playback id propriétaire)', cd.event.live_mode === 'pro' && cd.event.mux_live_playback_id === row.mux_live_playback_id);
  check('clé Mux jamais renvoyée', !JSON.stringify(created.json).includes(row.mux_stream_key) && !JSON.stringify(created.json).includes('stream_key'));
  const claims = jwt.verify(cd.ingest.token, SECRET);
  check('jeton : purpose + event + user + ~30 min', claims.purpose === 'studio_ingest' && claims.event_id === cd.event_id && claims.user_id === row.artist_id && Math.abs(claims.exp - claims.iat - 1800) <= 1);
  const dup = await createLive(a1, { title: 'Deuxième' });
  check('2e session du même artiste -> 409 + session', dup.status === 409 && dup.json.data && dup.json.data.event_id === cd.event_id, `${dup.status}`);
  const cur0 = await api('GET', '/studio/live/current', { token: a1 });
  check("GET /current -> state 'prepared'", cur0.json.data && cur0.json.data.state === 'prepared');
  const curFan = await api('GET', '/studio/live/current', { token: fanTok });
  check('GET /current (fan) -> null', curFan.json.status === 'success' && curFan.json.data === null);
  const a2 = await login('artist2@vybzzz.com');
  const stopOther = await api('POST', `/studio/live/${cd.event_id}/stop`, { token: a2 });
  check("stop par un autre artiste -> 403", stopOther.status === 403);
  const stopNone = await api('POST', '/studio/live/999999/stop', { token: a1 });
  check('stop inconnu -> 404', stopNone.status === 404);
  const stopPrep = await api('POST', `/studio/live/${cd.event_id}/stop`, { token: a1 });
  check("stop d'une session jamais lancée -> cancelled", stopPrep.status === 200 && db.prepare('SELECT status FROM events WHERE id=?').get(cd.event_id).status === 'cancelled');
  await sleep(50);
  check('flux Mux supprimé (jamais lancé)', muxCalls.del.includes(row.mux_live_stream_id));
  const curAfter = await api('GET', '/studio/live/current', { token: a1 });
  check('GET /current -> null après arrêt', curAfter.json.data === null);

  out('\n== Jetons et refus WebSocket ==');
  const e1 = await createLive(a1, { title: 'Pour jetons' });
  const eid = e1.json.data.event_id;
  const goodTok = e1.json.data.ingest.token;
  let c = connect('n-importe-quoi', 'video/webm;codecs=vp8,opus');
  const m1 = await c.waitFor('error', 3000);
  check('jeton invalide refusé (4401)', !!m1 && (await c.waitClose()) === 4401);
  c = connect(jwt.sign({ purpose: 'studio_ingest', event_id: eid, user_id: 1 }, SECRET, { expiresIn: -5 }), 'video/webm');
  await c.waitFor('error', 3000);
  check('jeton expiré refusé (4401)', (await c.waitClose()) === 4401);
  c = connect(jwt.sign({ id: 1 }, SECRET, { expiresIn: 60 }), 'video/webm');
  await c.waitFor('error', 3000);
  check('jeton de connexion (autre usage) refusé (4401)', (await c.waitClose()) === 4401);
  const ownerId = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(eid).artist_id;
  c = connect(studio.signIngestToken(eid, ownerId + 1), 'video/webm');
  await c.waitFor('error', 3000);
  check("jeton d'un autre utilisateur refusé (4404)", (await c.waitClose()) === 4404);
  c = connect(studio.signIngestToken(999999, ownerId), 'video/webm');
  await c.waitFor('error', 3000);
  check('évènement inconnu refusé (4404)', (await c.waitClose()) === 4404);
  c = connect(goodTok, 'video/webm;codecs=vp8,opus');
  await c.waitFor('ready', 5000);
  c.ws.send(Buffer.from('ceci nest pas une video du tout'), { binary: true });
  const bad = await c.waitFor('error', 4000);
  check('contenu non vidéo refusé (4415)', !!bad && (await c.waitClose()) === 4415, bad && bad.message);
  check("session non lancée reste 'published'", db.prepare('SELECT status FROM events WHERE id=?').get(eid).status === 'published');
  studio.endEvent(eid, 'test');

  // Chemins nominaux : 3 variantes (artist1, 2, 3 : un compte = une session à la fois)
  const res = {};
  res.vp8 = await runVariant('Transcodage (Firefox / Chrome vp8)', 'vp8', 'artist2@vybzzz.com', 8, false);
  res.h264 = await runVariant('Copie vidéo (Chrome h264 dans webm)', 'h264webm', 'artist3@vybzzz.com', 8, true);
  res.mp4 = await runVariant('Copie vidéo (Safari mp4 fragmenté)', 'mp4', 'artist4@vybzzz.com', 8, true);

  // ─── Doublon, reconnexion, délai de grâce ───
  out('\n== Doublon / reconnexion / fin sans retour ==');
  const a5 = await login('artist5@vybzzz.com');
  const r5 = await createLive(a5, { title: 'Reco' });
  const d5 = r5.json.data;
  const key5 = db.prepare('SELECT mux_stream_key k FROM events WHERE id=?').get(d5.event_id).k;
  const sink = startSink(key5);
  await sleep(900);
  const mime = VARIANTS.h264webm.mime;
  const c1 = connect(d5.ingest.token, mime);
  await c1.waitFor('ready', 5000);
  const g1 = startGen('h264webm', c1.ws);
  check('1re connexion : live', !!(await c1.waitFor('live', 15000)));
  await sleep(2000);

  // Doublon (même évènement, même jeton) : l'ancienne connexion est éjectée.
  const c2 = connect(d5.ingest.token, mime);
  const kicked = await c1.waitFor('error', 5000);
  check('doublon : ancienne connexion éjectée (4000)', !!kicked && (await c1.waitClose()) === 4000, kicked && kicked.message);
  g1.stop();
  check('doublon : une seule session ffmpeg pour l\'évènement', studio._sessions.size === 1 && studio._sessions.get(d5.event_id).ws !== c1.ws);
  check("l'évènement reste live pendant la bascule", db.prepare('SELECT status FROM events WHERE id=?').get(d5.event_id).status === 'live');
  await c2.waitFor('ready', 5000);
  const g2 = startGen('h264webm', c2.ws);
  check('doublon : la nouvelle connexion passe live', !!(await c2.waitFor('live', 15000)));

  // Un 2e évènement du même artiste ne peut pas diffuser en même temps.
  const nowIso = new Date().toISOString();
  const ins = db.prepare(`INSERT INTO events (artist_id, name, ticket_price, start_date_time, end_date_time, status, live_mode, studio_web, mux_live_stream_id, mux_stream_key)
    VALUES (?, 'autre', '0', ?, ?, 'published', 'pro', 1, 'ls_other', 'sk_other')`).run(db.prepare('SELECT artist_id FROM events WHERE id=?').get(d5.event_id).artist_id, nowIso, nowIso);
  const uid5 = db.prepare('SELECT artist_id FROM events WHERE id=?').get(d5.event_id).artist_id;
  const c3 = connect(studio.signIngestToken(ins.lastInsertRowid, uid5), mime);
  const refused = await c3.waitFor('error', 4000);
  check('2e ingest du même artiste refusé (4409)', !!refused && (await c3.waitClose()) === 4409, refused && refused.message);
  check('la session en cours est intacte', studio._sessions.has(d5.event_id));
  db.prepare('UPDATE events SET status = ? WHERE id = ?').run('cancelled', ins.lastInsertRowid);

  // Coupure réseau brutale puis reconnexion dans la fenêtre.
  g2.stop();
  c2.ws.terminate();
  await sleep(1500);
  check("coupure : l'évènement reste live (fenêtre de reconnexion)", db.prepare('SELECT status FROM events WHERE id=?').get(d5.event_id).status === 'live');
  check('coupure : ffmpeg tué', !studio._sessions.has(d5.event_id));
  const tk = await api('POST', `/studio/live/${d5.event_id}/token`, { token: a5 });
  check('POST /live/:id/token -> nouveau jeton', tk.status === 200 && typeof tk.json.data.ingest.token === 'string');
  const c4 = connect(tk.json.data.ingest.token, mime);
  await c4.waitFor('ready', 5000);
  const g4 = startGen('h264webm', c4.ws);
  const t4 = Date.now();
  check('reconnexion : nouveau ffmpeg, live à nouveau', !!(await c4.waitFor('live', 15000)));
  const reLat = (c4.msgs.find((m) => m.type === 'live') || {}).at - t4;
  out(`  reconnexion : délai jusqu'à 'live' = ${reLat} ms`);
  await sleep(3000);
  check('reconnexion : récepteur a reçu 2 flux (2 fichiers)', sink.files.length >= 2 && fs.statSync(sink.files[1]).size > 10000, sink.files.map((f) => fs.existsSync(f) ? fs.statSync(f).size : 0).join('/'));
  check("reconnexion : l'évènement n'a jamais quitté 'live'", db.prepare('SELECT status FROM events WHERE id=?').get(d5.event_id).status === 'live');
  const completesBefore = muxCalls.complete.length;

  // Fin sans retour : le navigateur disparaît, STUDIO_GRACE_MS (6 s ici ; 90 s en vrai).
  g4.stop();
  c4.ws.terminate();
  await sleep(3000);
  check('avant la fin du délai : toujours live', db.prepare('SELECT status FROM events WHERE id=?').get(d5.event_id).status === 'live');
  await sleep(5000);
  check("sans retour : 'completed'", db.prepare('SELECT status FROM events WHERE id=?').get(d5.event_id).status === 'completed');
  check('sans retour : Mux complete appelé', muxCalls.complete.length === completesBefore + 1);
  sink.stop();

  // ─── Concert programmé payant lancé depuis le navigateur (plan de secours) ───
  out('\n== Concert programmé : basculer en secours ==');
  const { sign } = require('../src/auth');
  const webWatch = require('../src/services/web_watch');
  const { serializeEvent } = require('../src/helpers');
  const mkArtist = (email, name) => {
    const id = Number(db.prepare(
      "INSERT INTO users (email, password, full_name, artist_name, role, is_artist, is_verified, status) VALUES (?, 'x', ?, ?, 'artist', 1, 1, 'active')"
    ).run(email, name, name).lastInsertRowid);
    return { id, email, token: sign({ id, email }) };
  };
  const wilson = mkArtist('dj.wilson@test.vybzzz', 'DJ Wilson');
  const other = mkArtist('autre.artiste@test.vybzzz', 'Autre');
  const inH = (h) => new Date(Date.now() + h * 3600 * 1000).toISOString();
  const mkEvent = (artistId, o = {}) => Number(db.prepare(
    `INSERT INTO events (artist_id, name, ticket_price, start_date_time, end_date_time, status, live_mode, cover_image, replay_enabled, replay_duration_days,
        mux_live_stream_id, mux_stream_key, mux_live_playback_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 14, ?, ?, ?)`
  ).run(artistId, o.name || 'DJ WILSON — BIRTHDAY LIVE', o.price || '49.99', o.start || inH(72), o.end || inH(75), o.status || 'published',
    o.mode === undefined ? 'mobile' : o.mode, o.cover === undefined ? '/uploads/wilson.jpg' : o.cover, o.replay === undefined ? 1 : o.replay,
    o.lsId || null, o.key || null, o.pb || null).lastInsertRowid);
  const getEv = (id) => db.prepare('SELECT * FROM events WHERE id = ?').get(id);
  const fanTicket = db.prepare("SELECT id FROM users WHERE email = 'demo@vybzzz.com'").get().id;
  const fanNo = db.prepare("SELECT id FROM users WHERE email = 'fan1@vybzzz.com'").get().id;
  const fanRefunded = db.prepare("SELECT id FROM users WHERE email = 'fan2@vybzzz.com'").get().id;
  const giveTicket = (eventId, userId, status = 'active') => db.prepare(
    "INSERT OR REPLACE INTO tickets (event_id, user_id, price_paid, receipt_number, status) VALUES (?, ?, '49.99', ?, ?)"
  ).run(eventId, userId, `T${eventId}-${userId}`, status);

  const evA = mkEvent(wilson.id);                       // le concert payant, 3 jours avant l'heure
  const evSoon = mkEvent(wilson.id, { name: 'Soirée proche', price: '0', start: inH(2), end: inH(4) });
  const evPast = mkEvent(wilson.id, { name: 'Commencé il y a 5 h', start: inH(-5), end: inH(-2) });
  const evOld = mkEvent(wilson.id, { name: 'Trop ancien', start: inH(-30), end: inH(-27) });
  const evDone = mkEvent(wilson.id, { name: 'Terminé', status: 'completed', start: inH(-3), end: inH(-1) });
  const evCancel = mkEvent(wilson.id, { name: 'Annulé', status: 'cancelled' });
  const evOther = mkEvent(other.id, { name: "Concert d'un autre" });
  giveTicket(evA, fanTicket); giveTicket(evA, fanRefunded, 'refunded');

  // Droits et refus
  const noEv = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: 999999 } });
  check('event_id inconnu -> 404', noEv.status === 404 && /introuvable/i.test(noEv.json.message), noEv.json.message);
  const badEv = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: 'abc' } });
  check('event_id invalide -> 422', badEv.status === 422);
  const alien = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evOther } });
  check("concert d'un autre artiste -> 403", alien.status === 403, alien.json.message);
  const adminTok = sign(db.prepare("SELECT id, email FROM users WHERE role = 'admin' LIMIT 1").get());
  const adm = await api('POST', '/studio/live', { token: adminTok, body: { event_id: evA } });
  check('admin sur le concert d\'un artiste -> refusé (403)', adm.status === 403, adm.json.message);
  const fanTry = await api('POST', '/studio/live', { token: fanTok, body: { event_id: evA } });
  check('fan (non artiste) -> 403', fanTry.status === 403);
  const doneTry = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evDone } });
  check('concert terminé -> 409 (message clair)', doneTry.status === 409 && /terminé ou annulé/.test(doneTry.json.message), doneTry.json.message);
  const cancTry = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evCancel } });
  check('concert annulé -> 409', cancTry.status === 409);
  check('refus : rien modifié, aucun flux Mux créé', getEv(evA).live_mode === 'mobile' && getEv(evA).studio_web === 0 && getEv(evDone).status === 'completed');

  // Liste GET /studio/events
  const lst0 = await api('GET', '/studio/events', { token: wilson.token });
  const ids0 = (lst0.json.data || []).map((e) => e.id);
  check('GET /studio/events -> 200', lst0.status === 200 && lst0.json.status === 'success');
  check('liste : published/live à venir ou démarrés il y a < 12 h', ids0.includes(evA) && ids0.includes(evSoon) && ids0.includes(evPast), ids0.join(','));
  check('liste : ni terminé, annulé, trop ancien, ni celui des autres', !ids0.includes(evDone) && !ids0.includes(evCancel) && !ids0.includes(evOld) && !ids0.includes(evOther));
  check('liste : triée par date de début', ids0.indexOf(evPast) < ids0.indexOf(evSoon) && ids0.indexOf(evSoon) < ids0.indexOf(evA), ids0.join(','));
  const itemA = (lst0.json.data || []).find((e) => e.id === evA) || {};
  check('liste : champs id/name/status/start/prix/billets/affiche',
    itemA.name === 'DJ WILSON — BIRTHDAY LIVE' && itemA.status === 'published' && itemA.start_date_time === getEv(evA).start_date_time
    && itemA.ticket_price === '49.99' && itemA.cover_image === '/uploads/wilson.jpg' && 'tickets_sold' in itemA, JSON.stringify(itemA));
  check('liste : billets vendus = non remboursés (1 sur 2)', itemA.tickets_sold === 1, String(itemA.tickets_sold));
  require('../src/db_payments').run();
  db.prepare("INSERT INTO pending_tickets (email, event_id, price_paid, source, ref) VALUES ('web.acheteur@example.com', ?, '49.99', 'stripe', 'cs_test_studio_1')").run(evA);
  const lstP = await api('GET', '/studio/events', { token: wilson.token });
  check('liste : compte aussi les places achetées sur le site (sans compte)', ((lstP.json.data || []).find((e) => e.id === evA) || {}).tickets_sold === 2);
  db.prepare("DELETE FROM pending_tickets WHERE ref = 'cs_test_studio_1'").run();
  const lstFan = await api('GET', '/studio/events', { token: fanTok });
  check('GET /studio/events (fan) -> 403', lstFan.status === 403);
  const lstAnon = await api('GET', '/studio/events');
  check('GET /studio/events sans jeton -> 401', lstAnon.status === 401);

  // Démarrage sur le concert existant (flux Mux créé : l'évènement n'en avait pas)
  const createsBefore = muxCalls.create.length;
  const goA = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evA, title: 'AUTRE TITRE', price: 0, replay: false } });
  check('POST /live {event_id} -> 200', goA.status === 200 && goA.json.status === 'success', `${goA.status} ${goA.json.message || ''}`);
  const dA = goA.json.data;
  const rA = getEv(evA);
  check('même évènement (aucun doublon créé)', dA.event_id === evA && db.prepare('SELECT COUNT(*) n FROM events WHERE artist_id = ?').get(wilson.id).n === 6);
  check("live_mode passe à 'pro', status reste published, repéré studio", rA.live_mode === 'pro' && rA.status === 'published' && rA.studio_web === 1);
  check('titre, prix, replay, affiche, dates inchangés (corps ignoré)', rA.name === 'DJ WILSON — BIRTHDAY LIVE' && rA.ticket_price === '49.99' && rA.replay_enabled === 1 && rA.replay_duration_days === 14
    && rA.cover_image === '/uploads/wilson.jpg' && itemA.start_date_time === rA.start_date_time);
  check('flux Mux créé (latence low) et ids rangés sur l\'évènement', muxCalls.create.length === createsBefore + 1
    && muxCalls.create[createsBefore].latencyMode === 'low' && muxCalls.create[createsBefore].passthrough.id === evA
    && rA.mux_live_stream_id && rA.mux_stream_key && rA.mux_live_playback_id);
  check('réponse : existing, état prepared, jeton, jamais la clé Mux', dA.existing === true && dA.state === 'prepared' && typeof dA.ingest.token === 'string'
    && !JSON.stringify(goA.json).includes(rA.mux_stream_key));
  const prevA = JSON.parse(rA.studio_prev);
  check("instantané de l'état précédent (published / mobile)", prevA.status === 'published' && prevA.live_mode === 'mobile' && prevA.live === false);
  // Qui voit l'identifiant de lecture ?
  const svT = serializeEvent(getEv(evA), { currentUserId: fanTicket });
  const svN = serializeEvent(getEv(evA), { currentUserId: fanNo });
  const svR = serializeEvent(getEv(evA), { currentUserId: fanRefunded });
  const svAnon = serializeEvent(getEv(evA));
  check("fan avec billet : live_mode 'pro' + id de lecture du live", svT.live_mode === 'pro' && svT.mux_live_playback_id === rA.mux_live_playback_id);
  check('fan SANS billet (concert payant) : pas d\'id de lecture', svN.mux_live_playback_id === null && svN.live_mode === 'pro');
  check('billet remboursé / anonyme : pas d\'id de lecture', svR.mux_live_playback_id === null && svAnon.mux_live_playback_id === null);
  const apiT = await api('GET', `/event/${evA}`, { token: await login('demo@vybzzz.com') });
  check('GET /event/:id (app, avec billet) : mode pro + id', apiT.json.data.live_mode === 'pro' && apiT.json.data.mux_live_playback_id === rA.mux_live_playback_id);
  const apiN = await api('GET', `/event/${evA}`, { token: await login('fan1@vybzzz.com') });
  check('GET /event/:id (app, sans billet) : pas d\'id', apiN.json.data.mux_live_playback_id === null);
  // 2e session pendant celle-ci
  const dup2 = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evSoon } });
  check('un seul live à la fois par artiste (autre concert) -> 409', dup2.status === 409 && dup2.json.data.event_id === evA);
  const dup3 = await api('POST', '/studio/live', { token: wilson.token, body: { title: 'instantané' } });
  check('un seul live à la fois (nouveau live instantané) -> 409', dup3.status === 409);
  const cur1 = await api('GET', '/studio/live/current', { token: wilson.token });
  check('GET /current inclut le concert programmé (prepared, existing)', cur1.json.data && cur1.json.data.event_id === evA && cur1.json.data.state === 'prepared' && cur1.json.data.existing === true);
  const lst1 = await api('GET', '/studio/events', { token: wilson.token });
  check('liste : le concert en session reste listé', (lst1.json.data || []).some((e) => e.id === evA && e.in_session === true));

  // Départ en avance : le concert est dans 72 h, l'artiste décide de passer en direct maintenant.
  const sinkA = startSink(rA.mux_stream_key);
  await sleep(900);
  const cA = connect(dA.ingest.token, VARIANTS.h264webm.mime);
  await cA.waitFor('ready', 5000);
  const gA = startGen('h264webm', cA.ws);
  check('départ en avance (72 h avant) : message live', !!(await cA.waitFor('live', 15000)));
  const liveA = getEv(evA);
  check("évènement passé 'live' par le studio (sans attendre le webhook Mux)", liveA.status === 'live', liveA.status);
  check('date de début programmée conservée', liveA.start_date_time === rA.start_date_time);
  check('instantané : diffusé par le studio', JSON.parse(liveA.studio_prev).live === true);
  const cur2 = await api('GET', '/studio/live/current', { token: wilson.token });
  check('GET /current -> state live, existing', cur2.json.data && cur2.json.data.state === 'live' && cur2.json.data.existing === true);
  // Côté site : le fan qui a payé voit le live, celui sans billet non, le remboursé non.
  process.env.WATCH_ALLOW_PUBLIC = '1';
  const wTok = webWatch.issue('demo@vybzzz.com', evA, 'test');
  const wStream = await api('POST', '/watch/stream', { body: { event_id: evA, token: wTok, device: 'dev-test-0001', want_url: true } });
  check('site /watch/stream : ticket -> state live + URL HLS du live', wStream.status === 200 && wStream.json.data.state === 'live' && wStream.json.data.media === 'live'
    && wStream.json.data.url === `https://stream.mux.com/${rA.mux_live_playback_id}.m3u8`, `${wStream.status} ${JSON.stringify(wStream.json.data || wStream.json).slice(0, 160)}`);
  const wTokN = webWatch.issue('fan1@vybzzz.com', evA, 'test');
  const wStreamN = await api('POST', '/watch/stream', { body: { event_id: evA, token: wTokN, device: 'dev-test-0002', want_url: true } });
  check('site /watch/stream : sans billet -> 403, pas d\'URL', wStreamN.status === 403 && !JSON.stringify(wStreamN.json).includes('stream.mux.com'));
  const wTokR = webWatch.issue('fan2@vybzzz.com', evA, 'test');
  const wStreamR = await api('POST', '/watch/stream', { body: { event_id: evA, token: wTokR, device: 'dev-test-0003', want_url: true } });
  check('site /watch/stream : billet remboursé -> 403', wStreamR.status === 403);
  delete process.env.WATCH_ALLOW_PUBLIC;
  const apiLive = await api('GET', `/event/${evA}`, { token: await login('demo@vybzzz.com') });
  check("app : status 'live' + mode pro + id de lecture (billet)", apiLive.json.data.status === 'live' && apiLive.json.data.live_mode === 'pro' && !!apiLive.json.data.mux_live_playback_id);

  // Coupure réseau puis reconnexion dans la fenêtre : le concert reste live.
  gA.stop();
  cA.ws.terminate();
  await sleep(1500);
  check("coupure : le concert reste 'live' (fenêtre de reconnexion)", getEv(evA).status === 'live');
  const tkA = await api('POST', `/studio/live/${evA}/token`, { token: wilson.token });
  check('POST /live/:id/token -> jeton', tkA.status === 200 && typeof tkA.json.data.ingest.token === 'string');
  const cA2 = connect(tkA.json.data.ingest.token, VARIANTS.h264webm.mime);
  await cA2.waitFor('ready', 5000);
  const gA2 = startGen('h264webm', cA2.ws);
  check('reconnexion : live à nouveau', !!(await cA2.waitFor('live', 15000)));
  check("reconnexion : l'évènement n'a pas quitté 'live', mode pro, ids identiques",
    getEv(evA).status === 'live' && getEv(evA).live_mode === 'pro' && getEv(evA).mux_live_playback_id === rA.mux_live_playback_id);
  check('reconnexion : même clé de flux (même ingest, même playback id)', getEv(evA).mux_stream_key === rA.mux_stream_key && muxCalls.create.length === createsBefore + 1);
  await sleep(2500);

  // Arrêt : completed, l'évènement est conservé, jamais supprimé.
  const completesA = muxCalls.complete.length;
  const stopA = await api('POST', `/studio/live/${evA}/stop`, { token: wilson.token });
  check('POST /stop -> stopped', stopA.status === 200 && stopA.json.data.stopped === true && stopA.json.data.state === 'completed' && stopA.json.data.reverted === false);
  await cA2.waitFor('ended', 5000);
  gA2.stop();
  const doneA = getEv(evA);
  check("stop : status 'completed', end_date_time = maintenant", doneA.status === 'completed' && Math.abs(Date.now() - new Date(doneA.end_date_time).getTime()) < 15000, doneA.end_date_time);
  check("stop : l'évènement est conservé (titre, prix, billets, flux)", doneA.name === 'DJ WILSON — BIRTHDAY LIVE' && doneA.ticket_price === '49.99'
    && db.prepare('SELECT COUNT(*) n FROM tickets WHERE event_id = ?').get(evA).n === 2 && doneA.mux_live_stream_id === rA.mux_live_stream_id);
  check('stop : Mux complete appelé, flux Mux jamais supprimé', muxCalls.complete.length === completesA + 1 && muxCalls.complete.includes(rA.mux_live_stream_id) && !muxCalls.del.includes(rA.mux_live_stream_id));
  const stopAgain = await api('POST', `/studio/live/${evA}/stop`, { token: wilson.token });
  check('stop répété : idempotent (200, toujours completed)', stopAgain.status === 200 && getEv(evA).status === 'completed');
  const curDone = await api('GET', '/studio/live/current', { token: wilson.token });
  check('GET /current -> null après la fin', curDone.json.data === null);
  const lstDone = await api('GET', '/studio/events', { token: wilson.token });
  check('liste : le concert terminé n\'apparaît plus', !(lstDone.json.data || []).some((e) => e.id === evA));
  const wd = await api('POST', `/studio/live`, { token: wilson.token, body: { event_id: evA } });
  check('relancer un concert terminé -> 409', wd.status === 409);
  sinkA.stop();

  // Jamais lancé : retour à l'état d'avant, pas d'annulation.
  const evC = mkEvent(wilson.id, { name: 'Concert C', mode: 'mobile' });
  const delsBeforeC = muxCalls.del.length;
  const goC = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evC } });
  check('concert C : démarrage -> 200 (pro, flux créé)', goC.status === 200 && getEv(evC).live_mode === 'pro' && !!getEv(evC).mux_live_stream_id);
  const lsC = getEv(evC).mux_live_stream_id;
  const stopC = await api('POST', `/studio/live/${evC}/stop`, { token: wilson.token });
  const rC = getEv(evC);
  check("jamais en direct : status 'published' (PAS cancelled), live_mode d'avant", stopC.status === 200 && stopC.json.data.reverted === true && rC.status === 'published' && rC.live_mode === 'mobile', `${rC.status}/${rC.live_mode}`);
  await sleep(50);
  check('jamais en direct : flux Mux créé pour la session supprimé et ids effacés', muxCalls.del.length === delsBeforeC + 1 && muxCalls.del.includes(lsC) && !rC.mux_live_stream_id && !rC.mux_stream_key && !rC.mux_live_playback_id);
  check('jamais en direct : plus repéré studio, concert intact', rC.studio_web === 0 && rC.studio_prev === null && rC.name === 'Concert C' && rC.ticket_price === '49.99');
  const lstC = await api('GET', '/studio/events', { token: wilson.token });
  check('liste : le concert C est de nouveau proposé', (lstC.json.data || []).some((e) => e.id === evC && e.in_session === false));
  const curC = await api('GET', '/studio/live/current', { token: wilson.token });
  check('GET /current -> null', curC.json.data === null);

  // Préparation > 60 min jamais lancée : remis comme avant, jamais annulé (balayage).
  const goC2 = await api('POST', '/studio/live', { token: wilson.token, body: { event_id: evC } });
  check('concert C relancé -> 200', goC2.status === 200);
  const aged = JSON.parse(getEv(evC).studio_prev); aged.at = new Date(Date.now() - 2 * 3600 * 1000).toISOString();
  db.prepare('UPDATE events SET studio_prev = ? WHERE id = ?').run(JSON.stringify(aged), evC);
  const curC2 = await api('GET', '/studio/live/current', { token: wilson.token });
  const rC2 = getEv(evC);
  check("préparation > 60 min : revert (published/mobile), jamais 'cancelled'", curC2.json.data === null && rC2.status === 'published' && rC2.live_mode === 'mobile' && rC2.studio_web === 0, `${rC2.status}/${rC2.live_mode}`);
  // ... et un évènement créé par le studio, lui, est toujours annulé (inchangé).
  const dj2 = mkArtist('dj2@test.vybzzz', 'DJ Deux');
  const newOne = await createLive(dj2.token, { title: 'Instantané périmé' });
  db.prepare("UPDATE events SET created_at = datetime('now', '-2 hours') WHERE id = ?").run(newOne.json.data.event_id);
  await api('GET', '/studio/live/current', { token: dj2.token });
  check("évènement créé par le studio, préparation expirée : 'cancelled' comme avant", getEv(newOne.json.data.event_id).status === 'cancelled');

  // Flux Mux déjà présent (relais d'enregistrement de l'app) : réutilisé, même playback id.
  const dj3 = mkArtist('dj3@test.vybzzz', 'DJ Trois');
  const evD = mkEvent(dj3.id, { name: 'Concert D (relais app)', lsId: 'ls_mobile_relay', key: 'sk_mobile_relay_secret', pb: 'pb_mobile_relay' });
  giveTicket(evD, fanTicket);
  const createsD = muxCalls.create.length; const delsD = muxCalls.del.length;
  const goD = await api('POST', '/studio/live', { token: dj3.token, body: { event_id: evD } });
  const rD = getEv(evD);
  check('flux existant : réutilisé (aucune création, aucune suppression Mux)', goD.status === 200 && muxCalls.create.length === createsD && muxCalls.del.length === delsD);
  check("flux existant : mêmes ids (playback id connu des fans), live_mode 'pro'", rD.mux_live_stream_id === 'ls_mobile_relay' && rD.mux_stream_key === 'sk_mobile_relay_secret'
    && rD.mux_live_playback_id === 'pb_mobile_relay' && rD.live_mode === 'pro');
  check('flux existant : instantané new_stream=false', JSON.parse(rD.studio_prev).new_stream === false);
  check('flux existant : clé jamais renvoyée', !JSON.stringify(goD.json).includes('sk_mobile_relay_secret'));
  check('flux existant : le ticket voit le même playback id', serializeEvent(rD, { currentUserId: fanTicket }).mux_live_playback_id === 'pb_mobile_relay');
  // Il n'est pas allé en direct : arrêt -> retour mobile, le flux (celui de l'app) n'est PAS supprimé.
  const stopD = await api('POST', `/studio/live/${evD}/stop`, { token: dj3.token });
  const rD2 = getEv(evD);
  check("flux existant, jamais lancé : revert (published/mobile), flux conservé (celui de l'app)", stopD.json.data.reverted === true && rD2.status === 'published' && rD2.live_mode === 'mobile'
    && rD2.mux_live_stream_id === 'ls_mobile_relay' && !muxCalls.del.includes('ls_mobile_relay'));
  // Idem mais diffusé, puis navigateur disparu : completed après le délai de grâce.
  const goD2 = await api('POST', '/studio/live', { token: dj3.token, body: { event_id: evD } });
  const sinkD = startSink('sk_mobile_relay_secret');
  await sleep(900);
  const cD = connect(goD2.json.data.ingest.token, VARIANTS.vp8.mime);
  await cD.waitFor('ready', 5000);
  const gD = startGen('vp8', cD.ws);
  check('flux existant : diffusion (transcodage vp8) -> live', !!(await cD.waitFor('live', 15000)) && getEv(evD).status === 'live');
  await sleep(2500);
  gD.stop(); cD.ws.terminate();
  await sleep(1500);
  check('navigateur disparu : toujours live pendant le délai de grâce', getEv(evD).status === 'live');
  await sleep(6500);
  const rD3 = getEv(evD);
  check("sans retour : 'completed', concert conservé, end_date_time = maintenant", rD3.status === 'completed' && rD3.name === 'Concert D (relais app)' && Math.abs(Date.now() - new Date(rD3.end_date_time).getTime()) < 20000);
  check('sans retour : Mux complete appelé sur le flux existant', muxCalls.complete.includes('ls_mobile_relay'));
  sinkD.stop();
  const probeD = probe(sinkD.files[0]);
  check('flux existant : le récepteur a reçu h264 + aac', probeD.video && probeD.video.codec_name === 'h264' && probeD.audio && probeD.audio.codec_name === 'aac');

  // Concert déjà « live » (diffusé depuis l'app, téléphone planté) puis studio sans image : retour à 'live'/mobile.
  const dj4 = mkArtist('dj4@test.vybzzz', 'DJ Quatre');
  const evE = mkEvent(dj4.id, { name: 'Concert E', status: 'live', start: inH(-1), end: inH(2), lsId: 'ls_e', key: 'sk_e', pb: 'pb_e' });
  const goE = await api('POST', '/studio/live', { token: dj4.token, body: { event_id: evE } });
  check("concert déjà 'live' (app) : démarrage accepté, état 'live'", goE.status === 200 && goE.json.data.state === 'live' && JSON.parse(getEv(evE).studio_prev).status === 'live');
  const stopE = await api('POST', `/studio/live/${evE}/stop`, { token: dj4.token });
  const rE = getEv(evE);
  check("studio jamais diffusé : le concert reste 'live' côté app (pas 'completed'), mode d'avant", stopE.json.data.reverted === true && rE.status === 'live' && rE.live_mode === 'mobile', `${rE.status}/${rE.live_mode}`);

  // ─── Limiteur : 5 créations / 15 min / compte ───
  out('\n== Limiteur POST /live ==');
  const a6tok = await login('artist5@vybzzz.com');
  // artist5 a déjà 1 création réussie ci-dessus ; 4 de plus passent, la 6e est refusée.
  let okCount = 0; let last = null;
  for (let i = 0; i < 5; i++) {
    last = await createLive(a6tok, { title: `Lim ${i}` });
    if (last.status === 200) { okCount += 1; await api('POST', `/studio/live/${last.json.data.event_id}/stop`, { token: a6tok }); }
  }
  check('5 créations / 15 min puis 429', okCount === 4 && last.status === 429, `ok=${okCount}, dernier=${last.status}`);

  // ─── Fonction désactivée ───
  out('\n== STUDIO_WEB absent ==');
  process.env.STUDIO_WEB = '0';
  const off = await api('POST', '/studio/live', { token: a1, body: { title: 'x' } });
  check("POST /live -> 404 'Indisponible.'", off.status === 404 && off.json.message === 'Indisponible.');
  const offCur = await api('GET', '/studio/live/current', { token: a1 });
  check('GET /current -> 404', offCur.status === 404);
  const offSt = await api('GET', '/studio/status');
  check('GET /status reste public', offSt.status === 200 && offSt.json.data.enabled === false && offSt.json.data.ffmpeg === true);
  const httpStatus = await new Promise((resolve) => {
    const w = new WebSocket(`${process.env.STUDIO_WS_URL}?t=x`);
    w.on('unexpected-response', (_q, res) => resolve(res.statusCode));
    w.on('error', () => resolve('error'));
    w.on('open', () => resolve('open'));
  });
  check('WebSocket -> 404', httpStatus === 404, String(httpStatus));
  process.env.STUDIO_WEB = '1';
  const otherPath = await new Promise((resolve) => {
    const w = new WebSocket(`ws://127.0.0.1:${PORT}/autre/chemin`);
    w.on('unexpected-response', (_q, res) => resolve(`http ${res.statusCode}`));
    w.on('error', (e) => resolve(e.message));
    w.on('open', () => resolve('open'));
  });
  check('upgrade sur un autre chemin -> socket détruite', /socket hang up|ECONNRESET/i.test(otherPath), otherPath);

  // ─── Hygiène des journaux ───
  out('\n== Journaux ==');
  const secrets = db.prepare("SELECT mux_stream_key k FROM events WHERE mux_stream_key IS NOT NULL").all().map((r) => r.k).concat(['sk_test_']);
  const leaked = logs.filter((l) => secrets.some((k) => l.includes(k)) || /eyJ[A-Za-z0-9_-]{20,}/.test(l));
  check('ni clé Mux ni jeton dans les journaux', leaked.length === 0, leaked.slice(0, 2).join(' | '));
  check('journaux préfixés [studio]', logs.some((l) => l.startsWith('[studio]')), `${logs.filter((l) => l.startsWith('[studio]')).length} lignes`);

  out('\n== Résumé des mesures ==');
  for (const [k, v] of Object.entries(res)) out(`  ${k}: 1re image au récepteur ${v.ff1} ms, CPU ffmpeg ${v.cpuPct == null ? 'n/d' : v.cpuPct.toFixed(1) + ' %'}`);
}

main().catch((e) => { out('ERREUR : ' + (e.stack || e)); failN += 1; }).finally(async () => {
  studio.shutdown();
  spawnSync('pkill', ['-f', `rtmp://127.0.0.1:${RTMP_PORT}`]);
  out(`\n${pass} ok, ${failN} échec(s)`);
  setTimeout(() => process.exit(failN ? 1 : 0), 300);
});

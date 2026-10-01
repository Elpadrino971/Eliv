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

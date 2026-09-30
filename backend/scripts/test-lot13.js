'use strict';
/**
 * Tests du lot 13 (teaser d'accueil Mux, distinct du replay) sur une base
 * JETABLE, en processus (l'app Express est montée ici, pas server.js).
 * Aucun appel réel à Mux : `fetch` est remplacé par un faux qui enregistre
 * les appels vers api.mux.com et refuse tout autre hôte. Ne touche jamais
 * backend/vybzzz.sqlite.
 *
 *   VYBZZZ_DB=/tmp/l13.sqlite node scripts/test-lot13.js
 *
 * Sort en erreur (exit 1) si un contrôle échoue.
 */

const fs = require('fs');
const crypto = require('crypto');

const DB = process.env.VYBZZZ_DB || '/tmp/vybzzz-lot13-test.sqlite';
if (/vybzzz\.sqlite$/.test(DB)) { console.error('Refus : base de prod.'); process.exit(2); }
for (const f of [DB, `${DB}-wal`, `${DB}-shm`]) { try { fs.unlinkSync(f); } catch (_) {} }
process.env.VYBZZZ_DB = DB;
process.env.JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
process.env.MUX_WEBHOOK_SECRET = 'x';
process.env.STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || 'x';
process.env.REVENUECAT_WEBHOOK_AUTH = process.env.REVENUECAT_WEBHOOK_AUTH || 'x';
process.env.NODE_ENV = 'development';
// Faux identifiants : services/mux.js se croit configuré, fetch est mocké.
process.env.MUX_TOKEN_ID = 'mock-id';
process.env.MUX_TOKEN_SECRET = 'mock-secret';
delete process.env.SIGHTENGINE_API_USER;
delete process.env.SIGHTENGINE_API_SECRET;

// ─── Faux Mux ───
const muxCalls = [];
let uploadSeq = 0;
const realFetch = global.fetch;
global.fetch = async (url, opts = {}) => {
  const u = String(url);
  if (u.startsWith('http://127.0.0.1')) return realFetch(url, opts);
  if (!u.startsWith('https://api.mux.com/')) throw new Error(`appel réseau inattendu : ${u}`);
  const body = opts.body ? JSON.parse(opts.body) : null;
  const call = { method: opts.method || 'GET', path: u.slice('https://api.mux.com'.length), body };
  muxCalls.push(call);
  const json = (status, data) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
  if (call.method === 'POST' && call.path === '/video/v1/uploads') {
    uploadSeq += 1;
    return json(201, { data: { id: `up_${uploadSeq}`, url: `https://storage.mux.test/up_${uploadSeq}` } });
  }
  if (call.method === 'DELETE' && call.path.startsWith('/video/v1/assets/')) return new Response(null, { status: 204 });
  return json(404, { error: { type: 'not_found' } });
};

const jwt = require('jsonwebtoken');
const app = require('../src/app');
const { db } = require('../src/db');
const { serializeEvent } = require('../src/helpers');

let PASS = 0; let FAILS = 0;
function check(label, cond, extra) {
  if (cond) { PASS += 1; console.log(`  ok   ${label}`); } else { FAILS += 1; console.log(`  FAIL ${label}${extra !== undefined ? ` -> ${JSON.stringify(extra)}` : ''}`); }
}
const tick = () => new Promise((r) => setTimeout(r, 50));

function mkUser(email, extra = {}) {
  const cols = { email, password: 'x', full_name: email.split('@')[0], role: 'user', is_artist: 0, is_verified: 1, status: 'active', wallet: '0', ...extra };
  const keys = Object.keys(cols);
  const id = db.prepare(`INSERT INTO users (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`).run(...keys.map((k) => cols[k])).lastInsertRowid;
  return { id, token: jwt.sign({ id, email }, process.env.JWT_SECRET, { expiresIn: '1d' }) };
}
function mkEvent(artistId, extra = {}) {
  const cols = { name: 'Lot13 concert', artist_id: artistId, ticket_price: '9.99', status: 'published', start_date_time: new Date(Date.now() + 5 * 864e5).toISOString(), ...extra };
  const keys = Object.keys(cols);
  return db.prepare(`INSERT INTO events (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`).run(...keys.map((k) => cols[k])).lastInsertRowid;
}
const row = (id) => db.prepare('SELECT * FROM events WHERE id = ?').get(id);

async function main() {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((r) => server.once('listening', r));
  const BASE = `http://127.0.0.1:${server.address().port}/api`;
  const req = async (method, path, { token, body, headers = {}, raw } = {}) => {
    const h = { ...headers };
    if (token) h.Authorization = `Bearer ${token}`;
    if (body !== undefined) h['Content-Type'] = 'application/json';
    const res = await realFetch(`${BASE}${path}`, { method, headers: h, body: raw !== undefined ? raw : (body !== undefined ? JSON.stringify(body) : undefined) });
    let json = null; try { json = await res.json(); } catch (_) {}
    return { code: res.status, json };
  };
  const webhook = (evt) => {
    const raw = JSON.stringify(evt);
    const t = Math.floor(Date.now() / 1000);
    const v1 = crypto.createHmac('sha256', 'x').update(`${t}.${raw}`).digest('hex');
    return req('POST', '/mux/webhook', { raw, headers: { 'Content-Type': 'application/json', 'mux-signature': `t=${t},v1=${v1}` } });
  };
  const assetReady = (assetId, playbackId, passthrough) => webhook({
    type: 'video.asset.ready',
    data: { id: assetId, playback_ids: [{ id: playbackId, policy: 'public' }], passthrough: JSON.stringify(passthrough) },
  });

  const admin = mkUser('l13.admin@test.local', { role: 'admin' });
  const artist = mkUser('l13.artist@test.local', { role: 'artist', is_artist: 1, artist_name: 'L13 Artist' });
  const fan = mkUser('l13.fan@test.local');

  console.log('## 0. Migration');
  const cols = db.prepare('PRAGMA table_info(events)').all().map((c) => c.name);
  check('events.teaser_playback_id et events.teaser_asset_id présentes', cols.includes('teaser_playback_id') && cols.includes('teaser_asset_id'));

  // Concert payant avec un replay déjà en place.
  const EV = mkEvent(artist.id, { mux_playback_id: 'REPLAYPB', mux_asset_id: 'asset_replay', video_reel: 'https://stream.mux.com/REPLAYPB.m3u8', mux_upload_status: 'ready' });

  console.log('## 1. POST /admin/mux/direct-upload kind teaser (Mux mocké)');
  let r = await req('POST', '/admin/mux/direct-upload', { token: admin.token, body: { kind: 'teaser', ref_id: EV } });
  const up = muxCalls.filter((c) => c.path === '/video/v1/uploads').pop();
  check('200 + upload_url/upload_id/ref_id', r.code === 200 && r.json.data.upload_url && r.json.data.upload_id && Number(r.json.data.ref_id) === EV, r.json);
  check('passthrough {kind:teaser, id}', up && JSON.parse(up.body.new_asset_settings.passthrough).kind === 'teaser' && JSON.parse(up.body.new_asset_settings.passthrough).id === EV, up && up.body);
  check('playback public, sans static_renditions', up && JSON.stringify(up.body.new_asset_settings.playback_policy) === '["public"]' && !('static_renditions' in up.body.new_asset_settings), up && up.body);
  check('statut du REPLAY non touché (mux_upload_status/mux_upload_id)', row(EV).mux_upload_status === 'ready' && row(EV).mux_upload_id === null, row(EV));
  r = await req('POST', '/admin/mux/direct-upload', { token: admin.token, body: { kind: 'event', ref_id: EV } });
  const upEv = muxCalls.filter((c) => c.path === '/video/v1/uploads').pop();
  check('kind event (replay) : static_renditions toujours demandées', r.code === 200 && Array.isArray(upEv.body.new_asset_settings.static_renditions), upEv.body);
  db.prepare("UPDATE events SET mux_upload_status = 'ready', mux_upload_id = NULL WHERE id = ?").run(EV);
  r = await req('POST', '/admin/mux/direct-upload', { token: admin.token, body: { kind: 'teaser', ref_id: 999999 } });
  check('kind teaser sur concert inexistant -> 404', r.code === 404, r);
  r = await req('POST', '/admin/mux/direct-upload', { token: fan.token, body: { kind: 'teaser', ref_id: EV } });
  check('non-admin -> 401/403', r.code === 401 || r.code === 403, r.code);

  console.log('## 2. Webhook video.asset.ready kind teaser');
  r = await assetReady('asset_t1', 'TEASER1', { kind: 'teaser', id: EV });
  let e = row(EV);
  check('webhook 200', r.code === 200, r);
  check('teaser_playback_id / teaser_asset_id remplis', e.teaser_playback_id === 'TEASER1' && e.teaser_asset_id === 'asset_t1', e);
  check('replay intact (mux_playback_id, mux_asset_id, video_reel, statut)', e.mux_playback_id === 'REPLAYPB' && e.mux_asset_id === 'asset_replay' && e.video_reel === 'https://stream.mux.com/REPLAYPB.m3u8' && e.mux_upload_status === 'ready', e);
  const delBefore = muxCalls.filter((c) => c.method === 'DELETE').length;
  r = await assetReady('asset_t2', 'TEASER2', { kind: 'teaser', id: EV });
  await tick();
  e = row(EV);
  const dels = muxCalls.filter((c) => c.method === 'DELETE').slice(delBefore);
  check('2e teaser remplace le 1er', e.teaser_playback_id === 'TEASER2' && e.teaser_asset_id === 'asset_t2', e);
  check('ancien asset teaser supprimé chez Mux (best effort)', dels.length === 1 && dels[0].path === '/video/v1/assets/asset_t1', dels);
  check('replay toujours intact', e.mux_playback_id === 'REPLAYPB' && e.mux_asset_id === 'asset_replay', e);
  const d2 = muxCalls.filter((c) => c.method === 'DELETE').length;
  await assetReady('asset_t2', 'TEASER2', { kind: 'teaser', id: EV }); // webhook rejoué (même asset)
  await tick();
  check('webhook rejoué (même asset) : aucune suppression', muxCalls.filter((c) => c.method === 'DELETE').length === d2);

  console.log('## 3. serializeEvent / API publique : concert payant, visiteur anonyme');
  const anon = serializeEvent(row(EV), {});
  check('teaser_url public', anon.teaser_url === 'https://stream.mux.com/TEASER2.m3u8', anon.teaser_url);
  check('teaser_poster', anon.teaser_poster === 'https://image.mux.com/TEASER2/thumbnail.webp?width=720&time=1', anon.teaser_poster);
  check('video_reel / mux_playback_id / mux_live_playback_id masqués', anon.video_reel === null && anon.mux_playback_id === null && anon.mux_live_playback_id === null, { v: anon.video_reel, p: anon.mux_playback_id });
  const buyer = mkUser('l13.buyer@test.local');
  db.prepare("INSERT INTO tickets (event_id, user_id, price_paid, receipt_number, status) VALUES (?, ?, '9.99', 'L13-R1', 'active')").run(EV, buyer.id);
  const asBuyer = serializeEvent(row(EV), { currentUserId: buyer.id });
  check('acheteur : replay visible + teaser', asBuyer.mux_playback_id === 'REPLAYPB' && asBuyer.teaser_url === anon.teaser_url);
  const EV_NOTEASER = mkEvent(artist.id, { ticket_price: '0' });
  const noT = serializeEvent(row(EV_NOTEASER), {});
  check('sans teaser : teaser_url / teaser_poster = null', noT.teaser_url === null && noT.teaser_poster === null, noT);
  r = await req('GET', '/events');
  const inList = (r.json?.data || r.json?.events || []).find?.((x) => x.id === EV);
  check('GET /api/events renvoie teaser_url (anonyme)', !!inList && inList.teaser_url === anon.teaser_url && inList.mux_playback_id === null, inList && { t: inList.teaser_url, p: inList.mux_playback_id });
  r = await req('POST', '/admin/featured-event', { token: admin.token, body: { event_id: EV } });
  const fr = await req('GET', '/featured-event');
  check('GET /api/featured-event renvoie teaser_url / teaser_poster', fr.json?.data?.event?.teaser_url === anon.teaser_url && fr.json.data.event.teaser_poster === anon.teaser_poster, { set: r.json, got: fr.json?.data });

  console.log('## 4. GET /admin/events expose teaser_playback_id');
  r = await req('GET', '/admin/events', { token: admin.token });
  const ar = r.json.data.find((x) => x.id === EV);
  check('teaser_playback_id dans la liste admin', ar && ar.teaser_playback_id === 'TEASER2', ar);

  console.log('## 5. DELETE /admin/events/:id/teaser');
  const d3 = muxCalls.filter((c) => c.method === 'DELETE').length;
  r = await req('DELETE', `/admin/events/${EV}/teaser`, { token: admin.token });
  e = row(EV);
  const del3 = muxCalls.filter((c) => c.method === 'DELETE').slice(d3);
  check('200 + asset_deleted', r.code === 200 && r.json.data.asset_deleted === true && r.json.data.teaser_url === null, r.json);
  check('colonnes teaser vidées, replay intact', e.teaser_playback_id === null && e.teaser_asset_id === null && e.mux_playback_id === 'REPLAYPB', e);
  check('asset teaser supprimé chez Mux', del3.length === 1 && del3[0].path === '/video/v1/assets/asset_t2', del3);
  check('serializeEvent : teaser_url = null après retrait', serializeEvent(row(EV), {}).teaser_url === null);
  r = await req('DELETE', `/admin/events/${EV}/teaser`, { token: admin.token });
  check('2e DELETE : 200 idempotent (« Aucun teaser »)', r.code === 200 && r.json.data.asset_deleted === false, r.json);
  r = await req('DELETE', '/admin/events/999999/teaser', { token: admin.token });
  check('DELETE teaser concert inexistant -> 404', r.code === 404, r.code);
  r = await req('DELETE', `/admin/events/${EV}/teaser`, { token: fan.token });
  check('DELETE teaser non-admin -> 401/403', r.code === 401 || r.code === 403, r.code);

  console.log('## 6. POST /admin/events/:id/replay-to-teaser (teaser envoyé comme replay)');
  // Cas client : bande-annonce uploadée via l'ancien bouton (kind 'event') ->
  // le webhook a rempli le REPLAY (+ mux_live_playback_id, replay_expires_at).
  const EVW = mkEvent(artist.id, { name: 'DJ Wilson (test)' });
  await assetReady('asset_w', 'WILSONPB', { kind: 'event', id: EVW });
  e = row(EVW);
  check('pré-condition : vidéo rangée dans le replay', e.mux_playback_id === 'WILSONPB' && e.video_reel === 'https://stream.mux.com/WILSONPB.m3u8' && e.mux_asset_id === 'asset_w', e);
  check('pré-condition : masquée à l\'anonyme', serializeEvent(e, {}).mux_playback_id === null && serializeEvent(e, {}).teaser_url === null);
  r = await req('POST', `/admin/events/${EVW}/replay-to-teaser`, { token: admin.token });
  e = row(EVW);
  check('200 + données', r.code === 200 && r.json.data.teaser_playback_id === 'WILSONPB' && r.json.data.teaser_url === 'https://stream.mux.com/WILSONPB.m3u8', r.json);
  check('teaser rempli', e.teaser_playback_id === 'WILSONPB' && e.teaser_asset_id === 'asset_w', e);
  check('replay vidé (playback, asset, video_reel, live playback, statut, expiration)', e.mux_playback_id === null && e.mux_asset_id === null && e.video_reel === null && e.mux_live_playback_id === null && e.mux_upload_status === null && e.replay_expires_at === null, e);
  const sw = serializeEvent(e, {});
  check('anonyme : teaser_url visible, has_replay false', sw.teaser_url === 'https://stream.mux.com/WILSONPB.m3u8' && sw.has_replay === false, sw);
  r = await req('POST', `/admin/events/${EVW}/replay-to-teaser`, { token: admin.token });
  check('2e appel (plus de replay) -> 409', r.code === 409, r);
  const EVC = mkEvent(artist.id, { status: 'completed', mux_playback_id: 'REALREPLAY', mux_asset_id: 'asset_rr' });
  r = await req('POST', `/admin/events/${EVC}/replay-to-teaser`, { token: admin.token });
  check('concert completed -> 409, rien ne bouge', r.code === 409 && row(EVC).mux_playback_id === 'REALREPLAY' && row(EVC).teaser_playback_id === null, r);
  const EVE = mkEvent(artist.id, { status: 'ended', mux_playback_id: 'REALREPLAY2' });
  r = await req('POST', `/admin/events/${EVE}/replay-to-teaser`, { token: admin.token });
  check('concert ended -> 409', r.code === 409, r.code);
  const EVB = mkEvent(artist.id, { mux_playback_id: 'BLOCKED', mux_upload_status: 'blocked' });
  r = await req('POST', `/admin/events/${EVB}/replay-to-teaser`, { token: admin.token });
  check('vidéo bloquée par la modération -> 409', r.code === 409, r.code);
  // Teaser existant + replay qui est en fait un nouveau teaser : l'ancien asset teaser part.
  const EVR = mkEvent(artist.id, { teaser_playback_id: 'OLDT', teaser_asset_id: 'asset_oldt', mux_playback_id: 'NEWT', mux_asset_id: 'asset_newt', video_reel: 'https://legacy.example/teaser.mp4' });
  const d4 = muxCalls.filter((c) => c.method === 'DELETE').length;
  r = await req('POST', `/admin/events/${EVR}/replay-to-teaser`, { token: admin.token });
  await tick();
  e = row(EVR);
  const del4 = muxCalls.filter((c) => c.method === 'DELETE').slice(d4);
  check('remplace le teaser existant + supprime l\'ancien asset', e.teaser_playback_id === 'NEWT' && e.teaser_asset_id === 'asset_newt' && del4.length === 1 && del4[0].path === '/video/v1/assets/asset_oldt', { e, del4 });
  check('video_reel non-Mux (ancien teaser fichier) conservé', e.video_reel === 'https://legacy.example/teaser.mp4', e.video_reel);
  r = await req('POST', `/admin/events/${EVW}/replay-to-teaser`, { token: fan.token });
  check('non-admin -> 401/403', r.code === 401 || r.code === 403, r.code);

  console.log('## 7. Webhook teaser : concert inexistant / asset.errored');
  r = await assetReady('asset_x', 'XPB', { kind: 'teaser', id: 999999 });
  check('teaser concert inexistant : 200, rien écrit', r.code === 200 && !db.prepare("SELECT 1 FROM events WHERE teaser_asset_id = 'asset_x'").get());
  const EVX = mkEvent(artist.id, { teaser_playback_id: 'KEEP', teaser_asset_id: 'asset_keep' });
  r = await webhook({ type: 'video.asset.errored', data: { id: 'asset_err', passthrough: JSON.stringify({ kind: 'teaser', id: EVX }) } });
  check('asset.errored teaser : ancien teaser conservé, replay non marqué', r.code === 200 && row(EVX).teaser_playback_id === 'KEEP' && row(EVX).mux_upload_status === null, row(EVX));

  const stray = muxCalls.filter((c) => !(c.path === '/video/v1/uploads' || c.path.startsWith('/video/v1/assets/')));
  check('aucun autre appel Mux que uploads/assets (tous mockés)', stray.length === 0, stray);

  server.close();
  console.log(`\n${PASS} ok, ${FAILS} échec(s)`);
  process.exit(FAILS ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });

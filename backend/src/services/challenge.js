'use strict';
/**
 * VybzzZ Live Challenge — configuration, rattachement des fans amenés par un
 * artiste (pré-inscription web -> compte app avec le même e-mail) et calcul
 * du VybzzZ Score / classement.
 *
 * Mécanique du lien (friction minimale, validée) :
 *   1. L'artiste s'inscrit au challenge sur le site -> code personnel -> lien
 *      https://vybzzz.online/c/CODE
 *   2. Un fan ouvre le lien, laisse son e-mail (pré-inscription, statut 'pre').
 *   3. Quand un compte VybzzZ est créé ET vérifié avec ce même e-mail
 *      (OTP ou connexion Google/Apple), la pré-inscription passe 'qualified'
 *      et compte pour l'artiste. Un e-mail déjà membre avant la
 *      pré-inscription ne compte jamais (statut 'existing').
 *   Les clics sur le lien sont comptés à part et n'entrent PAS dans le score.
 */
const crypto = require('crypto');
const { db } = require('../db');

const CONFIG = {
  slug: 'live-challenge-2026',
  name: 'VybzzZ Live Challenge',
  start: '2026-09-20T00:00:00Z',
  end: '2026-10-24T23:59:59Z',
  organizer: 'Axen Digital, en collaboration avec Alizés Records',
  linkBase: process.env.CHALLENGE_LINK_BASE || 'https://vybzzz.online/c/',
  siteBase: process.env.SITE_BASE_URL || 'https://vybzzz.online',
  minLives: 1,
  topN: 40,
  // Pondérations du brief (base à confirmer avec les données réelles).
  weights: { audience: 35, referrals: 25, engagement: 20, economy: 10, activity: 10 },
  prizes: [
    { rank: 1, title: 'Nouvel iPhone Pro', detail: 'ou équipement créateur de valeur équivalente (~1 500 €)' },
    { rank: 2, title: '600 € de matériel', detail: 'pack matériel création / live' },
    { rank: 3, title: '400 € de matériel', detail: 'matériel ou accompagnement artistique' },
  ],
};

/** Lien nominatif : vybzzz.online/c/nom-de-scene (slug lisible, unique). */
function slugify(seed) {
  return String(seed || '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 28) || 'artiste';
}
function genCode(seed) {
  const base = slugify(seed);
  const exists = (s) => !!db.prepare('SELECT 1 FROM challenge_artists WHERE lower(code) = ?').get(s);
  if (!exists(base)) return base;
  for (let i = 2; i < 500; i++) if (!exists(`${base}-${i}`)) return `${base}-${i}`;
  return `${base}-${crypto.randomBytes(2).toString('hex')}`;
}

function cleanEmail(e) { return String(e || '').trim().toLowerCase(); }
function isEmail(e) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e); }
function linkFor(code) { return CONFIG.linkBase + code; }
function inWindow(iso) { const t = new Date(iso).getTime(); return t >= Date.parse(CONFIG.start) && t <= Date.parse(CONFIG.end); }

/** Inscription d'un artiste (idempotente par e-mail). */
function registerArtist({ stage_name, email, phone, genre, socials, adult, accept, ip }) {
  email = cleanEmail(email);
  if (!isEmail(email)) throw new Error('E-mail invalide.');
  if (!stage_name || String(stage_name).trim().length < 2) throw new Error('Nom de scène manquant.');
  if (!adult) throw new Error('Le challenge est réservé aux artistes de 18 ans et plus.');
  if (!accept) throw new Error('Merci d\'accepter le règlement.');
  const existing = db.prepare('SELECT * FROM challenge_artists WHERE email = ?').get(email);
  if (existing) return { ...existing, link: linkFor(existing.code), already: true };
  const user = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  const code = genCode(stage_name);
  const info = db.prepare(
    `INSERT INTO challenge_artists (code, email, stage_name, phone, genre, socials, user_id, accepted_rules, adult, ip)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, ?)`
  ).run(code, email, String(stage_name).trim(), phone || null, genre || null, socials || null, user?.id || null, ip || null);
  const row = db.prepare('SELECT * FROM challenge_artists WHERE id = ?').get(info.lastInsertRowid);
  return { ...row, link: linkFor(row.code), already: false };
}

function artistByCode(code) {
  return db.prepare('SELECT * FROM challenge_artists WHERE lower(code) = ?').get(String(code || '').trim().toLowerCase());
}

function countClick(artistId) {
  const day = new Date().toISOString().slice(0, 10);
  db.prepare(
    `INSERT INTO challenge_clicks (artist_id, day, count) VALUES (?, ?, 1)
     ON CONFLICT(artist_id, day) DO UPDATE SET count = count + 1`
  ).run(artistId, day);
}

/** Pré-inscription d'un fan via le lien d'un artiste. */
function joinViaLink({ code, email, name, ip, ua }) {
  const artist = artistByCode(code);
  if (!artist || artist.status === 'disqualified') throw new Error('Lien invalide.');
  email = cleanEmail(email);
  if (!isEmail(email)) throw new Error('E-mail invalide.');
  if (email === artist.email) throw new Error('Tu ne peux pas utiliser ton propre lien.');
  const dup = db.prepare('SELECT artist_id, status FROM challenge_referrals WHERE email = ?').get(email);
  if (dup) return { status: dup.artist_id === artist.id ? 'already' : 'other_artist' };
  const member = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  const status = member ? 'existing' : 'pre';
  db.prepare(
    `INSERT INTO challenge_referrals (artist_id, email, name, user_id, status, ip, ua) VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(artist.id, email, name ? String(name).trim().slice(0, 80) : null, member?.id || null, status, ip || null, ua ? String(ua).slice(0, 200) : null);
  return { status, artist: { stage_name: artist.stage_name } };
}

/**
 * À appeler quand un compte est VÉRIFIÉ (OTP validé, ou Google/Apple).
 * Qualifie la pré-inscription correspondante si le compte a été créé après elle.
 * Rattache aussi l'artiste à son compte si l'e-mail correspond.
 */
function onVerifiedUser(user) {
  try {
    if (!user || !user.email) return;
    const email = cleanEmail(user.email);
    const ref = db.prepare("SELECT * FROM challenge_referrals WHERE email = ? AND status = 'pre'").get(email);
    if (ref) {
      const createdAt = Date.parse((user.created_at || '').replace(' ', 'T') + 'Z') || Date.now();
      const preAt = Date.parse((ref.created_at || '').replace(' ', 'T') + 'Z') || 0;
      // Compte créé après la pré-inscription (tolérance 1 h pour l'horloge).
      if (createdAt >= preAt - 3600_000) {
        db.prepare("UPDATE challenge_referrals SET status = 'qualified', user_id = ?, qualified_at = datetime('now') WHERE id = ?").run(user.id, ref.id);
      } else {
        db.prepare("UPDATE challenge_referrals SET status = 'existing', user_id = ? WHERE id = ?").run(user.id, ref.id);
      }
    }
    db.prepare('UPDATE challenge_artists SET user_id = ? WHERE email = ? AND (user_id IS NULL OR user_id = 0)').run(user.id, email);
  } catch (e) {
    console.warn('[challenge] onVerifiedUser:', e.message);
  }
}

/** Métriques brutes d'un artiste sur la fenêtre du challenge. */
function rawMetrics(a) {
  const m = { lives: 0, audience: 0, referrals: 0, engagement: 0, economy: 0, clips: 0, clicks: 0, pre: 0 };
  const S = CONFIG.start.replace('T', ' ').slice(0, 19), E = CONFIG.end.replace('T', ' ').slice(0, 19);
  m.referrals = db.prepare("SELECT COUNT(*) c FROM challenge_referrals WHERE artist_id = ? AND status = 'qualified'").get(a.id).c;
  m.pre = db.prepare("SELECT COUNT(*) c FROM challenge_referrals WHERE artist_id = ? AND status = 'pre'").get(a.id).c;
  m.clicks = db.prepare('SELECT COALESCE(SUM(count),0) c FROM challenge_clicks WHERE artist_id = ?').get(a.id).c;
  if (!a.user_id) return m;
  const events = db.prepare(
    `SELECT id FROM events WHERE artist_id = ? AND status IN ('live','completed')
       AND start_date_time BETWEEN ? AND ?`
  ).all(a.user_id, S, E).map((r) => r.id);
  m.lives = events.length;
  m.clips = db.prepare(
    `SELECT COUNT(*) c FROM feed_clips WHERE user_id = ? AND active = 1 AND created_at BETWEEN ? AND ?`
  ).get(a.user_id, S, E).c;
  for (const ev of events) {
    // Audience réelle = personnes distinctes ayant pris une place OU interagi
    // pendant le live (chat, cadeau, question). Proxy en attendant un compteur
    // de présence dans l'app.
    const aud = db.prepare(
      `SELECT COUNT(DISTINCT user_id) c FROM (
         SELECT user_id FROM tickets WHERE event_id = ? AND status <> 'cancelled'
         UNION SELECT user_id FROM live_messages WHERE event_id = ?
         UNION SELECT user_id FROM activities WHERE event_id = ? AND type = 'gift'
         UNION SELECT user_id FROM live_questions WHERE event_id = ?
       ) WHERE user_id IS NOT NULL AND user_id <> ?`
    ).get(ev, ev, ev, ev, a.user_id).c;
    const msgs = db.prepare('SELECT COUNT(*) c FROM live_messages WHERE event_id = ?').get(ev).c;
    const gifts = db.prepare("SELECT COUNT(*) c, COALESCE(SUM(points),0) p FROM activities WHERE event_id = ? AND type = 'gift'").get(ev);
    const qs = db.prepare('SELECT COUNT(*) c, COALESCE(SUM(likes),0) l FROM live_questions WHERE event_id = ?').get(ev);
    const tix = db.prepare("SELECT COALESCE(SUM(price_paid),0) s FROM tickets WHERE event_id = ? AND status <> 'cancelled'").get(ev).s;
    m.audience += aud;
    m.engagement += msgs + gifts.c * 2 + qs.c + qs.l;
    // 100 points ≈ 1 € (grille provisoire, voir objectif collectif du Stage)
    m.economy += Number(tix) + Number(gifts.p) / 100;
  }
  return m;
}

let _cache = { at: 0, data: null };
function leaderboard(force) {
  if (!force && _cache.data && Date.now() - _cache.at < 60_000) return _cache.data;
  const artists = db.prepare("SELECT * FROM challenge_artists WHERE status <> 'disqualified' ORDER BY id").all();
  const rows = artists.map((a) => ({ artist: a, m: rawMetrics(a), activity: 0 }));
  for (const r of rows) r.activity = r.m.clips + 3 * r.m.lives;
  const max = (f) => Math.max(1, ...rows.map(f));
  const M = { audience: max((r) => r.m.audience), referrals: max((r) => r.m.referrals), engagement: max((r) => r.m.engagement), economy: max((r) => r.m.economy), activity: max((r) => r.activity) };
  const W = CONFIG.weights;
  for (const r of rows) {
    r.score = Math.round(
      (W.audience * r.m.audience) / M.audience +
      (W.referrals * r.m.referrals) / M.referrals +
      (W.engagement * r.m.engagement) / M.engagement +
      (W.economy * r.m.economy) / M.economy +
      (W.activity * r.activity) / M.activity
    );
    r.eligible = r.m.lives >= CONFIG.minLives;
  }
  rows.sort((x, y) => (y.eligible - x.eligible) || (y.score - x.score) || (y.m.referrals - x.m.referrals));
  const data = rows.map((r, i) => ({
    rank: i + 1,
    id: r.artist.id,
    code: r.artist.code,
    stage_name: r.artist.stage_name,
    score: r.score,
    eligible: r.eligible,
    lives: r.m.lives,
    clips: r.m.clips,
    referrals: r.m.referrals,
    pre: r.m.pre,
    clicks: r.m.clicks,
    audience: r.m.audience,
    engagement: r.m.engagement,
    economy: Math.round(r.m.economy * 100) / 100,
  }));
  _cache = { at: Date.now(), data };
  return data;
}

/** HTML de la page d'invitation nominative : balises Open Graph au nom de
 *  l'artiste (aperçu WhatsApp / Instagram / Facebook), puis redirection vers
 *  la page d'atterrissage du site. */
function inviteHtml(artist) {
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[ch]));
  const name = esc(artist.stage_name);
  const url = `${CONFIG.siteBase}/c/${esc(artist.code)}`;
  const landing = `${CONFIG.siteBase}/c.html?r=${encodeURIComponent(artist.code)}`;
  const title = `${name} t'invite sur VybzzZ`;
  const desc = `Rejoins ${name} sur VybzzZ, la scène live : ses concerts en direct, ses clips, et ta place au premier rang.`;
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title><meta name="description" content="${desc}">
<meta property="og:type" content="website"><meta property="og:site_name" content="VybzzZ"><meta property="og:title" content="${title}"><meta property="og:description" content="${desc}"><meta property="og:url" content="${url}"><meta property="og:image" content="${CONFIG.siteBase}/assets/challenge/og.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:locale" content="fr_FR">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${title}"><meta name="twitter:description" content="${desc}"><meta name="twitter:image" content="${CONFIG.siteBase}/assets/challenge/og.jpg">
<link rel="canonical" href="${url}"><link rel="icon" href="${CONFIG.siteBase}/favicon.ico">
<meta http-equiv="refresh" content="0;url=${landing}"><script>location.replace(${JSON.stringify(landing)});</script>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0A1226;color:#F4EFE3;font-family:system-ui,sans-serif;text-align:center;padding:24px}a{color:#E6C76A}</style></head>
<body><div><p>${name} t'invite sur VybzzZ.</p><a href="${landing}">Continuer →</a></div></body></html>`;
}

function publicConfig() {
  const { slug, name, start, end, organizer, weights, prizes, minLives, topN } = CONFIG;
  return { slug, name, start, end, organizer, weights, prizes, minLives, topN, now: new Date().toISOString() };
}

module.exports = { CONFIG, registerArtist, artistByCode, countClick, joinViaLink, onVerifiedUser, leaderboard, publicConfig, linkFor, inviteHtml, slugify };

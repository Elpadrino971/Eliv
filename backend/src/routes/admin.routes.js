'use strict';

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { db } = require('../db');
const { platformCounters, payoutCountdown } = require('../helpers');
const { hash, compare, SECRET } = require('../auth');
const { saveUpload, saveClipVideo } = require('../uploads');
const mux = require('../services/mux');
const anthropic = require('../services/anthropic');
const apporteurBonus = require('../services/apporteur_bonus');
const statements = require('../services/statements');
const truthy = (v) => v === true || v === 1 || v === '1' || v === 'true' || v === 'on';
const CLIP_RETENTION_DAYS = Number(process.env.CLIP_RETENTION_DAYS) || 30;

/** Auth admin : exige un token dont le user a role='admin'. */
function requireAdmin(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ status: 'error', message: 'Unauthenticated.' });
  try {
    const payload = jwt.verify(token, SECRET);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.id);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ status: 'error', message: 'Admin only.' });
    }
    req.admin = user;
    next();
  } catch (e) {
    return res.status(401).json({ status: 'error', message: 'Invalid token.' });
  }
}

// ─── IA (Claude) : rédaction assistée des descriptions concert / bio artiste ───
router.post('/ai/generate-description', requireAdmin, async (req, res) => {
  if (!anthropic.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'IA non configurée côté serveur (définir GEMINI_API_KEY gratuit ou ANTHROPIC_API_KEY).' });
  }
  const b = req.body || {};
  const kind = b.kind === 'artist' ? 'artist' : 'event';
  const hint = (b.hint || '').trim() || '(aucune info supplémentaire)';
  const prompt = kind === 'artist'
    ? `Rédige une bio d'artiste courte et percutante (3 à 4 phrases, en français, ton chaleureux et professionnel) pour la plateforme de concerts en streaming VybzzZ.
Nom d'artiste : ${b.artist_name || b.name || ''}
Genre musical : ${b.genre || ''}
Infos données par l'admin : ${hint}
Réponds uniquement avec le texte de la bio, sans titre ni guillemets.`
    : `Rédige une description de concert courte et vendeuse (3 à 4 phrases, en français, ton enthousiaste) pour la plateforme de concerts en streaming VybzzZ.
Nom du concert : ${b.name || ''}
Artiste : ${b.artist_name || ''}
Genre musical : ${b.genre || ''}
Infos données par l'admin : ${hint}
Réponds uniquement avec le texte de la description, sans titre ni guillemets.`;

  try {
    const text = await anthropic.generateText(prompt, { maxTokens: 250 });
    return res.json({ status: 'success', data: { text } });
  } catch (e) {
    console.error('[ai generate-description]', e.message);
    return res.status(502).json({ status: 'error', message: `Erreur IA : ${e.message}` });
  }
});

// POST /api/admin/login
router.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get((email || '').toLowerCase());
  if (!user || user.role !== 'admin' || !compare(password, user.password)) {
    return res.status(401).json({ status: 'error', message: 'Identifiants admin invalides.' });
  }
  const token = jwt.sign({ id: user.id, email: user.email }, SECRET, { expiresIn: '7d' });
  return res.json({
    status: 'success',
    token,
    admin: { id: user.id, email: user.email, full_name: user.full_name },
  });
});

// GET /api/admin/stats
router.get('/stats', requireAdmin, (req, res) => {
  const fans = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'user' AND is_artist = 0").get().c;
  const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE is_artist = 1').get().c;
  const events = db.prepare('SELECT COUNT(*) c FROM events').get().c;
  const packages = db.prepare('SELECT COUNT(*) c FROM packages').get().c;
  const referrals = db.prepare("SELECT COUNT(*) c FROM referrals WHERE status = 'validated'").get().c;
  const revenueRow = db.prepare("SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets").get();
  const counters = platformCounters();
  return res.json({
    status: 'success',
    data: {
      total_users: fans,
      total_artists: artists,
      total_events: events,
      total_packages: packages,
      total_referrals: referrals,
      total_revenue: Math.round(revenueRow.r),
      // OPRAS : artistes ayant tenu ≥1 concert + compteur d'audience total,
      // + compte à rebours des 60 j avant 1er paiement (mis en exergue).
      validated_artists: counters.validated_artists,
      users_all: counters.users_total,
      payout: payoutCountdown(),
    },
  });
});

// GET /api/admin/users?type=all|user|artist&search=
router.get('/users', requireAdmin, (req, res) => {
  const { type, search } = req.query;
  let sql = "SELECT * FROM users WHERE role != 'admin'";
  const params = [];
  if (type === 'user') sql += ' AND is_artist = 0';
  if (type === 'artist') sql += ' AND is_artist = 1';
  if (search) {
    sql += ' AND (full_name LIKE ? OR artist_name LIKE ? OR email LIKE ?)';
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  sql += ' ORDER BY id DESC';
  const rows = db.prepare(sql).all(...params).map((u) => ({
    id: u.id, full_name: u.full_name, artist_name: u.artist_name, email: u.email, phone_number: u.phone_number,
    address: u.address, status: u.status, is_artist: !!u.is_artist,
    profile_image: u.artist_profile || u.profile_image, created_at: u.created_at,
  }));
  const counts = {
    all: db.prepare("SELECT COUNT(*) c FROM users WHERE role != 'admin'").get().c,
    user: db.prepare("SELECT COUNT(*) c FROM users WHERE role != 'admin' AND is_artist = 0").get().c,
    artist: db.prepare("SELECT COUNT(*) c FROM users WHERE is_artist = 1").get().c,
  };
  return res.json({ status: 'success', data: rows, counts });
});

// POST /api/admin/users  (add)
router.post('/users', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.email) return res.status(422).json({ status: 'error', message: 'Email requis.' });
  const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(b.email.toLowerCase());
  if (exists) return res.status(422).json({ status: 'error', message: 'Email déjà utilisé.' });
  db.prepare(
    `INSERT INTO users (email, password, full_name, is_artist, status, registration_type, role)
     VALUES (?, ?, ?, ?, 'active', 'email', ?)`
  ).run(
    b.email.toLowerCase(), hash(b.password || 'password'), b.full_name || null,
    b.is_artist ? 1 : 0, b.is_artist ? 'artist' : 'user'
  );
  return res.json({ status: 'success', message: 'Utilisateur créé.' });
});

// POST /api/admin/users/:id/status
router.post('/users/:id/status', requireAdmin, (req, res) => {
  const status = req.body?.status || 'active';
  db.prepare("UPDATE users SET status = ? WHERE id = ?").run(status, req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});

// DELETE /api/admin/users/:id
router.delete('/users/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM users WHERE id = ? AND role != ?').run(req.params.id, 'admin');
  return res.json({ status: 'success', message: 'Utilisateur supprimé.' });
});

// ─── Genres CRUD ───
router.get('/genres', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM genres ORDER BY id').all() });
});
router.post('/genres', requireAdmin, (req, res) => {
  if (!req.body?.name) return res.status(422).json({ status: 'error', message: 'Nom requis.' });
  db.prepare('INSERT INTO genres (name) VALUES (?)').run(req.body.name);
  return res.json({ status: 'success', message: 'Genre ajouté.' });
});
router.put('/genres/:id', requireAdmin, (req, res) => {
  db.prepare("UPDATE genres SET name = ?, updated_at = datetime('now') WHERE id = ?").run(req.body?.name, req.params.id);
  return res.json({ status: 'success', message: 'Genre modifié.' });
});
router.delete('/genres/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM genres WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Genre supprimé.' });
});

// ─── User Genres ───
router.get('/user-genres', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT ug.user_id, ug.genre_id, u.full_name, u.email, u.profile_image, g.name AS genre, u.created_at
     FROM user_genres ug
     JOIN users u ON u.id = ug.user_id
     JOIN genres g ON g.id = ug.genre_id
     ORDER BY ug.user_id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Events (CRUD complet + vidéo Mux) ───
const muxHls = (id) => (id ? `https://stream.mux.com/${id}.m3u8` : null);

// Normalise les réglages replay envoyés par le formulaire admin. Absent ->
// activé par défaut. Durée bornée à 1..60 jours (60 = fenêtre de hold Apple).
function parseReplay(b) {
  const replayEnabled = (b.replay_enabled === undefined || b.replay_enabled === null)
    ? 1
    : (truthy(b.replay_enabled) ? 1 : 0);
  let replayDays = parseInt(b.replay_duration_days, 10);
  if (!Number.isFinite(replayDays) || replayDays < 1) replayDays = 60;
  if (replayDays > 60) replayDays = 60;
  return { replayEnabled, replayDays };
}

// Convertit une heure LOCALE saisie dans l'admin ("2026-06-07 02:30:00") + un
// offset (minutes vs UTC, ex: -180 pour GMT-3) en ISO UTC pour le stockage.
// Chaque spectateur la reverra ensuite dans SON propre fuseau (app cote client,
// via .toLocal()) : c'est ce qui rend l'heure correcte pour tout le monde.
function localToUtcIso(localStr, offsetMinutes) {
  if (!localStr) return null;
  const off = Number(offsetMinutes) || 0;
  const naive = new Date(`${localStr.replace(' ', 'T')}Z`);
  if (isNaN(naive.getTime())) return localStr;
  return new Date(naive.getTime() - off * 60000).toISOString();
}

router.get('/events', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT e.id, e.name, e.status, e.ticket_price, e.start_date_time, e.likes_count,
            e.artist_id, e.genre_id, e.description, e.cover_image, e.mux_playback_id,
            e.is_banner, e.tz_offset_minutes, e.mux_upload_status, e.mux_asset_id,
            e.replay_expires_at, e.replay_enabled, e.replay_duration_days,
            e.geo_mode, e.geo_countries, e.geo_block_until,
            e.mux_live_stream_id, u.artist_name AS artist
     FROM events e LEFT JOIN users u ON u.id = e.artist_id
     ORDER BY e.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// Concerts actuellement EN DIRECT — supervision / modération (la plateforme
// est responsable du contenu diffusé). Renvoie de quoi lister ET regarder via
// le flux HLS Mux (mux_live_playback_id, disponible une fois le relais
// Zego->Mux branché).
router.get('/live-events', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT e.id, e.name, e.start_date_time, e.likes_count,
            e.mux_live_playback_id, e.mux_live_stream_id,
            u.artist_name AS artist, u.id AS artist_id, u.email AS artist_email,
            (SELECT COUNT(DISTINCT t.user_id) FROM tickets t WHERE t.event_id = e.id) AS buyers
     FROM events e LEFT JOIN users u ON u.id = e.artist_id
     WHERE e.status = 'live'
     ORDER BY e.start_date_time DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// Liste des artistes (pour le menu déroulant du formulaire event)
router.get('/artists-list', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT id, COALESCE(artist_name, full_name, email) AS name FROM users WHERE is_artist = 1 ORDER BY name"
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Géo-blocage (par secteur) : normalisation + fin de blocage temporisé ───
function normalizeGeoMode(v) {
  const m = String(v || 'off').toLowerCase();
  return ['off', 'block', 'only'].includes(m) ? m : 'off';
}
function normalizeGeoCountries(v) {
  const set = new Set(
    String(v || '').split(',').map((c) => c.trim().toUpperCase()).filter((c) => /^[A-Z]{2}$/.test(c)),
  );
  return [...set].join(',');
}
// Durée en heures (admin) + début du concert -> date de fin du blocage. Passé
// cette date, la diffusion repart seule. 0/vide -> null (blocage permanent).
function computeGeoBlockUntil(startIso, hoursRaw) {
  const hours = parseFloat(hoursRaw);
  if (!Number.isFinite(hours) || hours <= 0) return null;
  const start = startIso ? Date.parse(startIso) : Date.now();
  const base = Number.isNaN(start) ? Date.now() : start;
  return new Date(base + hours * 60 * 60 * 1000).toISOString();
}

router.post('/events', requireAdmin, (req, res) => {
  const b = req.body || {};
  const cover = saveUpload(req, ['cover', 'cover_image', 'image'], 'covers', 'events/covers') || b.cover_image || null;
  if (!b.name) return res.status(422).json({ status: 'error', message: 'Le nom est requis.' });
  const tzOffset = Number(b.tz_offset_minutes) || 0;
  const { replayEnabled, replayDays } = parseReplay(b);
  const startUtc = localToUtcIso(b.start_date_time, tzOffset);
  db.prepare(
    `INSERT INTO events (artist_id, name, cover_image, ticket_price, start_date_time, tz_offset_minutes, genre_id,
        description, status, mux_playback_id, mux_live_playback_id, video_reel, is_banner,
        replay_enabled, replay_duration_days, geo_mode, geo_countries, geo_block_until)
     VALUES (@artist_id, @name, @cover, @price, @start, @tzOffset, @genre, @desc, @status, @mux, @muxLive, @reel, @banner,
        @replayEnabled, @replayDays, @geoMode, @geoCountries, @geoBlockUntil)`
  ).run({
    artist_id: b.artist_id || null, name: b.name, cover,
    price: b.ticket_price || '0', start: startUtc, tzOffset, genre: b.genre_id || null,
    desc: b.description || null, status: b.status || 'published',
    mux: b.mux_playback_id || null, muxLive: b.status === 'live' ? (b.mux_playback_id || null) : null,
    reel: muxHls(b.mux_playback_id), banner: b.is_banner ? 1 : 0,
    replayEnabled, replayDays,
    geoMode: normalizeGeoMode(b.geo_mode), geoCountries: normalizeGeoCountries(b.geo_countries),
    geoBlockUntil: computeGeoBlockUntil(startUtc, b.geo_block_hours),
  });
  return res.json({ status: 'success', message: 'Concert créé.' });
});

router.put('/events/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  const cover = saveUpload(req, ['cover', 'cover_image', 'image'], 'covers', 'events/covers') || b.cover_image || null;
  const tzOffset = Number(b.tz_offset_minutes) || 0;
  const { replayEnabled, replayDays } = parseReplay(b);
  const startUtc = localToUtcIso(b.start_date_time, tzOffset);
  db.prepare(
    `UPDATE events SET artist_id = @artist_id, name = @name, cover_image = @cover,
        ticket_price = @price, start_date_time = @start, tz_offset_minutes = @tzOffset, genre_id = @genre, description = @desc,
        status = @status, mux_playback_id = @mux, mux_live_playback_id = @muxLive,
        video_reel = @reel, is_banner = @banner,
        replay_enabled = @replayEnabled, replay_duration_days = @replayDays,
        geo_mode = @geoMode, geo_countries = @geoCountries, geo_block_until = @geoBlockUntil, updated_at = datetime('now')
     WHERE id = @id`
  ).run({
    id: req.params.id, artist_id: b.artist_id || null, name: b.name, cover,
    price: b.ticket_price || '0', start: startUtc, tzOffset, genre: b.genre_id || null,
    desc: b.description || null, status: b.status || 'published',
    mux: b.mux_playback_id || null, muxLive: b.status === 'live' ? (b.mux_playback_id || null) : null,
    reel: muxHls(b.mux_playback_id), banner: b.is_banner ? 1 : 0,
    replayEnabled, replayDays,
    geoMode: normalizeGeoMode(b.geo_mode), geoCountries: normalizeGeoCountries(b.geo_countries),
    geoBlockUntil: computeGeoBlockUntil(startUtc, b.geo_block_hours),
  });
  return res.json({ status: 'success', message: 'Concert mis à jour.' });
});

router.delete('/events/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM events WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Concert supprimé.' });
});

// ─── Mux : Direct Upload (replay/vidéo event ou clip) ───
// Le fichier ne transite JAMAIS par notre serveur : l'admin PUT le fichier
// brut directement sur l'URL Mux renvoyée ici. Mux prévient ensuite via
// webhook (`video.asset.ready`) et le backend attache le playback_id à la
// ligne visée (voir routes/mux.routes.js).
router.post('/mux/direct-upload', requireAdmin, (req, res) => {
  if (!mux.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Mux non configuré côté serveur (MUX_TOKEN_ID/MUX_TOKEN_SECRET manquants).' });
  }
  const b = req.body || {};
  const kind = b.kind === 'clip' ? 'clip' : 'event';

  let refId = Number(b.ref_id) || null;
  if (kind === 'clip' && !refId) {
    // Nouveau clip : on crée la ligne tout de suite (inactive tant que non prête + non approuvée).
    const info = db.prepare(
      'INSERT INTO feed_clips (feed, title, active, upload_status) VALUES (?, ?, 0, ?)'
    ).run(b.feed === 'clips' ? 'clips' : 'for_you', b.title || null, 'waiting');
    refId = info.lastInsertRowid;
  }
  if (!refId) {
    return res.status(422).json({ status: 'error', message: 'ref_id requis (event ou clip existant).' });
  }

  mux.createDirectUpload({ passthrough: { kind, id: refId } })
    .then(({ uploadId, uploadUrl }) => {
      if (kind === 'event') {
        db.prepare("UPDATE events SET mux_upload_id = ?, mux_upload_status = 'waiting' WHERE id = ?").run(uploadId, refId);
      } else {
        db.prepare("UPDATE feed_clips SET mux_upload_id = ?, upload_status = 'waiting' WHERE id = ?").run(uploadId, refId);
      }
      return res.json({ status: 'success', data: { upload_url: uploadUrl, upload_id: uploadId, ref_id: refId } });
    })
    .catch((e) => {
      console.error('[mux direct-upload]', e.message);
      return res.status(502).json({ status: 'error', message: `Erreur Mux : ${e.message}` });
    });
});

// ─── Mux : Live Stream (mode "Concert PRO" — régie -> encodeur -> Mux) ───
router.post('/events/:id/mux/live-stream', requireAdmin, (req, res) => {
  if (!mux.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Mux non configuré côté serveur.' });
  }
  const event = db.prepare('SELECT id FROM events WHERE id = ?').get(req.params.id);
  if (!event) return res.status(404).json({ status: 'error', message: 'Concert introuvable.' });

  mux.createLiveStream({ passthrough: { kind: 'event', id: event.id } })
    .then(({ liveStreamId, streamKey, playbackId, ingestUrl }) => {
      db.prepare(
        `UPDATE events SET mux_live_stream_id = ?, mux_stream_key = ?, mux_live_playback_id = ?
         WHERE id = ?`
      ).run(liveStreamId, streamKey, playbackId, event.id);
      return res.json({
        status: 'success',
        data: { live_stream_id: liveStreamId, stream_key: streamKey, playback_id: playbackId, ingest_url: ingestUrl },
      });
    })
    .catch((e) => {
      console.error('[mux live-stream]', e.message);
      return res.status(502).json({ status: 'error', message: `Erreur Mux : ${e.message}` });
    });
});

router.delete('/events/:id/mux/live-stream', requireAdmin, (req, res) => {
  const event = db.prepare('SELECT mux_live_stream_id FROM events WHERE id = ?').get(req.params.id);
  if (!event?.mux_live_stream_id) return res.json({ status: 'success', message: 'Aucun live stream actif.' });

  mux.deleteLiveStream(event.mux_live_stream_id)
    .catch((e) => console.error('[mux live-stream delete]', e.message))
    .finally(() => {
      db.prepare(
        "UPDATE events SET mux_live_stream_id = NULL, mux_stream_key = NULL, mux_live_playback_id = NULL WHERE id = ?"
      ).run(req.params.id);
      return res.json({ status: 'success', message: 'Live stream arrêté.' });
    });
});

// ─── Packages ───
router.get('/packages', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM packages ORDER BY id').all() });
});
router.post('/packages', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare(
    'INSERT INTO packages (name, points, price, revenuecat_product_id, active) VALUES (?, ?, ?, ?, ?)'
  ).run(b.name, b.points || '0', b.price || '0', b.revenuecat_product_id || null, truthy(b.active) ? 1 : 0);
  return res.json({ status: 'success', message: 'Package ajouté.' });
});
router.delete('/packages/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM packages WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Package supprimé.' });
});

// ─── Subscriptions ───
router.get('/subscriptions', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM subscriptions ORDER BY id').all() });
});

// ─── Reviews ───
router.get('/reviews', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.full_name AS user, u.email, e.name AS event
     FROM reviews r LEFT JOIN users u ON u.id = r.user_id LEFT JOIN events e ON e.id = r.event_id
     ORDER BY r.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.delete('/reviews/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM reviews WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Avis supprimé.' });
});

// ─── Withdrawals ───
router.get('/withdrawals', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT w.id, w.amount, w.status, w.bank, w.created_at, u.full_name AS user, u.artist_name, u.email
     FROM withdrawals w LEFT JOIN users u ON u.id = w.user_id ORDER BY w.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/withdrawals/:id/status', requireAdmin, (req, res) => {
  db.prepare('UPDATE withdrawals SET status = ? WHERE id = ?').run(req.body?.status || 'approved', req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});

// ─── Reports (agrégats) ───
router.get('/reports', requireAdmin, (req, res) => {
  const revenue = Math.round(db.prepare('SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets').get().r);
  const ticketsSold = db.prepare('SELECT COUNT(*) c FROM tickets').get().c;
  const topEvents = db.prepare(
    `SELECT e.name, COUNT(t.id) AS sales FROM events e
     LEFT JOIN tickets t ON t.event_id = e.id GROUP BY e.id ORDER BY sales DESC LIMIT 5`
  ).all();
  const byGenre = db.prepare(
    `SELECT g.name, COUNT(e.id) AS events FROM genres g
     LEFT JOIN events e ON e.genre_id = g.id GROUP BY g.id ORDER BY events DESC`
  ).all();
  return res.json({ status: 'success', data: { revenue, tickets_sold: ticketsSold, top_events: topEvents, by_genre: byGenre } });
});

// ─── Contact Leads ───
router.get('/contact-leads', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM contact_leads ORDER BY id DESC').all() });
});
// Approuver une candidature = choisir l'abonnement à lui attribuer. Si un
// compte existe déjà avec cet email, l'abonnement est activé immédiatement.
// Sinon la candidature reste "approuvée en attente" et /sign-up terminera
// l'activation tout seul dès que le candidat crée son compte avec ce même
// email (voir auth.routes.js) : plus besoin de repasser par l'écran
// "Utilisateurs" pour attribuer l'abonnement à la main.
router.post('/contact-leads/:id/approve', requireAdmin, (req, res) => {
  const lead = db.prepare('SELECT * FROM contact_leads WHERE id = ?').get(req.params.id);
  if (!lead) return res.status(404).json({ status: 'error', message: 'Candidature introuvable.' });
  const subscriptionsId = Number(req.body?.subscriptions_id);
  if (!subscriptionsId) return res.status(422).json({ status: 'error', message: 'Choisis un abonnement à attribuer.' });

  const user = db.prepare('SELECT * FROM users WHERE lower(email) = lower(?)').get(lead.email);
  if (user) {
    db.prepare("UPDATE users SET is_artist = 1, role = 'artist' WHERE id = ?").run(user.id);
    db.prepare('INSERT INTO user_subscriptions (user_id, subscriptions_id, status) VALUES (?, ?, ?)')
      .run(user.id, subscriptionsId, 'active');
    db.prepare("UPDATE contact_leads SET status = 'converted', approved_subscription_id = ? WHERE id = ?")
      .run(subscriptionsId, lead.id);
    return res.json({ status: 'success', message: 'Compte trouvé — abonnement activé immédiatement.' });
  }

  db.prepare("UPDATE contact_leads SET status = 'approved', approved_subscription_id = ? WHERE id = ?")
    .run(subscriptionsId, lead.id);
  return res.json({ status: 'success', message: "Pas encore de compte pour cet email — l'abonnement s'activera automatiquement dès l'inscription du candidat." });
});
router.post('/contact-leads/:id/reject', requireAdmin, (req, res) => {
  db.prepare("UPDATE contact_leads SET status = 'rejected', approved_subscription_id = NULL WHERE id = ?").run(req.params.id);
  return res.json({ status: 'success', message: 'Candidature refusée.' });
});
router.delete('/contact-leads/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM contact_leads WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Lead supprimé.' });
});

// ─── FAQ (CRUD) ───
router.get('/faqs', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM faqs ORDER BY id').all() });
});
router.post('/faqs', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('INSERT INTO faqs (question, answer) VALUES (?, ?)').run(b.question, b.answer);
  return res.json({ status: 'success', message: 'FAQ ajoutée.' });
});
router.put('/faqs/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE faqs SET question = ?, answer = ? WHERE id = ?').run(b.question, b.answer, req.params.id);
  return res.json({ status: 'success', message: 'FAQ modifiée.' });
});
router.delete('/faqs/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM faqs WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'FAQ supprimée.' });
});

// ─── CMS ───
router.get('/cms', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM cms_pages').all() });
});
router.put('/cms/:slug', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare(
    "INSERT INTO cms_pages (slug, title, content, updated_at) VALUES (?, ?, ?, datetime('now')) \
     ON CONFLICT(slug) DO UPDATE SET title = excluded.title, content = excluded.content, updated_at = datetime('now')"
  ).run(req.params.slug, b.title || '', b.content || '');
  return res.json({ status: 'success', message: 'Page CMS enregistrée.' });
});

// ─── Profile (admin courant) ───
router.get('/profile', requireAdmin, (req, res) => {
  const a = req.admin;
  return res.json({ status: 'success', data: { id: a.id, full_name: a.full_name, email: a.email, role: a.role } });
});
router.post('/profile', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (b.full_name) db.prepare('UPDATE users SET full_name = ? WHERE id = ?').run(b.full_name, req.admin.id);
  if (b.password) {
    db.prepare('UPDATE users SET password = ? WHERE id = ?').run(hash(b.password), req.admin.id);
  }
  return res.json({ status: 'success', message: 'Profil mis à jour.' });
});

// ─── Transactions (tickets) ───
router.get('/transactions', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT t.id, t.receipt_number, t.price_paid, t.status, t.created_at,
            u.full_name AS user, u.email, e.name AS event
     FROM tickets t
     LEFT JOIN users u ON u.id = t.user_id
     LEFT JOIN events e ON e.id = t.event_id
     ORDER BY t.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Abusive words ───
router.get('/abusive', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: db.prepare('SELECT * FROM abusive_words ORDER BY id').all() });
});
router.post('/abusive', requireAdmin, (req, res) => {
  if (req.body?.word) db.prepare('INSERT INTO abusive_words (word) VALUES (?)').run(req.body.word);
  return res.json({ status: 'success', message: 'Mot ajouté.' });
});
router.delete('/abusive/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM abusive_words WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Supprimé.' });
});

// ─── Listes pour les menus déroulants ───
router.get('/users-list', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT id, COALESCE(full_name, artist_name, email) AS name FROM users WHERE role != 'admin' ORDER BY name"
  ).all();
  return res.json({ status: 'success', data: rows });
});

// ─── Édition Utilisateur ───
router.put('/users/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  // photo : sert d'avatar artiste (artist_profile) ET de photo profil (profile_image)
  const photo = saveUpload(req, ['photo', 'avatar', 'profile_picture', 'image'], 'profiles', 'profiles') || b.photo || b.artist_profile || null;
  db.prepare(
    `UPDATE users SET full_name = @full_name, artist_name = @artist_name, phone_number = @phone, address = @address,
        is_artist = @artist,
        artist_profile = COALESCE(@photo, artist_profile),
        profile_image = COALESCE(@photo, profile_image)
     WHERE id = @id`
  ).run({
    id: req.params.id, full_name: b.full_name || null, artist_name: b.artist_name || null, phone: b.phone_number || null,
    address: b.address || null, artist: truthy(b.is_artist) ? 1 : 0, photo,
  });
  return res.json({ status: 'success', message: 'Utilisateur modifié.' });
});

// ─── User Genres : ajout / suppression ───
router.post('/user-genres', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.user_id || !b.genre_id) return res.status(422).json({ status: 'error', message: 'Utilisateur et genre requis.' });
  db.prepare('INSERT OR IGNORE INTO user_genres (user_id, genre_id) VALUES (?, ?)').run(b.user_id, b.genre_id);
  return res.json({ status: 'success', message: 'Association ajoutée.' });
});
router.delete('/user-genres', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM user_genres WHERE user_id = ? AND genre_id = ?').run(req.query.user_id, req.query.genre_id);
  return res.json({ status: 'success', message: 'Association supprimée.' });
});

// ─── Packages : édition ───
router.put('/packages/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  db.prepare(
    'UPDATE packages SET name = ?, points = ?, price = ?, revenuecat_product_id = ?, active = ? WHERE id = ?'
  ).run(b.name, b.points || '0', b.price || '0', b.revenuecat_product_id || null, truthy(b.active) ? 1 : 0, req.params.id);
  return res.json({ status: 'success', message: 'Package modifié.' });
});

// ─── Abonnements : CRUD ───
router.post('/subscriptions', requireAdmin, (req, res) => {
  const b = req.body || {};
  const image = saveUpload(req, ['image', 'photo'], 'covers', 'events/covers') || b.image || null;
  db.prepare('INSERT INTO subscriptions (name, tier, price, price_annual, period, active, image, slot_from, slot_to, commission, badge, perks, stripe_price_id, stripe_price_id_annual, revenuecat_product_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
    .run(b.name, b.tier || '', b.price || '0', b.price_annual || null, b.period || 'month', b.active === undefined ? 1 : (truthy(b.active) ? 1 : 0), image, b.slot_from || null, b.slot_to || null, b.commission || null, b.badge || null, b.perks || null, b.stripe_price_id || null, b.stripe_price_id_annual || null, b.revenuecat_product_id || null);
  return res.json({ status: 'success', message: 'Abonnement ajouté.' });
});
router.put('/subscriptions/:id', requireAdmin, (req, res) => {
  const b = req.body || {};
  const image = saveUpload(req, ['image', 'photo'], 'covers', 'events/covers') || b.image || null;
  db.prepare(`UPDATE subscriptions SET name = ?, tier = ?, price = ?, price_annual = ?, period = ?, active = ?,
      image = COALESCE(?, image), slot_from = ?, slot_to = ?, commission = ?, badge = ?, perks = ?,
      stripe_price_id = ?, stripe_price_id_annual = ?, revenuecat_product_id = ? WHERE id = ?`)
    .run(b.name, b.tier, b.price, b.price_annual || null, b.period, truthy(b.active) ? 1 : 0, image, b.slot_from || null, b.slot_to || null, b.commission || null, b.badge || null, b.perks || null, b.stripe_price_id || null, b.stripe_price_id_annual || null, b.revenuecat_product_id || null, req.params.id);
  return res.json({ status: 'success', message: 'Abonnement modifié.' });
});
router.delete('/subscriptions/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM subscriptions WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Abonnement supprimé.' });
});

// ─── Abonnements attribués (grant manuel à un utilisateur/artiste) ───
// Sert tant que /subscription/buy n'enregistre pas encore un vrai achat
// RevenueCat/IAP en base — permet de simuler/attribuer un abonnement actif.
router.get('/user-subscriptions', requireAdmin, (req, res) => {
  const rows = req.query.user_id
    ? db.prepare(`
        SELECT us.*, COALESCE(u.artist_name, u.full_name, u.email) AS user_name, s.name AS subscription_name
        FROM user_subscriptions us
        LEFT JOIN users u ON u.id = us.user_id
        LEFT JOIN subscriptions s ON s.id = us.subscriptions_id
        WHERE us.user_id = ?
        ORDER BY us.id DESC
      `).all(req.query.user_id)
    : db.prepare(`
        SELECT us.*, COALESCE(u.artist_name, u.full_name, u.email) AS user_name, s.name AS subscription_name
        FROM user_subscriptions us
        LEFT JOIN users u ON u.id = us.user_id
        LEFT JOIN subscriptions s ON s.id = us.subscriptions_id
        ORDER BY us.id DESC
      `).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/user-subscriptions', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.user_id || !b.subscriptions_id) {
    return res.status(422).json({ status: 'error', message: 'Utilisateur et abonnement requis.' });
  }
  db.prepare('INSERT INTO user_subscriptions (user_id, subscriptions_id, status) VALUES (?, ?, ?)')
    .run(b.user_id, b.subscriptions_id, b.status || 'active');
  return res.json({ status: 'success', message: 'Abonnement attribué.' });
});
router.delete('/user-subscriptions/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM user_subscriptions WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Abonnement retiré.' });
});

// ─── Feed Clips ("Pour toi" / "Clips") : upload direct depuis l'admin, ou
// Mux Playback ID si la vidéo est déjà sur Mux. Voir /api/feed-clips (public).
router.get('/feed-clips', requireAdmin, (req, res) => {
  const rows = db.prepare(`
    SELECT fc.*, COALESCE(u.artist_name, u.full_name, u.email) AS submitted_by
    FROM feed_clips fc LEFT JOIN users u ON u.id = fc.user_id
    ORDER BY fc.active ASC, fc.feed, fc.position, fc.id DESC
  `).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/feed-clips/:id/approve', requireAdmin, (req, res) => {
  db.prepare('UPDATE feed_clips SET active = 1 WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Clip approuvé.' });
});
router.post('/feed-clips', requireAdmin, async (req, res) => {
  const b = req.body || {};
  const uploaded = await saveClipVideo(req, ['video', 'file']);
  const video = uploaded?.url || b.video_url || null;
  const firebasePath = uploaded?.firebasePath || null;
  const expiresAt = firebasePath ? `datetime('now', '+' || ${CLIP_RETENTION_DAYS} || ' days')` : 'NULL';
  // Pas de vidéo à la création ? OK : elle peut être attachée ensuite via le
  // bouton "🎬 Upload" (Mux Direct Upload) depuis la liste.
  // artist_id (optionnel) rattache le clip à un artiste : il apparaît alors
  // dans la grille "façon TikTok" de sa fiche profil (GET /api/artist/:id/clips)
  // en plus du feed. Vide = clip officiel, non rattaché.
  const artistId = b.artist_id ? Number(b.artist_id) : null;
  db.prepare(
    `INSERT INTO feed_clips (feed, title, video_url, mux_playback_id, position, active, user_id, firebase_path, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ${expiresAt})`
  ).run(
    b.feed === 'clips' ? 'clips' : 'for_you', b.title || null, video, b.mux_playback_id || null,
    Number(b.position) || 0, b.active === undefined ? 1 : (truthy(b.active) ? 1 : 0), artistId, firebasePath
  );
  return res.json({ status: 'success', message: 'Clip ajouté.' });
});
router.put('/feed-clips/:id', requireAdmin, async (req, res) => {
  const b = req.body || {};
  const uploaded = await saveClipVideo(req, ['video', 'file']);
  const video = uploaded?.url || b.video_url || null;
  const artistId = b.artist_id ? Number(b.artist_id) : null;
  db.prepare(
    `UPDATE feed_clips SET feed = ?, title = ?, video_url = COALESCE(?, video_url), mux_playback_id = ?,
        position = ?, active = ?, user_id = ?, firebase_path = COALESCE(?, firebase_path),
        expires_at = CASE WHEN ? IS NOT NULL THEN datetime('now', '+' || ? || ' days') ELSE expires_at END
     WHERE id = ?`
  ).run(
    b.feed === 'clips' ? 'clips' : 'for_you', b.title || null, video, b.mux_playback_id || null,
    Number(b.position) || 0, truthy(b.active) ? 1 : 0, artistId, uploaded?.firebasePath || null,
    uploaded?.firebasePath || null, CLIP_RETENTION_DAYS, req.params.id
  );
  return res.json({ status: 'success', message: 'Clip modifié.' });
});
router.delete('/feed-clips/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM feed_clips WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Clip supprimé.' });
});

// ─── Graphiques + Objectifs (Dashboard) ───
const MONTHS_FR = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
router.get('/chart-data', requireAdmin, (req, res) => {
  const rows = db.prepare(
    "SELECT strftime('%Y-%m', created_at) m, COALESCE(SUM(CAST(price_paid AS REAL)),0) rev, COUNT(*) cnt FROM tickets GROUP BY m"
  ).all();
  const byMonth = Object.fromEntries(rows.map((r) => [r.m, r]));
  const now = new Date();
  const months = [];
  for (let i = 5; i >= 0; i--) months.push(new Date(now.getFullYear(), now.getMonth() - i, 1));
  const keys = months.map((d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  const labels = months.map((d) => MONTHS_FR[d.getMonth()]);
  const revenue = keys.map((k) => Math.round(byMonth[k]?.rev || 0));
  const tickets = keys.map((k) => byMonth[k]?.cnt || 0);

  const g = (k, def) => +(db.prepare('SELECT value v FROM settings WHERE key = ?').get(k)?.v || def);
  const totalRev = Math.round(db.prepare("SELECT COALESCE(SUM(CAST(price_paid AS REAL)),0) r FROM tickets").get().r);
  const fans = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'user' AND is_artist = 0").get().c;
  const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE is_artist = 1').get().c;
  return res.json({
    status: 'success',
    data: {
      labels, revenue, tickets,
      goals: {
        revenue: { current: totalRev, target: g('goal_revenue', 50000) },
        users: { current: fans, target: g('goal_users', 500) },
        artists: { current: artists, target: g('goal_artists', 50) },
      },
    },
  });
});
router.put('/goals', requireAdmin, (req, res) => {
  const b = req.body || {};
  const set = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  ['goal_revenue', 'goal_users', 'goal_artists'].forEach((k) => { if (b[k] != null && b[k] !== '') set.run(k, String(b[k])); });
  return res.json({ status: 'success', message: 'Objectifs enregistrés.' });
});

// ─── Parrainage (10% par nouvel artiste parrainé, plafonné à 10/mois) ───
function refRule() {
  const rate = +(db.prepare("SELECT value v FROM settings WHERE key = 'referral_rate'").get()?.v || 10);
  const cap = +(db.prepare("SELECT value v FROM settings WHERE key = 'referral_monthly_cap'").get()?.v || 10);
  return { rate, cap };
}

router.get('/referrals', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT r.id, r.code, r.status, r.reward, r.created_at, r.referrer_id,
            COALESCE(ru.artist_name, ru.full_name, ru.email) AS referrer,
            COALESCE(re.full_name, re.email) AS referee, re.is_artist AS referee_is_artist
     FROM referrals r
     LEFT JOIN users ru ON ru.id = r.referrer_id
     LEFT JOIN users re ON re.id = r.referee_id
     ORDER BY r.id DESC`
  ).all();
  // Compteur du mois en cours par parrain (artistes validés uniquement)
  const month = new Date().toISOString().slice(0, 7);
  const monthly = {};
  for (const r of rows) {
    if (r.status === 'validated' && r.referee_is_artist && (r.created_at || '').slice(0, 7) === month) {
      monthly[r.referrer_id] = (monthly[r.referrer_id] || 0) + 1;
    }
  }
  return res.json({ status: 'success', data: rows, rule: refRule(), monthly });
});

router.put('/referral-settings', requireAdmin, (req, res) => {
  const b = req.body || {};
  const set = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  if (b.rate != null) set.run('referral_rate', String(b.rate));
  if (b.cap != null) set.run('referral_monthly_cap', String(b.cap));
  return res.json({ status: 'success', message: 'Règle de parrainage enregistrée.' });
});

// ─── Page de lancement (splash) : fond d'écran + animation personnalisables
// depuis l'admin, lus par l'app via GET /api/splash-settings (public). Permet
// de changer le visuel de démarrage sans nouvelle version App Store/Play Store.
const SPLASH_ANIMATION_STYLES = ['sparkles', 'fade', 'none'];

router.get('/splash-settings', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT key, value FROM settings WHERE key IN ('splash_background_image', 'splash_background_video', 'splash_logo_image', 'splash_text_color', 'splash_overlay', 'splash_animation_style')`
  ).all();
  const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return res.json({
    status: 'success',
    data: {
      background_image: map.splash_background_image || null,
      background_video: map.splash_background_video || null,
      logo_image: map.splash_logo_image || null,
      text_color: map.splash_text_color || null,
      overlay: Number(map.splash_overlay) || 0,
      animation_style: map.splash_animation_style || 'sparkles',
    },
  });
});

router.put('/splash-settings', requireAdmin, (req, res) => {
  const b = req.body || {};
  const set = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');

  const imageUrl = saveUpload(req, ['background_image', 'image'], 'splash', 'splash');
  if (imageUrl) set.run('splash_background_image', imageUrl);
  else if (truthy(b.remove_background_image)) set.run('splash_background_image', '');

  const videoUrl = saveUpload(req, ['background_video', 'video'], 'splash', 'splash');
  if (videoUrl) set.run('splash_background_video', videoUrl);
  else if (truthy(b.remove_background_video)) set.run('splash_background_video', '');

  // Logo emblème (image) — même mécanique que le fond : géré depuis l'admin/VPS,
  // récupéré par l'app via /api/splash-settings (aucune nouvelle version requise).
  const logoUrl = saveUpload(req, ['logo_image', 'logo'], 'splash', 'splash');
  if (logoUrl) set.run('splash_logo_image', logoUrl);
  else if (truthy(b.remove_logo_image)) set.run('splash_logo_image', '');

  // Colorimétrie / contraste des écritures (lisibilité selon le fond).
  if (typeof b.text_color === 'string' && /^#?[0-9a-fA-F]{6}$/.test(b.text_color.trim())) {
    set.run('splash_text_color', '#' + b.text_color.trim().replace(/^#/, ''));
  }
  if (b.overlay !== undefined && b.overlay !== '') {
    const ov = Math.max(0, Math.min(85, parseInt(b.overlay, 10) || 0));
    set.run('splash_overlay', String(ov));
  }

  if (b.animation_style && SPLASH_ANIMATION_STYLES.includes(b.animation_style)) {
    set.run('splash_animation_style', b.animation_style);
  }

  const rows = db.prepare(
    `SELECT key, value FROM settings WHERE key IN ('splash_background_image', 'splash_background_video', 'splash_logo_image', 'splash_text_color', 'splash_overlay', 'splash_animation_style')`
  ).all();
  const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return res.json({
    status: 'success',
    message: 'Page de lancement mise à jour.',
    data: {
      background_image: map.splash_background_image || null,
      background_video: map.splash_background_video || null,
      logo_image: map.splash_logo_image || null,
      text_color: map.splash_text_color || null,
      overlay: Number(map.splash_overlay) || 0,
      animation_style: map.splash_animation_style || 'sparkles',
    },
  });
});

router.post('/referrals', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.referrer_id || !b.referee_id) return res.status(422).json({ status: 'error', message: 'Parrain et filleul requis.' });
  if (b.referrer_id === b.referee_id) return res.status(422).json({ status: 'error', message: 'Un parrain ne peut pas se parrainer lui-même.' });
  const code = db.prepare('SELECT referral_code c FROM users WHERE id = ?').get(b.referrer_id)?.c || 'MANUEL';
  db.prepare("INSERT INTO referrals (code, referrer_id, referee_id, status, reward) VALUES (?, ?, ?, ?, ?)")
    .run(code, b.referrer_id, b.referee_id, b.status || 'validated', refRule().rate + '%');
  return res.json({ status: 'success', message: 'Parrainage ajouté.' });
});

router.post('/referrals/:id/validate', requireAdmin, (req, res) => {
  db.prepare("UPDATE referrals SET status = 'validated' WHERE id = ?").run(req.params.id);
  return res.json({ status: 'success', message: 'Parrainage validé.' });
});
router.delete('/referrals/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM referrals WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Parrainage supprimé.' });
});

// ─── Boîte à idées ───
router.get('/ideas', requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT i.*, COALESCE(u.full_name, u.artist_name, i.name) AS author
     FROM ideas i LEFT JOIN users u ON u.id = i.user_id ORDER BY i.id DESC`
  ).all();
  return res.json({ status: 'success', data: rows });
});
router.post('/ideas/:id/status', requireAdmin, (req, res) => {
  db.prepare('UPDATE ideas SET status = ? WHERE id = ?').run(req.body?.status || 'reviewed', req.params.id);
  return res.json({ status: 'success', message: 'Statut mis à jour.' });
});
router.delete('/ideas/:id', requireAdmin, (req, res) => {
  db.prepare('DELETE FROM ideas WHERE id = ?').run(req.params.id);
  return res.json({ status: 'success', message: 'Idée supprimée.' });
});

// ═══════════════════════════════════════════════════════════════════════
// APPORTEURS (imprésarios / agences) & commissions — voir APPORTEURS.md.
// "Sous-dossier" = vue filtrée sur users.apporteur_id (pas de dossier figé).
// ═══════════════════════════════════════════════════════════════════════

// Code de parrainage unique (l'artiste le valide sur /rejoindre pour s'auto-
// rattacher). Basé sur la structure + un suffixe aléatoire, garanti unique.
function genApporteurCode(structure, name) {
  const base = String(structure || name || 'VYB').replace(/[^A-Za-z0-9]/g, '').toUpperCase().slice(0, 6) || 'VYB';
  for (let i = 0; i < 20; i++) {
    const code = `${base}${Math.floor(1000 + Math.random() * 9000)}`;
    if (!db.prepare('SELECT 1 FROM apporteurs WHERE code = ?').get(code)) return code;
  }
  return `${base}${Date.now() % 100000}`;
}

// Liste des apporteurs + nb d'artistes rattachés + total dû (non payé).
router.get('/apporteurs', requireAdmin, (req, res) => {
  const rows = db.prepare('SELECT * FROM apporteurs ORDER BY id DESC').all();
  const list = rows.map((a) => {
    const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE apporteur_id = ?').get(a.id).c;
    const due = db.prepare(
      "SELECT COALESCE(SUM(CAST(amount AS REAL)),0) s FROM apporteur_commissions WHERE apporteur_id = ? AND invoice_status != 'payée'"
    ).get(a.id).s;
    let params = {}; try { params = JSON.parse(a.deal_params || '{}'); } catch (_) { params = {}; }
    return { ...a, deal_params: params, artists_count: artists, due_total: Math.round(due * 100) / 100 };
  });
  return res.json({ status: 'success', count: list.length, list });
});

// Détail (page "agence") : deal + ses artistes + récap commissions.
router.get('/apporteurs/:id', requireAdmin, (req, res) => {
  const a = db.prepare('SELECT * FROM apporteurs WHERE id = ?').get(req.params.id);
  if (!a) return res.status(404).json({ status: 'error', message: 'Apporteur introuvable.' });
  let params = {}; try { params = JSON.parse(a.deal_params || '{}'); } catch (_) { params = {}; }
  const artists = db.prepare(
    `SELECT id, full_name, artist_name, artist_regime, apporteur_attached_at, sub_free_until, commission_end
     FROM users WHERE apporteur_id = ? ORDER BY id DESC`
  ).all(a.id);
  const s = db.prepare(
    `SELECT
       COALESCE(SUM(CASE WHEN invoice_status='due'      THEN CAST(amount AS REAL) ELSE 0 END),0) due,
       COALESCE(SUM(CASE WHEN invoice_status='exigible' THEN CAST(amount AS REAL) ELSE 0 END),0) exigible,
       COALESCE(SUM(CASE WHEN invoice_status='payée'    THEN CAST(amount AS REAL) ELSE 0 END),0) payee
     FROM apporteur_commissions WHERE apporteur_id = ?`
  ).get(a.id);
  const r2 = (n) => Math.round(n * 100) / 100;
  // Primes de signature (Pionnier / Fondateur) — liste + totaux par statut.
  const bonuses = db.prepare(
    `SELECT b.*, u.full_name, u.artist_name FROM apporteur_bonuses b
     LEFT JOIN users u ON u.id = b.artist_id WHERE b.apporteur_id = ? ORDER BY b.id DESC`
  ).all(a.id);
  const bs = db.prepare(
    `SELECT
       COALESCE(SUM(CASE WHEN status='due'      THEN CAST(amount AS REAL) ELSE 0 END),0) due,
       COALESCE(SUM(CASE WHEN status='exigible' THEN CAST(amount AS REAL) ELSE 0 END),0) exigible,
       COALESCE(SUM(CASE WHEN status='payée'    THEN CAST(amount AS REAL) ELSE 0 END),0) payee
     FROM apporteur_bonuses WHERE apporteur_id = ?`
  ).get(a.id);
  return res.json({ status: 'success', data: {
    apporteur: { ...a, deal_params: params },
    artists,
    commissions: { due: r2(s.due), exigible: r2(s.exigible), payee: r2(s.payee) },
    bonuses,
    bonuses_totals: { due: r2(bs.due), exigible: r2(bs.exigible), payee: r2(bs.payee) },
  }});
});

// Déclencher manuellement la prime Fondateur d'un artiste (encaissement de la
// 3e mensualité — à câbler auto sur le webhook d'abonnement ensuite).
router.post('/apporteurs/artist/:artistId/prime-fondateur', requireAdmin, (req, res) => {
  apporteurBonus.onFondateurThirdPayment(Number(req.params.artistId));
  return res.json({ status: 'success' });
});

// Statut de facturation d'une prime : due -> exigible -> payée.
router.post('/apporteur-bonuses/:id/status', requireAdmin, (req, res) => {
  const status = ['due', 'exigible', 'payée'].includes(req.body?.status) ? req.body.status : null;
  if (!status) return res.status(422).json({ status: 'error', message: 'Statut invalide.' });
  db.prepare('UPDATE apporteur_bonuses SET status = ? WHERE id = ?').run(status, req.params.id);
  return res.json({ status: 'success' });
});

// Créer un apporteur. body: name, structure, email, deal_type, deal_params.
router.post('/apporteurs', requireAdmin, (req, res) => {
  const b = req.body || {};
  if (!b.name) return res.status(422).json({ status: 'error', message: 'Le nom est requis.' });
  const dealType = ['simple', 'paliers', 'fixe_primes'].includes(b.deal_type) ? b.deal_type : 'simple';
  const params = typeof b.deal_params === 'string' ? b.deal_params : JSON.stringify(b.deal_params || {});
  const code = genApporteurCode(b.structure, b.name);
  const info = db.prepare(
    "INSERT INTO apporteurs (name, structure, email, deal_type, deal_params, status, code) VALUES (?, ?, ?, ?, ?, 'active', ?)"
  ).run(b.name, b.structure || null, b.email || null, dealType, params, code);
  return res.json({ status: 'success', data: { id: info.lastInsertRowid, code } });
});

// Régénérer le code de parrainage d'un apporteur.
router.post('/apporteurs/:id/regenerate-code', requireAdmin, (req, res) => {
  const a = db.prepare('SELECT structure, name FROM apporteurs WHERE id = ?').get(req.params.id);
  if (!a) return res.status(404).json({ status: 'error', message: 'Apporteur introuvable.' });
  const code = genApporteurCode(a.structure, a.name);
  db.prepare('UPDATE apporteurs SET code = ? WHERE id = ?').run(code, req.params.id);
  return res.json({ status: 'success', data: { code } });
});

// Modifier un apporteur (deal, statut active/suspended…).
router.post('/apporteurs/:id/update', requireAdmin, (req, res) => {
  const b = req.body || {};
  const a = db.prepare('SELECT * FROM apporteurs WHERE id = ?').get(req.params.id);
  if (!a) return res.status(404).json({ status: 'error', message: 'Apporteur introuvable.' });
  const dealType = ['simple', 'paliers', 'fixe_primes'].includes(b.deal_type) ? b.deal_type : a.deal_type;
  const params = b.deal_params != null
    ? (typeof b.deal_params === 'string' ? b.deal_params : JSON.stringify(b.deal_params))
    : a.deal_params;
  const status = ['active', 'suspended'].includes(b.status) ? b.status : a.status;
  db.prepare('UPDATE apporteurs SET name=?, structure=?, email=?, deal_type=?, deal_params=?, status=? WHERE id=?')
    .run(b.name ?? a.name, b.structure ?? a.structure, b.email ?? a.email, dealType, params, status, a.id);
  return res.json({ status: 'success' });
});

// Rattacher un artiste + démarrer ses compteurs (3 mois abo offert, 12 mois de
// commission par défaut — tous deux modifiables). body: artist_id, free_months,
// commission_months.
router.post('/apporteurs/:id/attach-artist', requireAdmin, (req, res) => {
  const b = req.body || {};
  const a = db.prepare('SELECT id FROM apporteurs WHERE id = ?').get(req.params.id);
  if (!a) return res.status(404).json({ status: 'error', message: 'Apporteur introuvable.' });
  const artist = db.prepare('SELECT id FROM users WHERE id = ?').get(b.artist_id);
  if (!artist) return res.status(404).json({ status: 'error', message: 'Artiste introuvable.' });
  const freeMonths = Number.isFinite(+b.free_months) ? +b.free_months : 3;
  const commMonths = Number.isFinite(+b.commission_months) ? +b.commission_months : 12;
  db.prepare(
    `UPDATE users SET apporteur_id = ?, apporteur_attached_at = datetime('now'),
        sub_free_until  = datetime('now', '+' || ? || ' months'),
        commission_end  = datetime('now', '+' || ? || ' months')
     WHERE id = ?`
  ).run(a.id, freeMonths, commMonths, artist.id);
  return res.json({ status: 'success' });
});

// Détacher un artiste : le rattachement se coupe SANS supprimer l'artiste.
router.post('/apporteurs/detach-artist', requireAdmin, (req, res) => {
  db.prepare('UPDATE users SET apporteur_id = NULL WHERE id = ?').run(req.body?.artist_id);
  return res.json({ status: 'success' });
});

// Renouveler / prolonger la période de commission d'un artiste (date modifiable).
router.post('/apporteurs/extend-commission', requireAdmin, (req, res) => {
  const months = Number.isFinite(+req.body?.months) ? +req.body.months : 12;
  db.prepare("UPDATE users SET commission_end = datetime('now', '+' || ? || ' months') WHERE id = ?")
    .run(months, req.body?.artist_id);
  return res.json({ status: 'success' });
});

// Régime d'un artiste (normal | pionnier | fondateur | parrain). Un PARRAIN
// (ex: Kassav') est exclu du calcul de commission apporteur.
router.post('/artist/:id/regime', requireAdmin, (req, res) => {
  const regime = ['normal', 'pionnier', 'fondateur', 'parrain'].includes(req.body?.regime) ? req.body.regime : 'normal';
  db.prepare('UPDATE users SET artist_regime = ? WHERE id = ?').run(regime, req.params.id);
  return res.json({ status: 'success' });
});

// Relevé mensuel d'un artiste (billets + tips + net). ?month=YYYY-MM (défaut : mois courant).
router.get('/artist/:id/statement', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: statements.artistStatement(req.params.id, req.query.month) });
});

// Relevé mensuel d'un apporteur (commissions + primes). ?month=YYYY-MM.
router.get('/apporteurs/:id/statement', requireAdmin, (req, res) => {
  return res.json({ status: 'success', data: statements.apporteurStatement(req.params.id, req.query.month) });
});

// Statut de facturation d'une commission : due -> exigible (facture reçue) -> payée.
router.post('/apporteur-commissions/:id/status', requireAdmin, (req, res) => {
  const status = ['due', 'exigible', 'payée'].includes(req.body?.status) ? req.body.status : null;
  if (!status) return res.status(422).json({ status: 'error', message: 'Statut invalide.' });
  db.prepare('UPDATE apporteur_commissions SET invoice_status = ? WHERE id = ?').run(status, req.params.id);
  return res.json({ status: 'success' });
});

module.exports = router;

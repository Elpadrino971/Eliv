'use strict';

/**
 * Sérialiseurs : transforment une ligne SQLite en l'objet JSON EXACT attendu
 * par les modèles Flutter (User.fromJson, Event.fromJson, …).
 * Toute divergence de nom de champ casserait le parsing côté app, donc on colle
 * au contrat existant (snake_case, types).
 */

const { db } = require('./db');

const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || 'https://api.vybzzz.online').replace(/\/+$/, '');

// Normalise une image de profil en URL ABSOLUE : garde les URLs http(s) telles
// quelles, préfixe les noms de fichiers nus (ex "beyonce.jpg") par /profiles/.
// null si vide. Évite que l'app reçoive un nom de fichier nu (qu'elle prend à
// tort pour un asset local -> avatar placeholder pour tout le monde).
function profileUrl(value) {
  if (!value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  return `${PUBLIC_BASE_URL}/profiles/${String(value).replace(/^\/+/, '')}`;
}

// Convertit une ligne `subscriptions` au format Subscription.fromJson (Flutter).
// Réutilisé par /api/subscription/get et par serializeUser (abonnement du user).
function subscriptionToJson(r) {
  if (!r) return null;
  const seatsTotal = r.slot_from != null && r.slot_to != null ? r.slot_to - r.slot_from + 1 : null;
  const perks = (r.perks || '')
    .split('\n')
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  return {
    id: r.id,
    title: r.name,
    price: r.price,
    price_type: r.period === 'year' ? 'yearly' : 'monthly',
    annual_price: r.price_annual || null,
    perks,
    commission_type: r.commission != null ? 'percentage' : null,
    commission: r.commission != null ? String(r.commission) : null,
    artists_count: null,
    status: r.active ? 'active' : 'inactive',
    created_at: r.created_at,
    updated_at: r.created_at,
    is_founder: (r.tier || '').toLowerCase() === 'founder',
    seats_total: seatsTotal,
    seats_remaining: seatsTotal,
    next_price: null,
    next_price_in_seats: null,
    public_price: null,
    badge: r.badge,
    iap_product_id: null,
    image: r.image,
  };
}

function serializeUser(row, { withPassword = false } = {}) {
  if (!row) return null;
  const genres = db
    .prepare(
      `SELECT g.* FROM genres g
       JOIN user_genres ug ON ug.genre_id = g.id
       WHERE ug.user_id = ?`
    )
    .all(row.id);

  const userSubscription = db
    .prepare(
      `SELECT us.id, us.user_id, us.subscriptions_id, us.status, us.start_date, us.end_date, us.created_at,
              s.name, s.tier, s.price, s.price_annual, s.period, s.active, s.image,
              s.slot_from, s.slot_to, s.commission, s.badge, s.perks, s.created_at AS sub_created_at
       FROM user_subscriptions us
       JOIN subscriptions s ON s.id = us.subscriptions_id
       WHERE us.user_id = ?
       ORDER BY us.id DESC`
    )
    .all(row.id)
    .map((us) => ({
      id: us.id,
      user_id: us.user_id,
      subscriptions_id: us.subscriptions_id,
      start_date: us.start_date,
      end_date: us.end_date,
      status: us.status,
      created_at: us.created_at,
      updated_at: us.created_at,
      subscription: subscriptionToJson({
        id: us.subscriptions_id, name: us.name, tier: us.tier, price: us.price,
        price_annual: us.price_annual, period: us.period, active: us.active, image: us.image,
        slot_from: us.slot_from, slot_to: us.slot_to, commission: us.commission, badge: us.badge,
        perks: us.perks, created_at: us.sub_created_at,
      }),
    }));

  const out = {
    id: row.id,
    email: row.email,
    phone_number: row.phone_number,
    // otp_code volontairement NON exposé : c'est un secret de vérification
    // serveur. serializeUser est renvoyé par des routes publiques
    // (/get-user, /featured-artists, activités…) -> ne jamais fuiter l'OTP.
    role: row.role,
    full_name: row.full_name,
    artist_name: row.artist_name,
    profile_image: profileUrl(row.profile_image),
    dob: row.dob,
    bio: row.bio,
    address: row.address,
    latitude: row.latitude,
    longitude: row.longitude,
    registration_type: row.registration_type,
    experience: row.experience,
    status: row.status,
    wallet: row.wallet,
    artist_bio: row.artist_bio,
    artist_profile: profileUrl(row.artist_profile),
    points: row.points,
    is_verified: row.is_verified,
    is_featured: !!row.is_featured,
    is_artist: !!row.is_artist,
    referral_code: row.referral_code,
    genres,
    user_subscription: userSubscription,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
  if (withPassword) out.password = row.password;
  return out;
}

function serializeEvent(row, { currentUserId = null } = {}) {
  if (!row) return null;

  const artist = db.prepare('SELECT * FROM users WHERE id = ?').get(row.artist_id);
  const genre = row.genre_id
    ? db.prepare('SELECT * FROM genres WHERE id = ?').get(row.genre_id)
    : null;

  const ticketRows = currentUserId
    ? db
        .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
        .all(row.id, currentUserId)
    : [];

  const buyerIds = db
    .prepare('SELECT DISTINCT user_id FROM tickets WHERE event_id = ?')
    .all(row.id)
    .map((r) => r.user_id);

  // ─── Fenetre de replay : configurable par event (défaut 60j) ───
  // L'artiste/l'admin choisit la durée (replay_duration_days, plafonnée à 60j =
  // fenêtre de hold Apple) et peut désactiver le replay (replay_enabled=0).
  // Au-dela de la fenetre — ou si le replay est desactive — le teaser gratuit
  // ET le replay paye s'arretent (meme flux Mux) : on ne renvoie plus l'ID/URL.
  const replayEnabled = row.replay_enabled === undefined || row.replay_enabled === null
    ? true
    : !!row.replay_enabled;
  let replayWindowDays = parseInt(row.replay_duration_days, 10);
  if (!Number.isFinite(replayWindowDays) || replayWindowDays < 1) replayWindowDays = 60;
  if (replayWindowDays > 60) replayWindowDays = 60;
  const referenceDate = row.end_date_time || row.start_date_time;
  const refTime = referenceDate ? new Date(referenceDate).getTime() : NaN;
  const replayExpiresAt = !isNaN(refTime)
    ? new Date(refTime + replayWindowDays * 24 * 60 * 60 * 1000).toISOString()
    : null;
  const replayExpired =
    !replayEnabled ||
    (replayExpiresAt !== null && row.status !== 'live' && Date.now() > new Date(replayExpiresAt).getTime());

  return {
    id: row.id,
    artist_id: row.artist_id,
    name: row.name,
    cover_image: row.cover_image,
    ticket_price: row.ticket_price,
    start_date_time: row.start_date_time,
    end_date_time: row.end_date_time,
    genre_id: row.genre_id,
    description: row.description,
    video_reel: replayExpired ? null : row.video_reel,
    is_private: row.is_private,
    has_live_chat: row.has_live_chat,
    capacity_limit: row.capacity_limit,
    status: row.status,
    link: row.link,
    joined_users_count: buyerIds.length,
    likes_count: row.likes_count,
    stream_key: row.stream_key,
    stream_url: row.stream_url,
    mux_playback_id: replayExpired ? null : row.mux_playback_id,
    mux_live_playback_id: row.mux_live_playback_id,
    replay_expires_at: replayExpiresAt,
    replay_expired: replayExpired,
    replay_enabled: replayEnabled,
    replay_duration_days: replayWindowDays,
    teaser_enabled: !!row.teaser_enabled,
    teaser_duration: row.teaser_duration,
    created_at: row.created_at,
    updated_at: row.updated_at,
    ticket_buyer_ids: buyerIds,
    genre,
    artist: serializeUser(artist),
    tickets: ticketRows.map(serializeTicket),
  };
}

function serializeTicket(row) {
  if (!row) return null;
  return {
    id: row.id,
    event_id: row.event_id,
    user_id: row.user_id,
    price_paid: row.price_paid,
    receipt_number: row.receipt_number,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

// Réponses standardisées (mêmes enveloppes que l'API actuelle)
function ok(res, data, extra = {}) {
  return res.json({ status: 'success', data, ...extra });
}
function list(res, key, rows) {
  return res.json({ status: 'success', [key]: rows });
}
function fail(res, message, code = 422, errors = null) {
  const body = { status: 'error', message };
  if (errors) body.errors = errors;
  return res.status(code).json(body);
}

function genReceipt() {
  const n = Math.floor(1000 + Math.random() * 9000);
  const m = Math.floor(1000 + Math.random() * 9000);
  return `VBZ-${n}-${m}`;
}

// Part ARTISTE par défaut (%) si l'artiste n'a pas d'abonnement / commission NULL.
// Cf. docs/founder_plan_api_spec.md (Starter 50 / Growth 60 / Elite 70 / Founder 60).
const DEFAULT_COMMISSION = 60;

// Taux de commission (= part artiste, en %) résolu depuis l'abonnement actif de
// l'artiste. Toujours calculé côté serveur, jamais fourni par le client.
function resolveArtistCommission(artistId) {
  if (!artistId) return DEFAULT_COMMISSION;
  const row = db
    .prepare(
      `SELECT s.commission FROM user_subscriptions us
       JOIN subscriptions s ON s.id = us.subscriptions_id
       WHERE us.user_id = ? AND us.status = 'active'
       ORDER BY us.id DESC LIMIT 1`
    )
    .get(artistId);
  const c = row && row.commission != null ? Number(row.commission) : DEFAULT_COMMISSION;
  if (!Number.isFinite(c)) return DEFAULT_COMMISSION;
  return Math.max(0, Math.min(100, c));
}

// Applique un taux (part artiste %) à un montant -> { artistShare, platformShare }
// arrondis à 2 décimales. Unité neutre (€ pour billets, points pour cadeaux).
function splitAmount(amount, rate) {
  const total = parseFloat(amount) || 0;
  const artistShare = Math.round(total * rate) / 100;
  const platformShare = Math.round((total - artistShare) * 100) / 100;
  return { artistShare, platformShare };
}

module.exports = {
  serializeUser,
  serializeEvent,
  serializeTicket,
  subscriptionToJson,
  ok,
  list,
  fail,
  genReceipt,
  resolveArtistCommission,
  splitAmount,
  DEFAULT_COMMISSION,
};

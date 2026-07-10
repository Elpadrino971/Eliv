'use strict';

/**
 * Sérialiseurs : transforment une ligne SQLite en l'objet JSON EXACT attendu
 * par les modèles Flutter (User.fromJson, Event.fromJson, …).
 * Toute divergence de nom de champ casserait le parsing côté app, donc on colle
 * au contrat existant (snake_case, types).
 */

const { db } = require('./db');

function serializeUser(row, { withPassword = false } = {}) {
  if (!row) return null;
  const genres = db
    .prepare(
      `SELECT g.* FROM genres g
       JOIN user_genres ug ON ug.genre_id = g.id
       WHERE ug.user_id = ?`
    )
    .all(row.id);

  const out = {
    id: row.id,
    email: row.email,
    phone_number: row.phone_number,
    otp_code: row.otp_code,
    role: row.role,
    full_name: row.full_name,
    artist_name: row.artist_name,
    profile_image: row.profile_image,
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
    artist_profile: row.artist_profile,
    points: row.points,
    is_verified: row.is_verified,
    is_featured: !!row.is_featured,
    is_artist: !!row.is_artist,
    referral_code: row.referral_code,
    genres,
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

  // ─── Fenetre de replay : 60 jours apres la fin du concert ───
  // Au-dela, le teaser gratuit ET le replay paye s'arretent tous les deux
  // (meme flux Mux pour les deux usages) : on ne renvoie plus l'ID/URL video.
  const REPLAY_WINDOW_DAYS = 60;
  const referenceDate = row.end_date_time || row.start_date_time;
  const refTime = referenceDate ? new Date(referenceDate).getTime() : NaN;
  const replayExpiresAt = !isNaN(refTime)
    ? new Date(refTime + REPLAY_WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString()
    : null;
  const replayExpired =
    replayExpiresAt !== null && row.status !== 'live' && Date.now() > new Date(replayExpiresAt).getTime();

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

module.exports = {
  serializeUser,
  serializeEvent,
  serializeTicket,
  ok,
  list,
  fail,
  genReceipt,
};

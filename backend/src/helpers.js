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
    // ID du produit d'abonnement (App Store / Play) — l'app l'utilise pour
    // lancer l'achat IAP par identifiant. Avant : hardcodé à null -> l'app ne
    // connaissait jamais le produit -> "Purchasing failed" (rejet Apple 2.1b).
    iap_product_id: r.revenuecat_product_id || null,
    image: r.image,
  };
}

// `full` = true seulement quand le row EST le viewer authentifié (ou l'admin) :
// email/téléphone/dob/adresse/géoloc/wallet/points sont des données privées et
// ne doivent JAMAIS être renvoyées quand on sérialise un AUTRE utilisateur
// (artiste vu depuis un event, liste de followers, artist_name en vedette…).
// Avant ce flag, ces routes publiques fuitaient wallet/email/téléphone de
// n'importe qui à partir de son seul id.
function serializeUser(row, { withPassword = false, full = false } = {}) {
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

  // Concert EN DIRECT de cet artiste (anneau "LIVE" + join direct depuis le
  // feed) : id du live + prix du billet. null si l'artiste n'est pas en live.
  const liveEvent = db
    .prepare("SELECT id, ticket_price FROM events WHERE artist_id = ? AND status = 'live' ORDER BY id DESC LIMIT 1")
    .get(row.id);

  const out = {
    id: row.id,
    // otp_code volontairement NON exposé : c'est un secret de vérification
    // serveur. serializeUser est renvoyé par des routes publiques
    // (/get-user, /featured-artists, activités…) -> ne jamais fuiter l'OTP.
    role: row.role,
    full_name: row.full_name,
    artist_name: row.artist_name,
    profile_image: profileUrl(row.profile_image),
    bio: row.bio,
    registration_type: row.registration_type,
    experience: row.experience,
    status: row.status,
    artist_bio: row.artist_bio,
    artist_profile: profileUrl(row.artist_profile),
    is_verified: row.is_verified,
    is_featured: !!row.is_featured,
    is_artist: !!row.is_artist,
    // Liens en bio (contact + réseaux), affichés/cliquables sur la fiche.
    contact_email: row.contact_email || null,
    link_website: row.link_website || null,
    link_instagram: row.link_instagram || null,
    link_tiktok: row.link_tiktok || null,
    link_youtube: row.link_youtube || null,
    link_spotify: row.link_spotify || null,
    is_live: !!liveEvent,
    live_event_id: liveEvent ? liveEvent.id : null,
    live_ticket_price: liveEvent ? liveEvent.ticket_price : null,
    referral_code: row.referral_code,
    genres,
    user_subscription: userSubscription,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
  if (full) {
    out.email = row.email;
    out.phone_number = row.phone_number;
    out.dob = row.dob;
    out.address = row.address;
    out.latitude = row.latitude;
    out.longitude = row.longitude;
    out.wallet = row.wallet;
    out.points = row.points;
  }
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
        // Un billet remboursé (Stripe/App Store) ne donne plus accès.
        .prepare("SELECT * FROM tickets WHERE event_id = ? AND user_id = ? AND COALESCE(status, 'active') <> 'refunded'")
        .all(row.id, currentUserId)
    : [];

  const buyerIds = db
    .prepare("SELECT DISTINCT user_id FROM tickets WHERE event_id = ? AND COALESCE(status, 'active') <> 'refunded'")
    .all(row.id)
    .map((r) => r.user_id);

  // Artistes invités (lot 7) : affichage « avec … » côté app. Le pourcentage
  // de partage est PRIVÉ (propriétaire/admin via GET /events/:id/guests).
  // Une requête par event, indexée (idx_event_guests_event).
  const guests = db
    .prepare(
      `SELECT g.user_id, u.artist_name, u.full_name, u.profile_image
         FROM event_guests g LEFT JOIN users u ON u.id = g.user_id
        WHERE g.event_id = ? ORDER BY g.id ASC`
    )
    .all(row.id)
    .map((g) => ({ user_id: g.user_id, artist_name: g.artist_name || g.full_name || null, profile_image: profileUrl(g.profile_image) }));

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

  // ─── Accès aux flux payants ───
  // Les URLs/IDs Mux (replay `stream.mux.com`, playback du live) donnaient
  // accès au concert à quiconque lisait la fiche, billet ou pas. Sur un event
  // payant, ils ne sont renvoyés qu'au détenteur d'un billet, à l'artiste ou
  // à un admin. Le teaser (video_reel qui n'est PAS une URL Mux) reste
  // public : il alimente le feed « Pour toi » et la bannière.
  // stream_key / stream_url (clé d'ingest RTMP) ne sortent plus jamais.
  const isPaid = (parseFloat(row.ticket_price) || 0) > 0;
  const hasTicket = ticketRows.length > 0;
  const isOwner = !!currentUserId && Number(currentUserId) === Number(row.artist_id);
  let isAdmin = false;
  if (currentUserId && !isOwner && !hasTicket && isPaid) {
    const viewer = db.prepare('SELECT role FROM users WHERE id = ?').get(currentUserId);
    isAdmin = !!viewer && viewer.role === 'admin';
  }
  const canWatch = !isPaid || hasTicket || isOwner || isAdmin;
  const isMuxUrl = (u) => typeof u === 'string' && /(^|\/\/)stream\.mux\.com\//i.test(u);
  const rawReel = replayExpired ? null : (row.video_reel || null);
  const rawPlayback = replayExpired ? null : (row.mux_playback_id || null);
  const rawLive = row.mux_live_playback_id || null;
  const hasReplay = !!(rawPlayback || isMuxUrl(rawReel));
  const videoReel = rawReel && isMuxUrl(rawReel) && !canWatch ? null : rawReel;

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
    video_reel: videoReel,
    is_private: row.is_private,
    has_live_chat: row.has_live_chat,
    capacity_limit: row.capacity_limit,
    status: row.status,
    link: row.link,
    joined_users_count: buyerIds.length,
    likes_count: row.likes_count,
    mux_playback_id: canWatch ? rawPlayback : null,
    mux_live_playback_id: canWatch ? rawLive : null,
    has_replay: hasReplay,
    has_ticket: hasTicket,
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
    guests,
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

// Enveloppe un handler async : une promesse rejetée part dans le middleware
// d'erreur d'Express au lieu de rester « unhandled » (et de faire tomber le
// process ou de laisser la requête sans réponse).
function asyncHandler(fn) {
  return function wrapped(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// E-mail masqué pour les journaux : `a***@domaine.tld`. On ne logge jamais
// une adresse en clair (RGPD + les logs partent parfois hors du serveur).
function maskEmail(email) {
  const e = String(email || '').trim();
  const at = e.indexOf('@');
  if (at < 1) return e ? '***' : '';
  return `${e[0]}***@${e.slice(at + 1)}`;
}

function genReceipt() {
  const n = Math.floor(1000 + Math.random() * 9000);
  const m = Math.floor(1000 + Math.random() * 9000);
  return `VBZ-${n}-${m}`;
}

// Part ARTISTE par défaut (%) sur le NET, modèle unifié « entrée gratuite » :
// 58,8 % du net → l'artiste garde ~50 % du brut quand les frais store sont à
// 15 %, et Vibe 41,2 % du net. Plus d'abonnement, plus de grille par tier.
// Surchargeable par env (DEFAULT_COMMISSION) sans redéploiement.
const DEFAULT_COMMISSION = Number(process.env.DEFAULT_COMMISSION) || 58.8;

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

// ─── OPRAS / portail apporteurs : compteurs plateforme + compte à rebours ───
// Compteurs agrégés (aucune donnée perso) affichés en exergue sur l'admin et
// sur la page apporteurs. « Artiste validé » = artiste ayant au moins un concert
// réellement tenu (statut live / completed / ended). Source unique de vérité :
// on lit la prod, on ne stocke aucun total recalculé à la main.
function platformCounters() {
  const users_total = db.prepare('SELECT COUNT(*) c FROM users').get().c;
  const fans = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'user' AND is_artist = 0").get().c;
  const artists = db.prepare('SELECT COUNT(*) c FROM users WHERE is_artist = 1').get().c;
  const validated_artists = db
    .prepare("SELECT COUNT(DISTINCT artist_id) c FROM events WHERE status IN ('live','completed','ended')")
    .get().c;
  return { users_total, fans, artists, validated_artists };
}

// Compte à rebours des 60 jours de hold avant le 1er paiement (reversement
// Apple). Départ configurable (défaut 20/08/2026). Calculé côté serveur pour
// rester la source de vérité ; l'UI n'a qu'à afficher/décompter.
const PAYOUT_START_ISO = process.env.PAYOUT_START_ISO || '2026-08-20T00:00:00Z';
const PAYOUT_HOLD_DAYS = parseInt(process.env.PAYOUT_HOLD_DAYS || '60', 10);
function payoutCountdown() {
  const start = new Date(PAYOUT_START_ISO).getTime();
  const holdDays = Number.isFinite(PAYOUT_HOLD_DAYS) ? PAYOUT_HOLD_DAYS : 60;
  const target = start + holdDays * 24 * 60 * 60 * 1000;
  const now = Date.now();
  const msLeft = Math.max(0, target - now);
  return {
    start_at: new Date(start).toISOString(),
    target_at: new Date(target).toISOString(),
    hold_days: holdDays,
    days_left: Math.ceil(msLeft / (24 * 60 * 60 * 1000)),
    reached: now >= target,
  };
}

// Géo-blocage : l'event est-il bloqué pour ce pays (ISO-2) à cet instant ?
// 'block' = bloque les pays listés ; 'only' = n'autorise QUE les pays listés.
// Blocage temporisé : passé geo_block_until, la diffusion repart seule.
function isGeoBlocked(event, country) {
  const mode = String(event?.geo_mode || 'off').toLowerCase();
  if (mode === 'off') return false;
  if (event?.geo_block_until) {
    const until = Date.parse(event.geo_block_until);
    if (!Number.isNaN(until) && Date.now() > until) return false;
  }
  const list = String(event?.geo_countries || '')
    .split(',')
    .map((c) => c.trim().toUpperCase())
    .filter(Boolean);
  if (list.length === 0) return false;
  const c = String(country || '').trim().toUpperCase();
  if (!c) return false; // pays inconnu -> soft (non bloqué)
  if (mode === 'block') return list.includes(c);
  if (mode === 'only') return !list.includes(c);
  return false;
}

module.exports = {
  profileUrl,
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
  platformCounters,
  payoutCountdown,
  isGeoBlocked,
  asyncHandler,
  maskEmail,
};

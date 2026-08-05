'use strict';

/**
 * Connexion SQLite + schéma. Le schéma reproduit les modèles Flutter
 * (user_model.dart, event_model.dart, gift_model.dart, …) en snake_case,
 * exactement comme les renvoie l'API actuelle.
 */

const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = process.env.VYBZZZ_DB || path.join(__dirname, '..', 'vybzzz.sqlite');
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function init() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE,
      password TEXT,
      phone_number TEXT,
      otp_code TEXT,
      role TEXT DEFAULT 'user',
      full_name TEXT,
      artist_name TEXT,
      profile_image TEXT,
      dob TEXT,
      bio TEXT,
      address TEXT,
      latitude TEXT,
      longitude TEXT,
      registration_type TEXT DEFAULT 'email',
      experience TEXT,
      status TEXT DEFAULT 'active',
      wallet TEXT DEFAULT '0',
      artist_bio TEXT,
      artist_profile TEXT,
      points TEXT DEFAULT '0',
      is_verified INTEGER DEFAULT 0,
      is_featured INTEGER DEFAULT 0,
      is_artist INTEGER DEFAULT 0,
      referral_code TEXT,
      referred_by INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS genres (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS user_genres (
      user_id INTEGER,
      genre_id INTEGER,
      PRIMARY KEY (user_id, genre_id)
    );

    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist_id INTEGER,
      name TEXT,
      cover_image TEXT,
      ticket_price TEXT DEFAULT '0',
      start_date_time TEXT,
      end_date_time TEXT,
      genre_id INTEGER,
      description TEXT,
      video_reel TEXT,
      is_private INTEGER DEFAULT 0,
      has_live_chat INTEGER DEFAULT 1,
      capacity_limit INTEGER,
      status TEXT DEFAULT 'published',
      link TEXT,
      likes_count INTEGER DEFAULT 0,
      stream_key TEXT,
      stream_url TEXT,
      mux_playback_id TEXT,
      mux_live_playback_id TEXT,
      teaser_enabled INTEGER DEFAULT 1,
      teaser_duration INTEGER DEFAULT 60,
      is_banner INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS tickets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER,
      user_id INTEGER,
      price_paid TEXT,
      receipt_number TEXT,
      status TEXT DEFAULT 'active',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS follows (
      follower_id INTEGER,
      artist_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (follower_id, artist_id)
    );

    CREATE TABLE IF NOT EXISTS gifts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      image TEXT,
      price TEXT DEFAULT '0',
      points TEXT DEFAULT '0',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS activities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      event_id INTEGER,
      type TEXT,
      description TEXT,
      points TEXT,
      gift TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT
    );

    CREATE TABLE IF NOT EXISTS abusive_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT
    );

    -- Features de la spec (BACKEND_CHANGES.md) : referral + ghost pass
    CREATE TABLE IF NOT EXISTS referrals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT,
      referrer_id INTEGER,
      referee_id INTEGER,
      status TEXT DEFAULT 'pending',
      reward TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS ghost_passes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      event_id INTEGER,
      duration_minutes INTEGER DEFAULT 10,
      expires_at TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS event_signals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER,
      user_id INTEGER,
      type TEXT,
      region TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Admin : Packages, Subscriptions, Reviews, Withdrawals, Contact Leads, FAQ, CMS
    CREATE TABLE IF NOT EXISTS packages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      points TEXT DEFAULT '0',
      price TEXT DEFAULT '0',
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      tier TEXT,
      price TEXT DEFAULT '0',
      period TEXT DEFAULT 'month',
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Clips des feeds "Pour toi" / "Clips" (contenu curaté, indépendant des
    -- concerts) : uploadés directement depuis l'admin, ou renseignés via un
    -- Mux Playback ID déjà existant. Aussi utilisée pour les soumissions
    -- utilisateur (user_id renseigné, active=0 tant que non validé par l'admin).
    CREATE TABLE IF NOT EXISTS feed_clips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed TEXT DEFAULT 'for_you',
      title TEXT,
      video_url TEXT,
      mux_playback_id TEXT,
      position INTEGER DEFAULT 0,
      active INTEGER DEFAULT 1,
      user_id INTEGER,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS reviews (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      event_id INTEGER,
      rating INTEGER DEFAULT 5,
      comment TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS withdrawals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      amount TEXT,
      status TEXT DEFAULT 'pending',
      bank TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS contact_leads (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT,
      phone TEXT,
      message TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS faqs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      question TEXT,
      answer TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS cms_pages (
      slug TEXT PRIMARY KEY,
      title TEXT,
      content TEXT,
      updated_at TEXT DEFAULT (datetime('now'))
    );

    -- Abonnements attribués à un utilisateur (grant manuel tant que le vrai
    -- achat RevenueCat/IAP n'écrit pas encore ici) : simule un abonné actif.
    CREATE TABLE IF NOT EXISTS user_subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      subscriptions_id INTEGER,
      status TEXT DEFAULT 'active',
      start_date TEXT DEFAULT (datetime('now')),
      end_date TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Boîte à idées (suggestions des utilisateurs/artistes)
    CREATE TABLE IF NOT EXISTS ideas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      name TEXT,
      email TEXT,
      category TEXT,
      message TEXT,
      status TEXT DEFAULT 'new',
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Comptes bancaires artiste (retrait des gains). Les routes /withdraw/*
    -- étaient des stubs qui ne persistaient jamais rien (add-bank répondait
    -- "success" sans écrire en base, get-user-banks renvoyait toujours []) :
    -- corrigé pour un vrai retrait d'argent avant la mise en prod.
    CREATE TABLE IF NOT EXISTS banks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      bank_name TEXT,
      account_name TEXT,
      account_number TEXT,
      swift_code TEXT,
      routing_number TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // Dédup des évènements RevenueCat (les webhooks sont ré-émis) : évite de
  // créditer deux fois des points pour le même achat consommable.
  db.exec(`
    CREATE TABLE IF NOT EXISTS rc_processed_events (
      event_id TEXT PRIMARY KEY,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // Registre des revenus : pour CHAQUE vente (billet / cadeau), on trace le
  // brut, la part artiste et la part plateforme + le taux appliqué. Source de
  // vérité pour la compta (part plateforme = revenu réel du fondateur, pas le
  // brut). Unité : 'ticket' en EUROS, 'gift' en POINTS (1 € = 100 pts).
  db.exec(`
    CREATE TABLE IF NOT EXISTS platform_earnings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist_id INTEGER,
      source TEXT,
      source_id INTEGER,
      gross TEXT,
      artist_share TEXT,
      platform_share TEXT,
      commission_rate INTEGER,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // ─── Migrations : colonnes ajoutées après coup (ignorées si déjà présentes) ───
  for (const sql of [
    // Split commissions : snapshot du taux + part artiste au moment de la vente
    // du billet (grandfathering : un changement de palier ne re-tarife pas le passé).
    "ALTER TABLE tickets ADD COLUMN commission_rate INTEGER",
    "ALTER TABLE tickets ADD COLUMN artist_share TEXT",
    // Packs de points (recharge portefeuille via IAP RevenueCat).
    "ALTER TABLE packages ADD COLUMN revenuecat_product_id TEXT",
    "ALTER TABLE packages ADD COLUMN active INTEGER DEFAULT 1",
    "ALTER TABLE subscriptions ADD COLUMN image TEXT",
    "ALTER TABLE subscriptions ADD COLUMN slot_from INTEGER",
    "ALTER TABLE subscriptions ADD COLUMN slot_to INTEGER",
    "ALTER TABLE packages ADD COLUMN image TEXT",
    "ALTER TABLE events ADD COLUMN tz_offset_minutes INTEGER DEFAULT 0",
    "ALTER TABLE subscriptions ADD COLUMN commission INTEGER",
    "ALTER TABLE subscriptions ADD COLUMN badge TEXT",
    "ALTER TABLE subscriptions ADD COLUMN perks TEXT",
    "ALTER TABLE subscriptions ADD COLUMN price_annual TEXT",
    "ALTER TABLE feed_clips ADD COLUMN user_id INTEGER",
    // Intégration Mux réelle (Direct Upload + Live Stream + expiration replay)
    "ALTER TABLE events ADD COLUMN mux_asset_id TEXT",
    "ALTER TABLE events ADD COLUMN mux_upload_id TEXT",
    "ALTER TABLE events ADD COLUMN mux_upload_status TEXT",
    "ALTER TABLE events ADD COLUMN replay_expires_at TEXT",
    "ALTER TABLE events ADD COLUMN mux_live_stream_id TEXT",
    "ALTER TABLE events ADD COLUMN mux_stream_key TEXT",
    // Replay : l'artiste (à la création) et l'admin choisissent si le concert
    // est rejouable et pour combien de jours (défaut 60j = fenêtre de hold des
    // fonds Apple/remboursement). replay_duration_days sert à calculer
    // replay_expires_at au moment où l'enregistrement Mux devient disponible.
    "ALTER TABLE events ADD COLUMN replay_enabled INTEGER DEFAULT 1",
    "ALTER TABLE events ADD COLUMN replay_duration_days INTEGER DEFAULT 60",
    "ALTER TABLE feed_clips ADD COLUMN mux_asset_id TEXT",
    "ALTER TABLE feed_clips ADD COLUMN mux_upload_id TEXT",
    "ALTER TABLE feed_clips ADD COLUMN upload_status TEXT",
    "ALTER TABLE feed_clips ADD COLUMN expires_at TEXT",
    // Stripe Checkout (paiement carte web, en plus de l'IAP) : Price ID
    // colle a la main dans l'admin (pas de creation auto depuis le backend,
    // pour eviter de dupliquer des objets Stripe a chaque edition).
    "ALTER TABLE subscriptions ADD COLUMN stripe_price_id TEXT",
    "ALTER TABLE subscriptions ADD COLUMN stripe_price_id_annual TEXT",
    "ALTER TABLE user_subscriptions ADD COLUMN stripe_customer_id TEXT",
    "ALTER TABLE user_subscriptions ADD COLUMN stripe_subscription_id TEXT",
    "ALTER TABLE user_subscriptions ADD COLUMN stripe_checkout_session_id TEXT",
    // RevenueCat (IAP App Store/Play Store) : product_id colle a la main
    // dans l'admin, meme logique que stripe_price_id.
    "ALTER TABLE subscriptions ADD COLUMN revenuecat_product_id TEXT",
    // Firebase Storage (clips feed, alternative légère à Mux pour les
    // vidéos courtes) : chemin dans le bucket, nécessaire pour la purge.
    "ALTER TABLE feed_clips ADD COLUMN firebase_path TEXT",
    // OTP réel (envoyé par email via Resend) : avant, otp_code valait
    // toujours '1234' pour tout le monde, sans expiration. Un vrai code
    // aléatoire doit expirer -> horodatage de validité.
    "ALTER TABLE users ADD COLUMN otp_expires_at TEXT",
    // Candidature artiste (contact_leads) : suivi + activation auto de
    // l'abonnement choisi par l'admin dès que le candidat crée son compte
    // (voir POST /admin/contact-leads/:id/approve et /sign-up).
    "ALTER TABLE contact_leads ADD COLUMN status TEXT DEFAULT 'pending'",
    "ALTER TABLE contact_leads ADD COLUMN approved_subscription_id INTEGER",
  ]) {
    try { db.exec(sql); } catch (e) { /* colonne déjà présente */ }
  }

  // Packs de points par défaut (1 € = 100 points). Chaque pack correspond à un
  // produit consommable IAP (App Store / Play Store) dont l'identifiant DOIT
  // matcher EXACTEMENT `packages.revenuecat_product_id` : le webhook RevenueCat
  // crédite les points via `WHERE revenuecat_product_id = ?`. Sans ce mapping,
  // un achat réussi ne crédite AUCUN point (échec silencieux, argent pris).
  // [name, points, price(€), revenuecat_product_id (= product_id du store)]
  const DEFAULT_PACKS = [
    ['Découverte', '100', '0.99', 'vybzz_points_100'],
    ['Fan', '500', '4.99', 'vybzz_points_500'],
    ['Super-fan', '1100', '9.99', 'vybzz_points_1100'],
    ['VIP', '2400', '19.99', 'vybzz_points_2400'],
    ['Légende', '6500', '49.99', 'vybzz_points_6500'],
  ];

  const packCount = db.prepare('SELECT COUNT(*) c FROM packages').get().c;
  if (packCount === 0) {
    // Base neuve : on insère les packs déjà mappés à leur produit IAP.
    const insPack = db.prepare(
      'INSERT INTO packages (name, points, price, active, revenuecat_product_id) VALUES (?, ?, ?, 1, ?)'
    );
    for (const [name, points, price, rcId] of DEFAULT_PACKS) {
      insPack.run(name, points, price, rcId);
    }
  } else {
    // Base existante (seedée avant l'ajout de la colonne) : on back-fill le
    // mapping IAP sur les packs canoniques UNIQUEMENT s'il est encore vide,
    // pour ne JAMAIS écraser un identifiant saisi à la main dans l'admin.
    const fillPack = db.prepare(
      `UPDATE packages SET revenuecat_product_id = ?
       WHERE points = ? AND (revenuecat_product_id IS NULL OR revenuecat_product_id = '')`
    );
    const backfill = db.transaction(() => {
      for (const [, points, , rcId] of DEFAULT_PACKS) fillPack.run(rcId, points);
    });
    backfill();
  }
}

module.exports = { db, init, DB_PATH };

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
  `);

  // ─── Migrations : colonnes ajoutées après coup (ignorées si déjà présentes) ───
  for (const sql of [
    "ALTER TABLE subscriptions ADD COLUMN image TEXT",
    "ALTER TABLE subscriptions ADD COLUMN slot_from INTEGER",
    "ALTER TABLE subscriptions ADD COLUMN slot_to INTEGER",
    "ALTER TABLE packages ADD COLUMN image TEXT",
    "ALTER TABLE events ADD COLUMN tz_offset_minutes INTEGER DEFAULT 0",
    "ALTER TABLE subscriptions ADD COLUMN commission INTEGER",
    "ALTER TABLE subscriptions ADD COLUMN badge TEXT",
    "ALTER TABLE subscriptions ADD COLUMN perks TEXT",
    "ALTER TABLE subscriptions ADD COLUMN price_annual TEXT",
  ]) {
    try { db.exec(sql); } catch (e) { /* colonne déjà présente */ }
  }
}

module.exports = { db, init, DB_PATH };

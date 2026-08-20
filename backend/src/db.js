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

    -- "Ma liste" (façon Netflix) : artistes qu'un user enregistre pour les
    -- retrouver vite. Distinct de "follows" (abonnement) : on peut mettre en
    -- liste sans suivre. Voir GET/POST /api/my-list.
    CREATE TABLE IF NOT EXISTS saved_artists (
      user_id INTEGER,
      artist_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, artist_id)
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

  // Modération automatique (Sightengine) : une ligne par détection (texte,
  // image, vidéo/replay, live). Sert de file de revue + piste d'audit ("VYBZZZ
  // dispose d'un système qui détecte ET journalise le contenu illégal").
  db.exec(`
    CREATE TABLE IF NOT EXISTS moderation_flags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      surface TEXT,           -- text | image | video | live
      target_type TEXT,       -- comment | event | clip | profile | live
      target_id TEXT,
      action TEXT,            -- review | block
      score REAL,
      categories TEXT,        -- JSON [{name,score}]
      extra TEXT,             -- JSON (URL, extrait de texte, position frame…)
      status TEXT DEFAULT 'open',  -- open | reviewed | dismissed
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // Signalements utilisateurs (bouton "Signaler" de l'app — exigence Apple 1.2
  // pour tout contenu généré par les utilisateurs). Avant, /report-event ne
  // persistait RIEN (réponse "success" à vide) : impossible de traiter un
  // signalement. Ici on garde une vraie file consultable/actionnable.
  db.exec(`
    CREATE TABLE IF NOT EXISTS content_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reporter_id INTEGER,
      target_type TEXT,       -- event | user | clip | comment
      target_id TEXT,
      reason TEXT,
      details TEXT,
      status TEXT DEFAULT 'open',  -- open | reviewed | actioned | dismissed
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // ─── Apporteurs (imprésarios / managers) & commissions ─── voir APPORTEURS.md.
  // Un apporteur amène des artistes et touche une commission sur LA PART
  // PLATEFORME NETTE de SES artistes. Le deal n'est PAS codé en dur : il vit en
  // config (deal_type + deal_params JSON) ; le moteur (services/apporteur.js)
  // ne fait que l'appliquer. Nouveau contrat = de la donnée, pas du code.
  db.exec(`
    CREATE TABLE IF NOT EXISTS apporteurs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,                 -- personne (ex: Ruddy Séverin)
      structure TEXT,            -- prod / agence (ex: Alizés Records)
      email TEXT,
      deal_type TEXT DEFAULT 'simple',   -- simple | paliers | fixe_primes
      deal_params TEXT DEFAULT '{}',     -- JSON (rate, tiers, floor/cap, duration_months…)
      status TEXT DEFAULT 'active',      -- active | suspended
      wallet TEXT DEFAULT '0',           -- cumul dû (info)
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Une ligne = une commission apporteur due sur une vente d'un de ses artistes.
    -- Payable quand encaissed=1 (fonds Apple reçus ~J+60) ET exigible quand
    -- invoice_status='exigible' (facture reçue). Assiette = platform_share (net).
    CREATE TABLE IF NOT EXISTS apporteur_commissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      apporteur_id INTEGER,
      artist_id INTEGER,
      source_type TEXT,          -- ticket | gift
      source_id INTEGER,
      gross TEXT, store TEXT, net TEXT, artist_share TEXT,
      platform_share TEXT,       -- l'assiette
      rate INTEGER,              -- % apporteur figé sur la ligne
      amount TEXT,               -- commission = platform_share × rate
      encaissed INTEGER DEFAULT 0,
      invoice_status TEXT DEFAULT 'due',  -- due | exigible | payée
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Primes fixes (ex Amandine : 150€ au 1er live, 300€ après 3 mensualités).
    CREATE TABLE IF NOT EXISTS apporteur_bonuses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      apporteur_id INTEGER,
      artist_id INTEGER,
      type TEXT,                 -- pionnier | fondateur | …
      amount TEXT,
      status TEXT DEFAULT 'due', -- due | exigible | payée
      triggered_at TEXT DEFAULT (datetime('now'))
    );

    -- Signalement artiste → apporteur (harcèlement / nuisance) : SUSPEND la
    -- commission sur cet artiste. La suspension ne vient QUE d'ici (trace),
    -- jamais d'une action manuelle sans trace. Le rattachement se coupe sans
    -- supprimer l'artiste (qui reste sur la plateforme).
    CREATE TABLE IF NOT EXISTS apporteur_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist_id INTEGER,
      apporteur_id INTEGER,
      reason TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // ─── Migrations : colonnes ajoutées après coup (ignorées si déjà présentes) ───
  for (const sql of [
    // Split commissions : snapshot du taux + part artiste au moment de la vente
    // du billet (grandfathering : un changement de palier ne re-tarife pas le passé).
    "ALTER TABLE tickets ADD COLUMN commission_rate INTEGER",
    "ALTER TABLE tickets ADD COLUMN artist_share TEXT",
    // ─── Apporteurs : rattachement + phase de l'artiste (voir APPORTEURS.md) ───
    "ALTER TABLE users ADD COLUMN apporteur_id INTEGER",           // 1 seul apporteur, nullable
    "ALTER TABLE users ADD COLUMN artist_regime TEXT DEFAULT 'normal'", // normal|pionnier|fondateur|parrain
    // Identifiant Apple stable (le token Apple ne renvoie l'email qu'à la 1re
    // connexion -> on retrouve le compte via ce 'sub' aux connexions suivantes).
    "ALTER TABLE users ADD COLUMN apple_sub TEXT",
    "ALTER TABLE users ADD COLUMN apporteur_attached_at TEXT",
    "ALTER TABLE users ADD COLUMN sub_free_until TEXT",            // fin des 3 mois d'abo offert
    "ALTER TABLE users ADD COLUMN commission_end TEXT",            // fin 12/24 mois (modifiable = renouvelable)
    "ALTER TABLE users ADD COLUMN taux_partage_artiste INTEGER",   // snapshot part artiste courante (info)
    "ALTER TABLE users ADD COLUMN first_live_at TEXT",             // 1er live (déclencheur prime Pionnier + départ des 24 mois)
    // Gating encaissement : le paiement de la commission ne s'active qu'une fois
    // les fonds Apple/Google réellement reçus (~J+60), pas à la vente.
    "ALTER TABLE tickets ADD COLUMN encaissed INTEGER DEFAULT 0",
    "ALTER TABLE tickets ADD COLUMN encaissed_at TEXT",
    // Reçu RevenueCat consommé pour ce billet (anti-rejeu : une transaction
    // d'achat ne peut donner qu'UN billet, même à prix égal sur 2 concerts).
    "ALTER TABLE tickets ADD COLUMN rc_transaction_id TEXT",
    // Unicité au niveau base : deux requêtes concurrentes ne peuvent pas
    // consommer le même reçu (double-crédit). Index partiel (ignore les NULL).
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_tickets_rc_txn ON tickets(rc_transaction_id) WHERE rc_transaction_id IS NOT NULL",
    // Traçage NET + part apporteur dans le ledger (part plateforme = ta marge réelle).
    "ALTER TABLE platform_earnings ADD COLUMN store_fee TEXT",
    "ALTER TABLE platform_earnings ADD COLUMN net TEXT",
    "ALTER TABLE platform_earnings ADD COLUMN apporteur_id INTEGER",
    "ALTER TABLE platform_earnings ADD COLUMN apporteur_amount TEXT",
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
    // Code de parrainage apporteur : l'artiste le valide (page /rejoindre) pour
    // être rattaché automatiquement à l'apporteur + démarrer l'offre (3 mois).
    "ALTER TABLE apporteurs ADD COLUMN code TEXT",
    // Back-fill des IDs produit d'abonnement App Store (rejet Apple 2.1b : sans
    // ID, l'achat d'abo échouait). On ne touche QUE les lignes encore vides,
    // par palier -> n'écrase jamais une valeur saisie en admin.
    "UPDATE subscriptions SET revenuecat_product_id = 'vybzz_79_1m' WHERE (revenuecat_product_id IS NULL OR revenuecat_product_id = '') AND lower(tier) = 'founder'",
    "UPDATE subscriptions SET revenuecat_product_id = 'vybzz_99_1m' WHERE (revenuecat_product_id IS NULL OR revenuecat_product_id = '') AND lower(tier) = 'starter'",
    "UPDATE subscriptions SET revenuecat_product_id = 'vybzz_199_1m' WHERE (revenuecat_product_id IS NULL OR revenuecat_product_id = '') AND lower(tier) = 'growth'",
    "UPDATE subscriptions SET revenuecat_product_id = 'vybzz_299_1m' WHERE (revenuecat_product_id IS NULL OR revenuecat_product_id = '') AND lower(tier) = 'elite'",
  ]) {
    try { db.exec(sql); } catch (e) { /* colonne déjà présente */ }
  }

  // Back-fill : un code unique pour tout apporteur qui n'en a pas encore.
  const genCode = (structure) => {
    const base = String(structure || 'VYB').replace(/[^A-Za-z0-9]/g, '').toUpperCase().slice(0, 6) || 'VYB';
    return `${base}${Math.floor(1000 + (Date.now() % 9000))}`;
  };
  try {
    const missing = db.prepare("SELECT id, structure, name FROM apporteurs WHERE code IS NULL OR code = ''").all();
    const setCode = db.prepare('UPDATE apporteurs SET code = ? WHERE id = ?');
    for (const ap of missing) {
      let code, tries = 0;
      do { code = genCode(ap.structure || ap.name); tries++; }
      while (db.prepare('SELECT 1 FROM apporteurs WHERE code = ?').get(code) && tries < 20);
      setCode.run(code, ap.id);
    }
  } catch (_) { /* table apporteurs pas encore présente au tout premier init */ }

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

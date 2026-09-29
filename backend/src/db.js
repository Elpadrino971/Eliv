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

    CREATE TABLE IF NOT EXISTS email_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipient TEXT,
      kind TEXT,
      ok INTEGER DEFAULT 0,
      error TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_email_log_date ON email_log (created_at);

    CREATE TABLE IF NOT EXISTS analytics_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      day TEXT,
      vid TEXT,
      path TEXT,
      name TEXT,
      ref TEXT,
      country TEXT,
      device TEXT,
      lang TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_analytics_day ON analytics_events (day, name);
    CREATE INDEX IF NOT EXISTS idx_analytics_path ON analytics_events (day, path);

    CREATE TABLE IF NOT EXISTS merch_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      description TEXT,
      price_eur REAL DEFAULT 0,
      image_url TEXT,
      buy_url TEXT,
      category TEXT DEFAULT 'textile',
      active INTEGER DEFAULT 0,
      sort INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS challenge_artists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT UNIQUE,
      email TEXT UNIQUE,
      stage_name TEXT,
      phone TEXT,
      genre TEXT,
      socials TEXT,
      user_id INTEGER,
      status TEXT DEFAULT 'active',
      accepted_rules INTEGER DEFAULT 0,
      adult INTEGER DEFAULT 0,
      ip TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS challenge_referrals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist_id INTEGER,
      email TEXT UNIQUE,
      name TEXT,
      user_id INTEGER,
      status TEXT DEFAULT 'pre',
      ip TEXT,
      ua TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      qualified_at DATETIME
    );

    CREATE TABLE IF NOT EXISTS challenge_clicks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist_id INTEGER,
      day TEXT,
      count INTEGER DEFAULT 0,
      UNIQUE(artist_id, day)
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

  // Clés API machine-à-machine (ex : Atelier -> VybzzZ). Le secret n'est JAMAIS
  // stocké en clair : seul son hash SHA-256 est conservé, et la clé complète
  // n'est montrée qu'une fois à la création.
  db.exec(`
    CREATE TABLE IF NOT EXISTS api_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      prefix TEXT,
      key_hash TEXT UNIQUE,
      active INTEGER DEFAULT 1,
      last_used_at TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // Chat live CENTRALISÉ (source de vérité chez nous, plus seulement chez Zego) :
  // l'app et la régie postent via /api/live/:eventId/messages, chaque message est
  // conservé ici puis relayé en SSE aux écrans Stage / Régie.
  db.exec(`
    CREATE TABLE IF NOT EXISTS live_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER,
      user_id INTEGER,
      name TEXT,
      text TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_live_messages_event ON live_messages(event_id, id);
  `);

  // Questions du public (Q&A live) : les fans posent, likent ; la plus likée
  // remonte sur le Stage (bandeau « question à répondre »). La régie peut
  // proposer une question, la mettre à l'écran (featured), la marquer répondue
  // ou la masquer. Un like par utilisateur et par question.
  db.exec(`
    CREATE TABLE IF NOT EXISTS live_questions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER,
      user_id INTEGER,
      name TEXT,
      text TEXT,
      likes INTEGER DEFAULT 0,
      status TEXT DEFAULT 'open',       -- open | featured | answered | hidden
      created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_live_questions_event ON live_questions(event_id, status, likes);
    CREATE TABLE IF NOT EXISTS live_question_likes (
      question_id INTEGER,
      user_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (question_id, user_id)
    );
  `);

  // Porteurs actuels des badges du mur de fans (par concert) — persistés pour
  // survivre à un redémarrage et appliquer la marge anti-clignotement.
  db.exec(`
    CREATE TABLE IF NOT EXISTS live_badge_state (
      event_id INTEGER,
      badge TEXT,                 -- top_supporter | best_tipper | vip
      user_id INTEGER,
      name TEXT,
      score REAL DEFAULT 0,
      updated_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (event_id, badge)
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
    CREATE TABLE IF NOT EXISTS user_blocks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      blocker_id INTEGER NOT NULL,
      blocked_id INTEGER NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(blocker_id, blocked_id)
    );
    CREATE INDEX IF NOT EXISTS idx_user_blocks ON user_blocks (blocker_id);

    -- Registre des mouvements de points du portefeuille. Jusqu'ici aucun
    -- mouvement n'etait enregistre : le solde etait mis a jour directement et
    -- l'historique renvoyait une liste vide en dur. Les depenses (cadeaux,
    -- billets) restent reconstituables depuis la table activities et la table tickets ; les
    -- recharges, elles, ne laissaient aucune trace -- d'ou cette table.
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      role TEXT NOT NULL DEFAULT 'points',  -- points | price
      direction TEXT NOT NULL,              -- credit | debit
      type TEXT,                            -- topup | gift | ticket | subscription
      title TEXT,
      description TEXT,
      amount TEXT NOT NULL DEFAULT '0',
      source TEXT,                          -- revenuecat | stripe | app
      source_id TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON wallet_transactions (user_id, created_at DESC);

    -- Support. Les routes /support/* repondaient « Ticket created. » sans rien
    -- ecrire : personne n'a jamais recu les messages envoyes depuis l'app, et
    -- la liste des tickets restait vide cote utilisateur.
    CREATE TABLE IF NOT EXISTS support_tickets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      subject TEXT,
      priority TEXT DEFAULT 'normal',
      status TEXT DEFAULT 'open',          -- open | resolved
      resolved_on TEXT,
      rating TEXT,
      review TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_support_user ON support_tickets (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS support_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      support_ticket_id INTEGER NOT NULL,
      user_id INTEGER,
      role TEXT DEFAULT 'user',            -- user | admin
      value TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_support_msg ON support_messages (support_ticket_id, id);

    -- Agenda regional : concerts et spectacles des Antilles-Guyane collectes
    -- sur des sources publiques (bizouk.com pour l'instant), afin que la
    -- timeline de l'application montre TOUT ce qui se passe et pas seulement
    -- les dates VybzzZ. Les evenements diffuses par VybzzZ restent distingues
    -- visuellement cote application.
    --
    -- On ne stocke que des faits : titre, date, lieu, territoire, et le lien
    -- vers la fiche d'origine. Aucune description n'est recopiee, et la source
    -- est citee et cliquable dans l'application.
    CREATE TABLE IF NOT EXISTS external_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,              -- bizouk
      source_id TEXT NOT NULL,           -- identifiant sur la source
      source_url TEXT NOT NULL,
      title TEXT NOT NULL,
      start_date TEXT,                   -- ISO 8601
      end_date TEXT,
      venue TEXT,
      city TEXT,
      postal_code TEXT,
      territory TEXT,                    -- GP | MQ | GF
      organizer TEXT,
      image TEXT,
      price_from TEXT,
      currency TEXT,
      status TEXT DEFAULT 'scheduled',   -- scheduled | cancelled | postponed
      hidden INTEGER DEFAULT 0,          -- masquage manuel depuis l'admin
      vybzzz_event_id INTEGER,           -- rapproche d'un concert VybzzZ, si diffusion
      -- Validation manuelle. TANT QUE CE DRAPEAU EST A 0 : pas de halo dore,
      -- et AUCUN prix n'est expose a l'application. Le tarif en presentiel
      -- n'est jamais renvoye au public : VybzzZ ne vend pas ces billets, et
      -- afficher le prix d'un guichet tiers n'aurait aucun sens.
      vybzzz_approved INTEGER DEFAULT 0,
      vybzzz_price TEXT,                 -- tarif VybzzZ, calcule puis modifiable
      vybzzz_discount INTEGER,           -- remise appliquee, en % (tracabilite)
      approved_at TEXT,
      last_seen_at TEXT,
      source_lastmod TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      UNIQUE(source, source_id)
    );
    CREATE INDEX IF NOT EXISTS idx_ext_events_date ON external_events (start_date);
    CREATE INDEX IF NOT EXISTS idx_ext_events_terr ON external_events (territory, start_date);

    -- Places attribuées à un e-mail qui n'a pas encore de compte VybzzZ (gain
    -- à la roue, achat sur le site). Elles deviennent de vrais billets dès que
    -- le compte est créé et vérifié avec ce même e-mail.
    CREATE TABLE IF NOT EXISTS pending_tickets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL,
      event_id INTEGER NOT NULL,
      price_paid TEXT DEFAULT '0',
      store_fee_rate REAL,
      source TEXT NOT NULL,             -- wheel | stripe
      ref TEXT NOT NULL,                -- id du tirage ou de la session Stripe
      ticket_id INTEGER,                -- rempli une fois le billet créé
      created_at TEXT DEFAULT (datetime('now')),
      granted_at TEXT,
      UNIQUE(source, ref)
    );
    CREATE INDEX IF NOT EXISTS idx_pending_tickets_email ON pending_tickets (email, granted_at);

    -- Roue de la fortune : un tirage par e-mail et par campagne, décidé côté
    -- serveur. Une place gagnée est réservée 24 h ; sans confirmation de
    -- l'e-mail, elle retourne dans le jeu.
    CREATE TABLE IF NOT EXISTS wheel_spins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      campaign TEXT NOT NULL,
      email TEXT NOT NULL,
      ip_hash TEXT,
      result TEXT NOT NULL,             -- win | lose
      status TEXT NOT NULL,             -- lost | reserved | claimed | granted | expired
      token TEXT UNIQUE,
      created_at TEXT DEFAULT (datetime('now')),
      claimed_at TEXT,
      granted_at TEXT,
      UNIQUE(campaign, email)
    );
    CREATE INDEX IF NOT EXISTS idx_wheel_campaign ON wheel_spins (campaign, result, status);

    -- Billetterie du site (Stripe) : une ligne par session de paiement.
    CREATE TABLE IF NOT EXISTS web_ticket_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      email TEXT NOT NULL,
      amount TEXT NOT NULL,
      currency TEXT DEFAULT 'eur',
      stripe_session_id TEXT UNIQUE,
      status TEXT DEFAULT 'pending',    -- pending | paid
      campaign TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      paid_at TEXT
    );

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

    -- ─── Module VIBE : Réunions + Objectifs + CRM artistes ───
    -- Outil interne (section admin "Réunions & CRM"). Piste les réunions
    -- (visio Jitsi intégrée), les objectifs par personne (jauges) et le
    -- pipeline de recrutement des artistes. Aucune donnée de capital ici.

    -- Personnes suivies en réunion / porteuses d'objectifs (équipe, associés,
    -- apporteurs). Table dédiée, distincte de users (app) et apporteurs.
    CREATE TABLE IF NOT EXISTS vibe_people (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      role TEXT DEFAULT 'associe',   -- admin | associe | equipe | apporteur
      email TEXT,
      color TEXT,                    -- couleur d'accent (jauges/avatars)
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Objectifs mesurables par personne (jauge = current/target).
    CREATE TABLE IF NOT EXISTS vibe_objectives (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person_id INTEGER,
      scope TEXT DEFAULT 'mensuel',  -- hebdo | mensuel | trimestriel
      title TEXT NOT NULL,
      metric_label TEXT,             -- ex "artistes signés"
      target_value REAL DEFAULT 0,
      current_value REAL DEFAULT 0,
      unit TEXT,                     -- ex "artistes", "€", "%"
      period_start TEXT,
      period_end TEXT,
      status TEXT DEFAULT 'en_cours',-- en_cours | atteint | manque
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Réunions (visio Jitsi intégrée ou lien externe collé).
    CREATE TABLE IF NOT EXISTS vibe_meetings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      type TEXT DEFAULT 'hebdo',     -- hebdo | mensuelle | comite | ponctuelle
      scheduled_at TEXT,
      status TEXT DEFAULT 'planifiee',-- planifiee | en_cours | terminee | annulee
      jitsi_room TEXT,               -- nom de salle Jitsi (visio intégrée)
      visio_url TEXT,                -- lien externe (Zoom/Meet) si utilisé
      summary_md TEXT,               -- notes / compte rendu
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- Tâches / actions décidées en réunion, assignées à une personne, avec
    -- rattachement optionnel à un artiste du CRM.
    CREATE TABLE IF NOT EXISTS vibe_actions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meeting_id INTEGER,
      assignee_id INTEGER,
      crm_id INTEGER,
      title TEXT NOT NULL,
      due_date TEXT,
      priority TEXT DEFAULT 'normale',-- basse | normale | haute | critique
      status TEXT DEFAULT 'a_faire', -- a_faire | en_cours | fait | bloque
      created_at TEXT DEFAULT (datetime('now'))
    );

    -- CRM : pipeline de recrutement des artistes (pionniers).
    CREATE TABLE IF NOT EXISTS vibe_crm (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT DEFAULT 'artiste',   -- artiste | manager | label | media
      stage_name TEXT,               -- nom de scène
      legal_name TEXT,
      email TEXT,
      phone TEXT,
      instagram TEXT,
      country TEXT,
      genre TEXT,
      followers_count INTEGER,
      referrer_id INTEGER,           -- apporteur (vibe_people.id)
      pipeline_stage TEXT DEFAULT 'a_qualifier',
        -- a_qualifier | contacte | en_discussion | negociation | contrat_envoye | signe | perdu | en_pause
      expected_value REAL,
      next_action_date TEXT,
      lost_reason TEXT,
      notes_md TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    -- Interactions CRM (appels, messages, RDV, issues de réunions).
    CREATE TABLE IF NOT EXISTS vibe_crm_interactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      crm_id INTEGER,
      meeting_id INTEGER,
      channel TEXT,                  -- appel | whatsapp | email | dm | rdv | reunion
      direction TEXT,                -- entrant | sortant
      occurred_at TEXT DEFAULT (datetime('now')),
      summary TEXT,
      outcome TEXT,                  -- positif | neutre | negatif | sans_reponse
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);

  // ─── Migrations : colonnes ajoutées après coup (ignorées si déjà présentes) ───
  for (const sql of [
    // Agenda régional : validation manuelle avant tout affichage de prix ou de halo.
    "ALTER TABLE external_events ADD COLUMN vybzzz_approved INTEGER DEFAULT 0",
    "ALTER TABLE external_events ADD COLUMN vybzzz_price TEXT",
    "ALTER TABLE external_events ADD COLUMN vybzzz_discount INTEGER",
    "ALTER TABLE external_events ADD COLUMN approved_at TEXT",
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
    "ALTER TABLE users ADD COLUMN country_code TEXT",              // pays ISO-2 capturé à la connexion (IP) ou déduit
    "ALTER TABLE users ADD COLUMN geo_lat REAL",                   // latitude approx. pour la carte admin
    "ALTER TABLE users ADD COLUMN geo_lon REAL",                   // longitude approx. pour la carte admin
    "ALTER TABLE users ADD COLUMN geo_at TEXT",                    // date de la dernière capture géo
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
    // Origine du billet (lot 4) : store | wheel | stripe | artist_gift. Avant,
    // elle n'était lisible qu'en décodant rc_transaction_id (`<source>:<ref>`).
    "ALTER TABLE tickets ADD COLUMN source TEXT",
    "CREATE INDEX IF NOT EXISTS idx_tickets_event_source ON tickets(event_id, source)",
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
    "ALTER TABLE events ADD COLUMN live_ends_at TEXT",                   // fin RÉELLE du live (ISO UTC), pilotée par la régie (chrono)
    // ─── Géo-blocage (par secteur) ───
    // geo_mode      : 'off' (défaut) | 'block' (bloque les pays listés) | 'only'
    // geo_countries : codes pays ISO-2 séparés par virgule (ex 'FR,GF')
    // geo_block_until : blocage TEMPORISÉ — tant que now < cette date le blocage
    //   s'applique, passé ce délai la diffusion repart seule. NULL = permanent.
    "ALTER TABLE events ADD COLUMN geo_mode TEXT DEFAULT 'off'",
    "ALTER TABLE events ADD COLUMN geo_countries TEXT",
    "ALTER TABLE events ADD COLUMN geo_block_until TEXT",
    // Tarification dynamique (lot 9) : paliers de prix JSON, du plus lointain
    // au plus proche du début, ex. [{"hours_before":72,"price":"4.99"},
    // {"hours_before":48,"price":"6.99"},{"hours_before":0,"price":"9.99"}].
    // NULL/[] = prix fixe (ticket_price). Voir services/pricing.js.
    "ALTER TABLE events ADD COLUMN price_schedule TEXT",
    "ALTER TABLE feed_clips ADD COLUMN mux_asset_id TEXT",
    "ALTER TABLE feed_clips ADD COLUMN mux_upload_id TEXT",
    "ALTER TABLE feed_clips ADD COLUMN upload_status TEXT",
    "ALTER TABLE feed_clips ADD COLUMN expires_at TEXT",
    "ALTER TABLE feed_clips ADD COLUMN views INTEGER DEFAULT 0",       // impressions dans le feed (stats API)
    "ALTER TABLE feed_clips ADD COLUMN likes INTEGER DEFAULT 0",       // likes (stats API)
    "ALTER TABLE feed_clips ADD COLUMN source TEXT",                   // ex: 'atelier' (origine de la publication)
    "ALTER TABLE feed_clips ADD COLUMN external_ref TEXT",             // id côté client (Atelier) pour idempotence
    "ALTER TABLE feed_clips ADD COLUMN api_key_id INTEGER",            // clé API ayant publié (scoping status/stats)
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
    // Compteur d'échecs de saisie du code : au 5e échec le code est invalidé
    // (un code à 6 chiffres se devine sinon en < 1 M d'essais).
    "ALTER TABLE users ADD COLUMN otp_attempts INTEGER DEFAULT 0",
    // Comptes "staff" (rôle role='staff') : accès admin RESTREINT à certains
    // modules seulement (CSV d'ids de modules, ex 'vibe'). Le super-admin
    // (role='admin') garde l'accès total. Vide/NULL = aucun accès.
    "ALTER TABLE users ADD COLUMN admin_scopes TEXT",
    // Liens en bio (façon TikTok) : contact + réseaux, affichés/cliquables sur
    // la fiche profil. Édités depuis l'app (update-profile).
    "ALTER TABLE users ADD COLUMN contact_email TEXT",
    "ALTER TABLE users ADD COLUMN link_website TEXT",
    "ALTER TABLE users ADD COLUMN link_instagram TEXT",
    "ALTER TABLE users ADD COLUMN link_tiktok TEXT",
    "ALTER TABLE users ADD COLUMN link_youtube TEXT",
    "ALTER TABLE users ADD COLUMN link_spotify TEXT",
    // Candidature artiste (contact_leads) : suivi + activation auto de
    // l'abonnement choisi par l'admin dès que le candidat crée son compte
    // (voir POST /admin/contact-leads/:id/approve et /sign-up).
    "ALTER TABLE contact_leads ADD COLUMN status TEXT DEFAULT 'pending'",
    "ALTER TABLE contact_leads ADD COLUMN approved_subscription_id INTEGER",
    // Signature du contrat depuis la page « postuler » (dessinée au doigt) :
    // image PNG (data URL), version du contrat acceptée, et horodatage.
    "ALTER TABLE contact_leads ADD COLUMN signature_data TEXT",
    "ALTER TABLE contact_leads ADD COLUMN contract_version TEXT",
    "ALTER TABLE contact_leads ADD COLUMN signed_at TEXT",
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

  // ─── Likes de concert : un like par utilisateur (avant : compteur libre,
  // incrémentable à l'infini sans compte). ───
  db.exec(`
    CREATE TABLE IF NOT EXISTS event_likes (
      event_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (event_id, user_id)
    );
  `);

  // ─── Artistes invités sur un concert (lot 7) : partage de LA PART ARTISTE.
  // share_pct = pourcentage de la part artiste (pas du prix) reversé à
  // l'invité ; Σ share_pct ≤ 100, le reste revient à l'artiste principal.
  // La répartition réelle est faite par services/revenue_split.js. ───
  try {
    db.exec(`
      CREATE TABLE IF NOT EXISTS event_guests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        share_pct REAL NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        UNIQUE (event_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_event_guests_event ON event_guests (event_id);
      CREATE INDEX IF NOT EXISTS idx_wallet_tx_source ON wallet_transactions (type, source_id);
    `);
  } catch (e) { console.warn('[db] migration event_guests ignorée :', e.message); }

  // ─── Index (requêtes chaudes le soir d'un concert) ───
  for (const sql of [
    'CREATE INDEX IF NOT EXISTS idx_activities_event ON activities (event_id, id)',
    'CREATE INDEX IF NOT EXISTS idx_follows_artist ON follows (artist_id)',
    'CREATE INDEX IF NOT EXISTS idx_follows_user ON follows (follower_id)',
    'CREATE INDEX IF NOT EXISTS idx_wheel_spins_ip ON wheel_spins (campaign, ip_hash)',
    'CREATE INDEX IF NOT EXISTS idx_web_ticket_orders_event ON web_ticket_orders (event_id)',
    'CREATE INDEX IF NOT EXISTS idx_pending_tickets_email_only ON pending_tickets (email)',
    'CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)',
  ]) {
    try { db.exec(sql); } catch (e) { console.warn('[db] index ignoré :', e.message); }
  }
  // tickets(event_id, user_id) : UNIQUE si aucune ligne en double (sinon
  // index simple, et on le signale pour nettoyage manuel).
  try {
    const dup = db.prepare(
      'SELECT event_id, user_id FROM tickets GROUP BY event_id, user_id HAVING COUNT(*) > 1 LIMIT 1'
    ).get();
    if (dup) {
      console.warn(`[db] billets en double (event ${dup.event_id}, user ${dup.user_id}) : index tickets(event_id,user_id) NON unique.`);
      db.exec('CREATE INDEX IF NOT EXISTS idx_tickets_event_user ON tickets (event_id, user_id)');
    } else {
      db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_tickets_event_user_uniq ON tickets (event_id, user_id)');
    }
  } catch (e) { console.warn('[db] index tickets ignoré :', e.message); }

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

  // ─── Seed module VIBE : personnes suivies + objectifs d'exemple ───
  // Ne s'exécute qu'une fois (base vide) : l'admin gère ensuite tout depuis
  // la section "Réunions & CRM". Les noms viennent du contexte projet.
  try {
    const vpCount = db.prepare('SELECT COUNT(*) c FROM vibe_people').get().c;
    if (vpCount === 0) {
      const insP = db.prepare('INSERT INTO vibe_people (name, role, color) VALUES (?, ?, ?)');
      const seedPeople = [
        ['Ruddy', 'associe', '#E6C76A'],
        ['Alain', 'associe', '#7ab8ff'],
        ['Frédéric', 'associe', '#8ce6a1'],
        ['Amandine', 'apporteur', '#ff9ec4'],
        ['Hammad', 'equipe', '#c9a3ff'],
      ];
      const ids = {};
      for (const [name, role, color] of seedPeople) {
        ids[name] = insP.run(name, role, color).lastInsertRowid;
      }
      // Objectifs d'exemple (jauges) — modifiables/supprimables dans l'admin.
      const insO = db.prepare(
        `INSERT INTO vibe_objectives (person_id, scope, title, metric_label, target_value, current_value, unit)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      );
      insO.run(ids['Ruddy'], 'mensuel', 'Artistes signés ce mois', 'artistes signés', 5, 2, 'artistes');
      insO.run(ids['Alain'], 'mensuel', 'Rendez-vous labels', 'RDV réalisés', 8, 3, 'RDV');
      insO.run(ids['Frédéric'], 'mensuel', 'Pipeline qualifié', 'artistes qualifiés', 12, 7, 'artistes');
      insO.run(ids['Amandine'], 'mensuel', 'Artistes apportés', 'artistes apportés', 6, 4, 'artistes');
      insO.run(ids['Hammad'], 'hebdo', 'Tickets tech livrés', 'tickets livrés', 10, 6, 'tickets');
    }
  } catch (_) { /* tables vibe pas encore présentes au tout premier init */ }

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

  // Boutique merch (print à la demande) : 4 produits d'exemple, INACTIFS tant
  // que le fournisseur d'impression n'est pas branché (lien d'achat vide).
  try {
    if (!db.prepare('SELECT 1 FROM merch_products LIMIT 1').get()) {
      const ins = db.prepare('INSERT INTO merch_products (name, description, price_eur, image_url, buy_url, category, active, sort) VALUES (?, ?, ?, ?, ?, ?, 0, ?)');
      const base = 'https://vybzzz.online/assets/merch/';
      ins.run('T-shirt « Live Begins Here »', 'Coton bio 180 g, coupe unisexe, logo brodé or sur bleu nuit. Tailles XS à 3XL.', 29, base + 'tshirt.jpg', '', 'textile', 1);
      ins.run('Hoodie VybzzZ', 'Sweat à capuche molletonné, bleu nuit, wordmark VybzzZ poitrine et « LIVE BEGINS HERE » dans le dos.', 59, base + 'hoodie.jpg', '', 'textile', 2);
      ins.run('Casquette V', 'Casquette brodée, emblème V doré, réglable.', 24, base + 'cap.jpg', '', 'accessoire', 3);
      ins.run('Affiche Live Challenge 2026', 'Affiche 50 × 70 cm, papier mat 200 g, édition du premier VybzzZ Live Challenge.', 19, base + 'poster.jpg', '', 'print', 4);
    }
  } catch (e) {
    console.warn('[db] seed merch ignoré :', e.message);
  }

  // Textes légaux de l'app (CGU, confidentialité, à propos, e-mail support) :
  // seedés UNIQUEMENT si la clé est absente ou vide, pour ne jamais écraser
  // une version éditée dans l'admin (Support & contenu → Textes légaux).
  try {
    const legal = require('./legal_texts');
    const getS = db.prepare('SELECT value FROM settings WHERE key = ?');
    const putS = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
    for (const key of ['privacy_policy', 'terms_and_conditions', 'about_us', 'support_email']) {
      const row = getS.get(key);
      if (!row || !String(row.value || '').trim()) putS.run(key, legal[key]);
    }
  } catch (e) {
    console.warn('[db] seed textes légaux ignoré :', e.message);
  }

  // Nouveaux cadeaux (visuels fournis) : ajoutés une seule fois, seulement si
  // le catalogue existe déjà et qu'ils n'y sont pas. Modifiables dans l'admin.
  try {
    if (db.prepare('SELECT COUNT(*) AS n FROM gifts').get().n > 0) {
      const has = db.prepare('SELECT 1 FROM gifts WHERE lower(image) = ?');
      const ins = db.prepare('INSERT INTO gifts (name, image, price, points) VALUES (?, ?, ?, ?)');
      [['Flamme', 'flamme.png', '3', '30'], ['Fusée', 'fusee.png', '30', '300']].forEach((g) => {
        if (!has.get(g[1])) ins.run(...g);
      });
    }
  } catch (e) {
    console.warn('[db] ajout des cadeaux ignoré :', e.message);
  }
}

module.exports = { db, init, DB_PATH };

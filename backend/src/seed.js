'use strict';

/**
 * Données de démo : artistes en vedette, events (live / à venir / passés / bannière)
 * avec les playback IDs Mux, gifts, genres, settings.
 * Lancement : `npm run seed`  (ou `npm run reset` pour repartir de zéro).
 */

const { db, init } = require('./db');
const { hash } = require('./auth');

// Playback IDs Mux des vidéos de démo. VIDES par défaut : à REMPLIR avec TES
// vidéos LIBRES DE DROITS uniquement (Pexels/Pixabay -> Mux « Create New Asset
// from URL »). Ne JAMAIS remettre de contenu copyrighté (clips YouTube, musique
// d'artistes réels) ici. Vide = event sans vidéo (cover seule), aucune lecture
// cassée.
// Vidéo des CONCERTS / bannière — format PAYSAGE (libre de droits, validée 200).
const MUX = {
  concert: 'l2JmgS1n7QrM5FcpDUuHhfHUhUmCTMktB0002QMj3hU5E',
};

// « Pour toi » (feed vertical) — clips format PORTRAIT (libres de droits, 200).
// Seedés dans la table feed_clips (source réelle du feed « Pour toi »).
const FOR_YOU = [
  'zEL9vcJceKsAd8xvXHTarwp7qi4o7p5Solf825iyKsU',
  'PjoGaoXHgc16PWgjUQBMJHUwj7o3zWtHQHWvUZPCfN00',
  'n01jJlZoi013PInBeQRXeZZDqE02x02vhO1pF8Z200kXiixc',
  'p6m5rIaZQGsSX51YijSB1GZo449uMpudt00JladxxQ6Y',
];

// ── Mots interdits (modération du chat des lives / commentaires) ──
// Liste FR + EN par catégories. Le filtre côté app fait une correspondance
// de MOT ENTIER (les expressions à espaces sont en sous-chaîne).
const ABUSIVE_WORDS = [
  // Insultes FR
  'con', 'conard', 'connard', 'connasse', 'conne', 'salope', 'salaud', 'pute',
  'putain', 'enculé', 'encule', 'enculer', 'batard', 'bâtard', 'ducon', 'abruti',
  'débile', 'crétin', 'ordure', 'raclure', 'pétasse', 'pouffiasse', 'grognasse',
  'trouduc', 'couillon', 'bouffon', 'nique', 'niquer', 'niqué', 'fdp', 'ntm', 'tg',
  'ta gueule', 'ferme ta gueule', 'va te faire foutre', 'fils de pute',
  // Insultes EN
  'fuck', 'fucking', 'fucker', 'motherfucker', 'shit', 'bitch', 'asshole',
  'bastard', 'dick', 'cunt', 'slut', 'whore', 'douche', 'wanker', 'prick',
  // Haine / discrimination (racisme, homophobie, validisme) — à bloquer
  'pd', 'pédé', 'pede', 'tapette', 'tarlouze', 'gouine', 'bougnoule', 'négro',
  'negro', 'nègre', 'bamboula', 'youpin', 'bicot', 'mongol', 'attardé',
  'sale arabe', 'sale juif', 'sale noir', 'sale blanc', 'sale pédé',
  'nigger', 'nigga', 'faggot', 'fag', 'retard', 'retarded', 'tranny',
  'chink', 'spic', 'kike', 'dyke', 'coon',
  // Sexuel / illégal
  'viol', 'violer', 'pédophile', 'pedophile', 'pédo', 'pedo', 'zoophile', 'rape',
  'child porn',
  // Menaces / automutilation
  'crève', 'creve', 'crever', 'tue-toi', 'va mourir', 'je vais te tuer',
  'suicide-toi', 'kill yourself', 'kys',
  // Spam / arnaque
  'arnaque', 'scam', 'spam', 'free money', 'argent facile', 'argent gratuit',
  'crypto gratuit', 'bitcoin gratuit', 'giveaway', 'clique ici', 'cliquez ici',
  'pump and dump',
];

/**
 * Données de RÉFÉRENCE (sans aucun compte ni concert fictif) : genres, cadeaux,
 * réglages, mots interdits, paliers d'abonnement, FAQ, pages CMS. Communes au
 * seed de démo et au seed de production. Renvoie les ids des genres.
 */
function seedReference() {
  const genres = ['Afrobeat', 'Pop', 'Hip-Hop', 'R&B', 'Dancehall', 'Electro'];
  const insGenre = db.prepare('INSERT INTO genres (name) VALUES (?)');
  const genreIds = genres.map((g) => insGenre.run(g).lastInsertRowid);

  const insGift = db.prepare('INSERT INTO gifts (name, image, price, points) VALUES (?, ?, ?, ?)');
  [
    ['Rose', 'rose.png', '1', '10'],
    ['Coeur', 'coeur.png', '2', '20'],
    ['Étoile', 'etoile.png', '5', '50'],
    ['Diamant', 'diamant.png', '10', '100'],
    ['Couronne', 'couronne.png', '20', '200'],
    ['Château', 'chateau.png', '50', '500'],
  ].forEach((g) => insGift.run(...g));

  const insSetting = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  insSetting.run('teaser_duration', '60');
  insSetting.run('currency', 'EUR');
  insSetting.run('min_withdraw', '50');
  insSetting.run('referral_rate', '10');
  insSetting.run('referral_monthly_cap', '10');

  const insWord = db.prepare('INSERT INTO abusive_words (word) VALUES (?)');
  ABUSIVE_WORDS.forEach((w) => insWord.run(w));

  // Paliers artistes (les packs de points sont posés par db.js à l'init).
  const insSub = db.prepare('INSERT INTO subscriptions (name, tier, price, period) VALUES (?, ?, ?, ?)');
  [
    ['Founder 79', 'founder', '79', 'year'],
    ['Starter', 'starter', '9.99', 'month'],
    ['Growth', 'growth', '29.99', 'month'],
    ['Elite', 'elite', '99.99', 'month'],
  ].forEach((sub) => insSub.run(...sub));

  const insFaq = db.prepare('INSERT INTO faqs (question, answer) VALUES (?, ?)');
  [
    ['Comment acheter un billet ?', 'Ouvre un concert puis appuie sur "Acheter un billet".'],
    ['Comment caster un concert ?', 'Depuis le lecteur, appuie sur l\'icône AirPlay en haut à droite.'],
    ['Comment devenir artiste ?', 'Va dans Profil → Devenir artiste et complète l\'onboarding.'],
  ].forEach((f) => insFaq.run(...f));

  const insCms = db.prepare('INSERT OR REPLACE INTO cms_pages (slug, title, content) VALUES (?, ?, ?)');
  insCms.run('terms', 'Conditions générales', 'Contenu des CGU VYBZZZ…');
  insCms.run('privacy', 'Politique de confidentialité', 'Contenu de la politique de confidentialité…');
  insCms.run('about', 'À propos', 'VYBZZZ — Live begins here.');

  return genreIds;
}

const ADMIN_EMAIL = (process.env.ADMIN_INITIAL_EMAIL || 'admin@vybzzz.com').trim().toLowerCase();
const ADMIN_PASSWORD_MIN = 12;

/**
 * Seed de PRODUCTION : données de référence + le seul compte admin, dont le
 * mot de passe vient de ADMIN_INITIAL_PASSWORD (>= 12 caractères). Aucun
 * compte fictif, aucun concert de démo. Lève une erreur claire sinon.
 */
function runProduction() {
  init();
  const pw = process.env.ADMIN_INITIAL_PASSWORD || '';
  if (pw.length < ADMIN_PASSWORD_MIN) {
    throw new Error(
      '[seed] base vide en production : définir ADMIN_INITIAL_PASSWORD (>= ' + ADMIN_PASSWORD_MIN +
      ' caractères) pour créer le compte admin (' + ADMIN_EMAIL + '). Aucun compte de démo n\'est créé en production.'
    );
  }
  seedReference();
  db.prepare(
    `INSERT INTO users (email, password, full_name, role, is_artist, is_verified, registration_type, referral_code)
     VALUES (?, ?, 'Admin VybzzZ', 'admin', 0, 1, 'email', 'ADMIN001')`
  ).run(ADMIN_EMAIL, hash(pw));
  console.log('[seed] production : données de référence + compte admin ' + ADMIN_EMAIL + ' (mot de passe : ADMIN_INITIAL_PASSWORD).');
}

function hls(id) {
  return id ? `https://stream.mux.com/${id}.m3u8` : null;
}

function daysFromNow(d, hour = 20) {
  const date = new Date();
  date.setDate(date.getDate() + d);
  date.setHours(hour, 30, 0, 0);
  return date.toISOString().replace('T', ' ').slice(0, 19);
}

function reset() {
  for (const t of [
    'user_genres', 'tickets', 'follows', 'activities', 'events', 'gifts',
    'genres', 'users', 'settings', 'abusive_words', 'referrals', 'ghost_passes', 'event_signals',
    'packages', 'subscriptions', 'user_subscriptions', 'reviews', 'withdrawals', 'contact_leads',
    'faqs', 'cms_pages', 'ideas',
    // feed_clips = clips « Pour toi » (contient les clips YouTube copyrightés
    // ajoutés via l'admin) -> à vider aussi pour repartir 100% propre.
    'feed_clips',
  ]) {
    db.exec(`DELETE FROM ${t};`);
  }
  // reset des AUTOINCREMENT
  db.exec("DELETE FROM sqlite_sequence;");
}

function run() {
  if (process.env.NODE_ENV === 'production' && !process.argv.includes('--force-demo')) {
    throw new Error('[seed] le seed de démo (comptes fictifs, mots de passe connus) est refusé en production. Utiliser runProduction() / ADMIN_INITIAL_PASSWORD.');
  }
  init();
  if (process.argv.includes('--reset')) reset();

  // ── Genres, cadeaux, réglages, mots interdits, paliers, FAQ, CMS ──
  const genreIds = seedReference();

  // ── Utilisateur de démo (pour se connecter) ──
  const insUser = db.prepare(
    `INSERT INTO users (email, password, full_name, role, is_artist, is_verified, registration_type, referral_code, address)
     VALUES (@email, @password, @full_name, @role, @is_artist, 1, 'email', @referral_code, @address)`
  );
  insUser.run({
    email: 'demo@vybzzz.com',
    password: hash('password'),
    full_name: 'Alex Gray',
    role: 'user',
    is_artist: 0,
    referral_code: 'ALEX1234',
    address: 'Paris, France',
  });

  // ── Compte ADMIN (dashboard web /admin) ──
  insUser.run({
    email: 'admin@vybzzz.com',
    password: hash('admin123'),
    full_name: 'Admin VYBZZZ',
    role: 'admin',
    is_artist: 0,
    referral_code: 'ADMIN001',
    address: 'Paris, France',
  });

  // ── Artistes en vedette ──
  const insArtist = db.prepare(
    `INSERT INTO users (email, password, full_name, artist_name, role, is_artist, is_featured, is_verified,
        artist_profile, profile_image, address, artist_bio)
     VALUES (@email, @password, @full_name, @artist_name, 'artist', 1, 1, 1,
        @artist_profile, @profile_image, @address, @artist_bio)`
  );
  // Artistes de démo 100% FICTIFS (aucune vraie célébrité -> pas d'usurpation
  // d'identité / image). Photos = null (pas de photo de vraie personne) : à
  // remplacer par des visuels libres de droits (Pexels/Unsplash) via l'admin.
  const artists = [
    { artist_name: 'Nova Sky',   full_name: 'Nadia Okoye',  address: 'Accor Arena, Paris', img: null },
    { artist_name: 'Echo Vale',  full_name: 'Emma Laurent', address: 'Zénith, Paris',      img: null },
    { artist_name: 'Kojo Flame', full_name: 'Kojo Mensah',  address: 'Stade de France',    img: null },
    { artist_name: 'Léo Sway',   full_name: 'Léo Marchand', address: 'Cayenne, Guyane',    img: null },
    { artist_name: 'Mira Lune',  full_name: 'Mira Dubois',  address: 'Le Dôme, Marseille', img: null },
  ];
  const artistIds = artists.map((a, i) =>
    insArtist.run({
      email: `artist${i + 1}@vybzzz.com`,
      password: hash('password'),
      full_name: a.full_name,
      artist_name: a.artist_name,
      artist_profile: a.img,
      profile_image: a.img,
      address: a.address,
      artist_bio: `${a.artist_name} — live on VYBZZZ.`,
    }).lastInsertRowid
  );

  // ── Events ──
  const insEvent = db.prepare(
    `INSERT INTO events (artist_id, name, cover_image, ticket_price, start_date_time, end_date_time,
        genre_id, description, video_reel, status, mux_playback_id, mux_live_playback_id, is_banner, likes_count)
     VALUES (@artist_id, @name, @cover_image, @ticket_price, @start, @end, @genre_id, @description,
        @video_reel, @status, @mux_playback_id, @mux_live_playback_id, @is_banner, @likes)`
  );

  // Events de démo fictifs. Prix alignés sur les paliers IAP (ticket_XX) : 19.99
  // -> 149.99. cover_image null = pas de photo de célébrité (à remplacer par des
  // visuels libres de droits). Vidéos = null tant que MUX n'est pas rempli
  // (aucune lecture cassée) -> statuts 'published' (pas de live vide).
  const events = [
    {
      artist_id: artistIds[0], name: 'Midnight Bloom Tour', cover_image: null, ticket_price: '49.99',
      start: daysFromNow(20), genre_id: genreIds[3], status: 'published',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 1, likes: 1240,
      description: 'Nova Sky — Midnight Bloom Tour, en direct sur VYBZZZ.',
    },
    {
      artist_id: artistIds[1], name: 'Aurora Live', cover_image: null, ticket_price: '39.99',
      start: daysFromNow(35), genre_id: genreIds[1], status: 'published',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 1, likes: 3120,
      description: 'Echo Vale — Aurora World Tour.',
    },
    {
      artist_id: artistIds[2], name: 'Afro Nation Night', cover_image: null, ticket_price: '29.99',
      start: daysFromNow(12), genre_id: genreIds[0], status: 'published',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 0, likes: 980,
      description: 'Kojo Flame en concert.',
    },
    {
      artist_id: artistIds[3], name: 'Guyane Vibes', cover_image: null, ticket_price: '19.99',
      start: daysFromNow(5), genre_id: genreIds[4], status: 'published',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 0, likes: 410,
      description: 'Léo Sway — Dancehall depuis Cayenne.',
    },
    {
      artist_id: artistIds[4], name: 'Neon Pulse', cover_image: null, ticket_price: '59.99',
      start: daysFromNow(8), genre_id: genreIds[5], status: 'published',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 0, likes: 1500,
      description: 'Mira Lune — set électro immersif.',
    },
    {
      artist_id: artistIds[0], name: 'First Light Premiere', cover_image: null, ticket_price: '29.99',
      start: daysFromNow(-15), end: daysFromNow(-15, 22), genre_id: genreIds[3], status: 'completed',
      video_reel: hls(MUX.concert), mux_playback_id: MUX.concert || null, is_banner: 0, likes: 2100,
      description: 'Nova Sky — replay disponible.',
    },
  ];
  const eventIds = events.map((e) =>
    insEvent.run({
      artist_id: e.artist_id, name: e.name, cover_image: e.cover_image, ticket_price: e.ticket_price,
      start: e.start, end: e.end || null, genre_id: e.genre_id, description: e.description,
      video_reel: e.video_reel, status: e.status, mux_playback_id: e.mux_playback_id || null,
      mux_live_playback_id: e.mux_live_playback_id || null, is_banner: e.is_banner, likes: e.likes,
    }).lastInsertRowid
  );

  // ── « Pour toi » : clips PORTRAIT libres de droits (source réelle du feed) ──
  const insFeedClip = db.prepare(
    "INSERT INTO feed_clips (feed, title, mux_playback_id, position, active) VALUES ('for_you', ?, ?, ?, 1)"
  );
  FOR_YOU.forEach((id, i) => insFeedClip.run(`Découverte ${i + 1}`, id, i));

  const insSetting = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');

  // ── User Genres (associations user ↔ genre) ──
  const allUserIds = db.prepare("SELECT id FROM users WHERE role != 'admin'").all().map((r) => r.id);
  const insUG = db.prepare('INSERT OR IGNORE INTO user_genres (user_id, genre_id) VALUES (?, ?)');
  allUserIds.forEach((uid, i) => {
    insUG.run(uid, genreIds[i % genreIds.length]);
    insUG.run(uid, genreIds[(i + 1) % genreIds.length]);
  });

  // ── Packages (points) ──
  // Packs alignés sur les produits IAP (revenuecat_product_id) — cohérent avec
  // le seed runtime de db.js, pour qu'un reset ne casse pas le crédit de points.
  const insPkg = db.prepare('INSERT INTO packages (name, points, price, revenuecat_product_id) VALUES (?, ?, ?, ?)');
  [
    ['Découverte', '100', '0.99', 'vybzz_points_100'],
    ['Fan', '500', '4.99', 'vybzz_points_500'],
    ['Super-fan', '1100', '9.99', 'vybzz_points_1100'],
    ['VIP', '2400', '19.99', 'vybzz_points_2400'],
    ['Légende', '6500', '49.99', 'vybzz_points_6500'],
  ].forEach((p) => insPkg.run(...p));

  // ── Reviews ──
  const insReview = db.prepare('INSERT INTO reviews (user_id, event_id, rating, comment) VALUES (?, ?, ?, ?)');
  [
    [allUserIds[0], eventIds[0], 5, 'Concert incroyable, son parfait !'],
    [allUserIds[0], eventIds[1], 4, 'Très bonne expérience live.'],
    [allUserIds[0], eventIds[3], 5, 'Le live Mux est top.'],
  ].forEach((r) => insReview.run(...r));

  // ── Withdrawals ──
  const insWd = db.prepare('INSERT INTO withdrawals (user_id, amount, status, bank) VALUES (?, ?, ?, ?)');
  [
    [artistIds[0], '1200', 'pending', 'IBAN ****1234'],
    [artistIds[1], '850', 'approved', 'IBAN ****5678'],
    [artistIds[3], '430', 'rejected', 'IBAN ****9012'],
  ].forEach((w) => insWd.run(...w));

  // ── Contact Leads ──
  const insLead = db.prepare('INSERT INTO contact_leads (name, email, phone, message) VALUES (?, ?, ?, ?)');
  [
    ['Marie Dupont', 'marie@example.com', '+33600000001', 'Comment devenir artiste sur VYBZZZ ?'],
    ['John Smith', 'john@example.com', '+33600000002', 'Partenariat possible ?'],
  ].forEach((l) => insLead.run(...l));

  // ── Parrainages de démo ──
  const insRef = db.prepare(
    'INSERT INTO referrals (code, referrer_id, referee_id, status, reward) VALUES (?, ?, ?, ?, ?)'
  );
  insRef.run('NOVA1234', artistIds[0], artistIds[1], 'validated', '10%');
  insRef.run('NOVA1234', artistIds[0], artistIds[2], 'validated', '10%');
  insRef.run('ECHO5678', artistIds[1], artistIds[3], 'pending', '10%');

  // ── Fans + billets répartis sur 6 mois (pour revenus & graphiques) ──
  const insFan = db.prepare(
    `INSERT INTO users (email, password, full_name, role, is_artist, is_verified, registration_type, referral_code, address)
     VALUES (?, ?, ?, 'user', 0, 1, 'email', ?, ?)`
  );
  const fanIds = [];
  const cities = ['Paris', 'Cayenne', 'Lyon', 'Pointe-à-Pitre', 'Marseille', 'Kourou'];
  for (let i = 1; i <= 14; i++) {
    fanIds.push(insFan.run(`fan${i}@vybzzz.com`, hash('password'), `Fan ${i}`, `FAN${1000 + i}`, cities[i % cities.length]).lastInsertRowid);
  }

  // OR IGNORE : tickets(event_id, user_id) est unique, un même fan tiré deux
  // fois pour le même concert ne doit pas faire échouer le seed.
  const insTicket = db.prepare(
    `INSERT OR IGNORE INTO tickets (event_id, user_id, price_paid, receipt_number, status, created_at)
     VALUES (?, ?, ?, ?, 'active', ?)`
  );
  const dAgo = (d) => { const dt = new Date(); dt.setDate(dt.getDate() - d); return dt.toISOString().replace('T', ' ').slice(0, 19); };
  let rec = 1000;
  events.forEach((ev, idx) => {
    const n = 4 + Math.floor(Math.random() * 9); // 4 à 12 billets / concert
    for (let k = 0; k < n; k++) {
      const fan = fanIds[Math.floor(Math.random() * fanIds.length)];
      insTicket.run(eventIds[idx], fan, ev.ticket_price, `VBZ-${rec++}-${1000 + k}`, dAgo(Math.floor(Math.random() * 175)));
    }
  });

  // ── Boîte à idées (suggestions de démo) ──
  const insIdea = db.prepare('INSERT INTO ideas (user_id, name, email, category, message, status) VALUES (?, ?, ?, ?, ?, ?)');
  insIdea.run(fanIds[0], 'Fan 1', 'fan1@vybzzz.com', 'Fonctionnalité', 'Ajouter un mode hors-ligne pour réécouter les concerts.', 'new');
  insIdea.run(artistIds[0], 'Nova Sky', 'artist1@vybzzz.com', 'Artiste', 'Pouvoir programmer un live à l\'avance avec un compte à rebours.', 'reviewed');
  insIdea.run(fanIds[2], 'Fan 3', 'fan3@vybzzz.com', 'Cadeaux', 'Plus de cadeaux animés pendant les lives !', 'new');

  // ── Objectifs (CA, users, artistes) — éditables dans l'admin ──
  insSetting.run('goal_revenue', '50000');
  insSetting.run('goal_users', '500');
  insSetting.run('goal_artists', '50');

  console.log('[seed] OK :',
    `${genreIds.length} genres, ${artistIds.length} artistes, ${eventIds.length} events, 6 gifts.`);
  console.log('[seed] Compte démo : demo@vybzzz.com / password');
}

if (require.main === module) {
  run();
  console.log('[seed] terminé.');
}

module.exports = { run, runProduction, seedReference, reset, ADMIN_EMAIL };

'use strict';

/**
 * Données de démo : artistes en vedette, events (live / à venir / passés / bannière)
 * avec les playback IDs Mux, gifts, genres, settings.
 * Lancement : `npm run seed`  (ou `npm run reset` pour repartir de zéro).
 */

const { db, init } = require('./db');
const { hash } = require('./auth');

// Playback IDs Mux repris de lib/Global/api.dart (publics, pas des secrets)
const MUX = {
  clipLouis: '01c02msAhj7ug800qbzrvHkTNx4JZn79TBsCC8xtV7tc5k',
  krys: 'sdsKbwNQ5UxSJhyUC9aBhM1m9kVQsJuKxGaBsMpI01VU',
  ytdown: 'MW3Ts7Jng66mhzjyUg4AGqQ9ow9yqjgwUI003lSPRLag',
  live: '801JS1xqX3AfFn8nWo3ISZUUdeW01402569WQXowjZojYg',
};

function hls(id) {
  return `https://stream.mux.com/${id}.m3u8`;
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
  ]) {
    db.exec(`DELETE FROM ${t};`);
  }
  // reset des AUTOINCREMENT
  db.exec("DELETE FROM sqlite_sequence;");
}

function run() {
  init();
  if (process.argv.includes('--reset')) reset();

  // ── Genres ──
  const genres = ['Afrobeat', 'Pop', 'Hip-Hop', 'R&B', 'Dancehall', 'Electro'];
  const insGenre = db.prepare('INSERT INTO genres (name) VALUES (?)');
  const genreIds = genres.map((g) => insGenre.run(g).lastInsertRowid);

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

  // ── Artistes en vedette ──
  const insArtist = db.prepare(
    `INSERT INTO users (email, password, full_name, artist_name, role, is_artist, is_featured, is_verified,
        artist_profile, profile_image, address, artist_bio)
     VALUES (@email, @password, @full_name, @artist_name, 'artist', 1, 1, 1,
        @artist_profile, @profile_image, @address, @artist_bio)`
  );
  const artists = [
    { artist_name: 'The Weeknd', full_name: 'Abel Tesfaye', address: 'Accor Arena, Paris', img: 'weeknd.jpg' },
    { artist_name: 'Beyoncé', full_name: 'Beyoncé Knowles', address: 'Stade de France', img: 'beyonce.jpg' },
    { artist_name: 'Billie Eilish', full_name: 'Billie Eilish', address: 'Accor Arena, Paris', img: 'billie.jpg' },
    { artist_name: 'Burna Boy', full_name: 'Damini Ogulu', address: 'Zénith, Paris', img: 'burna.jpg' },
    { artist_name: 'KRYS', full_name: 'Krys', address: 'Cayenne, Guyane', img: 'krys.jpg' },
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

  const events = [
    {
      artist_id: artistIds[0], name: 'After Hours Tour', cover_image: 'weeknd.jpg', ticket_price: '560',
      start: daysFromNow(20), genre_id: genreIds[3], status: 'published',
      video_reel: hls(MUX.clipLouis), mux_playback_id: MUX.clipLouis, is_banner: 1, likes: 1240,
      description: 'The Weeknd — After Hours Tour, en direct sur VYBZZZ.',
    },
    {
      artist_id: artistIds[1], name: 'Renaissance Live', cover_image: 'beyonce.jpg', ticket_price: '720',
      start: daysFromNow(35), genre_id: genreIds[1], status: 'published',
      video_reel: hls(MUX.ytdown), mux_playback_id: MUX.ytdown, is_banner: 1, likes: 3120,
      description: 'Beyoncé — Renaissance World Tour.',
    },
    {
      artist_id: artistIds[2], name: 'Happier Than Ever', cover_image: 'billie.jpg', ticket_price: '480',
      start: daysFromNow(12), genre_id: genreIds[1], status: 'published',
      video_reel: hls(MUX.krys), mux_playback_id: MUX.krys, is_banner: 0, likes: 980,
      description: 'Billie Eilish en concert.',
    },
    {
      artist_id: artistIds[3], name: 'Afro Nation Night', cover_image: 'burna.jpg', ticket_price: '390',
      start: daysFromNow(0, new Date().getHours()), genre_id: genreIds[0], status: 'live',
      video_reel: hls(MUX.live), mux_playback_id: MUX.live, mux_live_playback_id: MUX.live, is_banner: 0, likes: 5400,
      description: 'Burna Boy — LIVE maintenant.',
    },
    {
      artist_id: artistIds[4], name: 'Guyane Vibes', cover_image: 'krys.jpg', ticket_price: '150',
      start: daysFromNow(2, 19), genre_id: genreIds[4], status: 'published',
      video_reel: hls(MUX.krys), mux_playback_id: MUX.krys, is_banner: 0, likes: 410,
      description: 'KRYS — Dancehall live depuis Cayenne.',
    },
    {
      artist_id: artistIds[0], name: 'Dawn FM Premiere', cover_image: 'weeknd.jpg', ticket_price: '300',
      start: daysFromNow(-15), end: daysFromNow(-15, 22), genre_id: genreIds[3], status: 'completed',
      video_reel: hls(MUX.clipLouis), mux_playback_id: MUX.clipLouis, is_banner: 0, likes: 2100,
      description: 'Replay disponible.',
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

  // ── Gifts ──
  const insGift = db.prepare('INSERT INTO gifts (name, image, price, points) VALUES (?, ?, ?, ?)');
  [
    ['Rose', 'rose.png', '1', '10'],
    ['Coeur', 'coeur.png', '2', '20'],
    ['Étoile', 'etoile.png', '5', '50'],
    ['Diamant', 'diamant.png', '10', '100'],
    ['Couronne', 'couronne.png', '20', '200'],
    ['Château', 'chateau.png', '50', '500'],
  ].forEach((g) => insGift.run(...g));

  // ── Settings ──
  const insSetting = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  insSetting.run('teaser_duration', '60');
  insSetting.run('currency', 'EUR');
  insSetting.run('min_withdraw', '50');

  // ── Mots interdits ──
  const insWord = db.prepare('INSERT INTO abusive_words (word) VALUES (?)');
  ['spam', 'scam', 'insulte'].forEach((w) => insWord.run(w));

  console.log('[seed] OK :',
    `${genreIds.length} genres, ${artistIds.length} artistes, ${eventIds.length} events, 6 gifts.`);
  console.log('[seed] Compte démo : demo@vybzzz.com / password');
}

if (require.main === module) {
  run();
  console.log('[seed] terminé.');
}

module.exports = { run, reset };

'use strict';

/**
 * Remplit la grille "façon TikTok" des fiches artistes avec du contenu de démo.
 *
 * Pour chaque artiste (is_artist=1) qui n'a encore AUCUNE vidéo, on lui crée
 * quelques feed_clips en réutilisant les Playback IDs Mux déjà présents (donc de
 * VRAIES miniatures s'affichent, pas des aplats). Les clips officiels d'origine
 * ne sont pas touchés (on crée de nouvelles lignes rattachées à l'artiste).
 *
 * Idempotent : un artiste qui a déjà des vidéos est ignoré.
 *
 * Lancer dans le conteneur backend :
 *   docker exec vybzzz node scripts/fill-demo-clips.js
 * (le conteneur a déjà VYBZZZ_DB=/data/vybzzz.sqlite dans son env)
 */

const { db } = require('../src/db');

const artists = db
  .prepare(
    "SELECT id, COALESCE(artist_name, full_name, email) AS name FROM users WHERE is_artist = 1"
  )
  .all();

const sources = db
  .prepare(
    "SELECT mux_playback_id, title FROM feed_clips WHERE mux_playback_id IS NOT NULL AND mux_playback_id <> '' AND active = 1 ORDER BY id DESC LIMIT 9"
  )
  .all();

if (artists.length === 0) {
  console.log('Aucun artiste (is_artist=1) en base. Rien à faire.');
  process.exit(0);
}
if (sources.length === 0) {
  console.log(
    'Aucun clip Mux source (mux_playback_id) à réutiliser. Ajoute au moins un clip Mux dans l’admin, puis relance.'
  );
  process.exit(0);
}

const insert = db.prepare(
  'INSERT INTO feed_clips (feed, title, mux_playback_id, active, user_id, position) VALUES (?, ?, ?, 1, ?, ?)'
);

let created = 0;
for (const a of artists) {
  const has = db
    .prepare('SELECT COUNT(*) c FROM feed_clips WHERE user_id = ?')
    .get(a.id).c;
  if (has > 0) {
    console.log(`- ${a.name} (#${a.id}) : déjà ${has} vidéo(s), on saute.`);
    continue;
  }
  sources.forEach((s, i) => {
    // ~1/3 en "clips" (paysage), le reste en "for_you" (shorts portrait).
    const feed = i % 3 === 0 ? 'clips' : 'for_you';
    insert.run(feed, s.title || `${a.name} — extrait ${i + 1}`, s.mux_playback_id, a.id, i);
    created++;
  });
  console.log(`+ ${a.name} (#${a.id}) : ${sources.length} vidéo(s) de démo ajoutées.`);
}

console.log(`\nTerminé. ${created} vidéo(s) créées au total.`);
process.exit(0);

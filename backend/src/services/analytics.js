'use strict';
/**
 * Mesure d'audience VybzzZ — sans cookie, sans donnée personnelle.
 *
 * Pourquoi maison plutôt que Google Analytics / Plausible :
 *  - aucun service supplémentaire à installer sur le VPS (Express + SQLite sont déjà là) ;
 *  - aucune donnée ne sort du serveur, donc aucun transfert hors UE à déclarer ;
 *  - aucun cookie ni stockage sur l'appareil du visiteur -> AUCUN bandeau de consentement
 *    nécessaire (CNIL : la mesure d'audience strictement nécessaire en est exemptée).
 *
 * Visiteur unique sans cookie : identifiant = sha256(sel du jour + IP + user-agent),
 * tronqué à 16 caractères. Le sel change chaque jour, donc :
 *  - impossible de suivre quelqu'un d'un jour sur l'autre ;
 *  - impossible de remonter à l'IP depuis la base (fonction à sens unique) ;
 *  - l'IP elle-même n'est JAMAIS stockée.
 */
const crypto = require('crypto');
const { db } = require('../db');
const geo = require('./geo');

// Sel quotidien, gardé en mémoire : il disparaît au redémarrage, ce qui ne fait
// que renforcer l'anonymat (au pire, un visiteur est compté deux fois ce jour-là).
let _saltDay = '';
let _salt = '';
function dailySalt() {
  const day = new Date().toISOString().slice(0, 10);
  if (day !== _saltDay) { _saltDay = day; _salt = crypto.randomBytes(24).toString('hex'); }
  return _salt;
}

function visitorId(ip, ua) {
  return crypto.createHash('sha256').update(dailySalt() + '|' + (ip || '') + '|' + (ua || '')).digest('hex').slice(0, 16);
}

// Robots et outils : comptés nulle part, sinon les chiffres ne veulent rien dire.
const BOT = /bot|crawl|spider|slurp|bingpreview|facebookexternalhit|preview|monitor|curl|wget|python-requests|headless|lighthouse|pingdom|uptime/i;
function isBot(ua) { return !ua || BOT.test(ua); }

function deviceOf(ua) {
  if (/iPad|Tablet/i.test(ua)) return 'tablette';
  if (/Mobi|Android|iPhone/i.test(ua)) return 'mobile';
  return 'ordinateur';
}

// Domaine de provenance uniquement : on veut savoir si le trafic vient de
// TikTok, d'Instagram ou de WhatsApp, pas quelle page précise.
function refHost(ref, self) {
  if (!ref) return 'direct';
  try {
    const h = new URL(ref).hostname.replace(/^www\./, '').toLowerCase();
    if (!h || h === self) return 'direct';
    if (h.includes('tiktok')) return 'TikTok';
    if (h.includes('instagram')) return 'Instagram';
    if (h.includes('facebook') || h === 'l.facebook.com' || h.includes('fb.')) return 'Facebook';
    if (h.includes('whatsapp') || h === 'l.wl.co') return 'WhatsApp';
    if (h.includes('youtube') || h.includes('youtu.be')) return 'YouTube';
    if (h.includes('google')) return 'Google';
    if (h.includes('snapchat')) return 'Snapchat';
    if (h.includes('t.co') || h.includes('twitter') || h === 'x.com') return 'X';
    if (h.includes('linkedin') || h === 'lnkd.in') return 'LinkedIn';
    return h.slice(0, 60);
  } catch (_) { return 'direct'; }
}

// Chemin nettoyé : on retire les paramètres, et on regroupe les liens
// personnels du Challenge sous "/c/*" pour ne pas créer une ligne par artiste.
function cleanPath(p) {
  let s = String(p || '/').split('?')[0].split('#')[0].slice(0, 120);
  if (!s.startsWith('/')) s = '/' + s;
  if (/^\/c\/[^/]+$/.test(s)) return '/c/*';
  return s;
}

const ALLOWED = new Set(['pageview', 'cta_apply', 'cta_challenge', 'challenge_signup', 'fan_join',
  'store_click', 'whatsapp_click', 'contact_lead', 'artist_apply', 'feed_view', 'share_link', 'app_page']);

function track({ name, path, ref, lang, ip, ua, host }) {
  if (isBot(ua)) return { ok: false, reason: 'bot' };
  const ev = ALLOWED.has(name) ? name : 'pageview';
  const country = (geo.fromIp(ip) || {}).code || null;
  db.prepare(
    `INSERT INTO analytics_events (day, vid, path, name, ref, country, device, lang)
     VALUES (date('now'), ?, ?, ?, ?, ?, ?, ?)`
  ).run(visitorId(ip, ua), cleanPath(path), ev, refHost(ref, host), country,
        deviceOf(ua || ''), String(lang || '').slice(0, 5) || null);
  return { ok: true };
}

/** Purge : 400 jours suffisent pour comparer une année sur l'autre. */
function purge() {
  try { db.prepare("DELETE FROM analytics_events WHERE day < date('now','-400 days')").run(); } catch (_) {}
}

function report(days = 7) {
  const d = Math.min(Math.max(parseInt(days, 10) || 7, 1), 365);
  const since = `date('now','-${d - 1} days')`;
  const q = (sql, ...p) => db.prepare(sql.replace('@since', since)).all(...p);
  const one = (sql, ...p) => db.prepare(sql.replace('@since', since)).get(...p);

  const totals = one(
    `SELECT COUNT(*) vues, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview'`
  );
  const byDay = q(
    `SELECT day, COUNT(*) vues, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview'
      GROUP BY day ORDER BY day`
  );
  const pages = q(
    `SELECT path, COUNT(*) vues, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview'
      GROUP BY path ORDER BY vues DESC LIMIT 15`
  );
  const refs = q(
    `SELECT ref source, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview'
      GROUP BY ref ORDER BY visiteurs DESC LIMIT 12`
  );
  const countries = q(
    `SELECT country, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview' AND country IS NOT NULL
      GROUP BY country ORDER BY visiteurs DESC LIMIT 12`
  ).map((r) => ({ ...r, nom: geo.name(r.country), drapeau: geo.flag(r.country) }));
  const devices = q(
    `SELECT device, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name = 'pageview'
      GROUP BY device ORDER BY visiteurs DESC`
  );
  const actions = q(
    `SELECT name, COUNT(*) total, COUNT(DISTINCT vid) visiteurs
       FROM analytics_events WHERE day >= @since AND name <> 'pageview'
      GROUP BY name ORDER BY total DESC`
  );

  // Tunnel du Live Challenge, en visiteurs distincts.
  const uniq = (sql, ...p) => one('SELECT COUNT(DISTINCT vid) n FROM analytics_events WHERE day >= @since AND ' + sql, ...p).n;
  const funnel = [
    { etape: 'Visiteurs du site', n: totals.visiteurs },
    { etape: 'Ont vu la page Challenge', n: uniq("name='pageview' AND path='/challenge.html'") },
    { etape: 'Se sont inscrits au Challenge', n: uniq("name='challenge_signup'") },
    { etape: 'Ont ouvert un lien d\'artiste', n: uniq("name='pageview' AND path='/c/*'") },
    { etape: 'Fans pré-inscrits via un lien', n: uniq("name='fan_join'") },
  ];
  return { jours: d, totals, byDay, pages, refs, countries, devices, actions, funnel };
}

module.exports = { track, report, purge };

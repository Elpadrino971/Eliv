// services/geo.js — résolution du pays d'un utilisateur (IP → pays) + utilitaires.
//
// geoip-lite est une "optionalDependency" : si elle n'est pas installée
// (échec réseau au build, etc.), le module continue de fonctionner en mode
// dégradé (la capture IP est simplement désactivée, le repli par adresse reste
// actif). Aucune donnée ne transite par un service externe : geoip-lite
// embarque sa propre base, tout est résolu en local.

let geoip = null;
try { geoip = require('geoip-lite'); } catch (_) { geoip = null; }

// Noms FR des pays les plus probables pour l'audience VybzzZ (repli : le code).
const NAMES = {
  FR: 'France', GP: 'Guadeloupe', MQ: 'Martinique', GF: 'Guyane', RE: 'La Réunion',
  YT: 'Mayotte', NC: 'Nouvelle-Calédonie', PF: 'Polynésie française', BL: 'Saint-Barthélemy',
  MF: 'Saint-Martin', BE: 'Belgique', CH: 'Suisse', LU: 'Luxembourg', MC: 'Monaco',
  GB: 'Royaume-Uni', IE: 'Irlande', DE: 'Allemagne', ES: 'Espagne', PT: 'Portugal',
  IT: 'Italie', NL: 'Pays-Bas', US: 'États-Unis', CA: 'Canada', BR: 'Brésil',
  MA: 'Maroc', DZ: 'Algérie', TN: 'Tunisie', SN: 'Sénégal', CI: "Côte d'Ivoire",
  CM: 'Cameroun', CD: 'RD Congo', CG: 'Congo', ML: 'Mali', GN: 'Guinée', TG: 'Togo',
  BJ: 'Bénin', BF: 'Burkina Faso', GA: 'Gabon', HT: 'Haïti', DO: 'Rép. dominicaine',
  MG: 'Madagascar', MU: 'Maurice', NG: 'Nigéria', GH: 'Ghana', ZA: 'Afrique du Sud',
};

// Drapeau emoji à partir d'un code ISO-2 (lettres → indicateurs régionaux).
function flag(code) {
  if (!code || code.length !== 2) return '🏳️';
  const cc = code.toUpperCase();
  if (!/^[A-Z]{2}$/.test(cc)) return '🏳️';
  return String.fromCodePoint(0x1F1E6 + cc.charCodeAt(0) - 65, 0x1F1E6 + cc.charCodeAt(1) - 65);
}

function name(code) {
  if (!code) return 'Inconnu';
  return NAMES[code.toUpperCase()] || code.toUpperCase();
}

// Résout une IP en { code, lat, lon } via geoip-lite (ou null).
function fromIp(ip) {
  if (!geoip || !ip) return null;
  // Nettoie IPv6-mapped IPv4 (::ffff:1.2.3.4) et les listes X-Forwarded-For.
  const clean = String(ip).replace('::ffff:', '').split(',')[0].trim();
  if (!clean || clean === '127.0.0.1' || clean === '::1') return null;
  try {
    const g = geoip.lookup(clean);
    if (!g || !g.country) return null;
    return { code: g.country, lat: g.ll ? g.ll[0] : null, lon: g.ll ? g.ll[1] : null, city: g.city || null };
  } catch (_) { return null; }
}

// Repli : déduit un pays (et un point approx.) d'une adresse texte libre.
// Sert à peupler la carte avec les comptes existants (avant capture IP).
const ADDRESS_HINTS = [
  [/guadeloupe|lamentin|pointe-?à-?pitre|gosier|97[12]\d\d/i, { code: 'GP', lat: 16.25, lon: -61.58 }],
  [/martinique|fort-?de-?france|schoelcher|972\d\d/i,        { code: 'MQ', lat: 14.64, lon: -61.02 }],
  [/cayenne|guyane|kourou|973\d\d/i,                         { code: 'GF', lat: 4.94,  lon: -52.33 }],
  [/réunion|reunion|saint-?denis.*974|974\d\d/i,             { code: 'RE', lat: -20.88,lon: 55.45 }],
  [/mayotte|976\d\d/i,                                       { code: 'YT', lat: -12.78,lon: 45.23 }],
  [/paris|lyon|marseille|toulouse|nantes|bordeaux|lille|nice|strasbourg|rennes|montpellier|france/i,
                                                             { code: 'FR', lat: 46.6,  lon: 2.4 }],
  [/bruxelles|belgique|belgium/i,                            { code: 'BE', lat: 50.85, lon: 4.35 }],
  [/genève|geneve|lausanne|suisse|switzerland/i,             { code: 'CH', lat: 46.8,  lon: 8.2 }],
  [/montréal|montreal|québec|quebec|canada/i,                { code: 'CA', lat: 56.1,  lon: -106.3 }],
  [/dakar|sénégal|senegal/i,                                 { code: 'SN', lat: 14.5,  lon: -14.5 }],
  [/abidjan|côte d'?ivoire|ivory/i,                          { code: 'CI', lat: 7.5,   lon: -5.5 }],
  [/casablanca|rabat|maroc|morocco/i,                        { code: 'MA', lat: 31.8,  lon: -7.1 }],
  [/londres|london|royaume-?uni|united kingdom/i,            { code: 'GB', lat: 54.0,  lon: -2.0 }],
];

function fromAddress(address) {
  if (!address) return null;
  for (const [re, geo] of ADDRESS_HINTS) if (re.test(address)) return { ...geo, city: null };
  return null;
}

// Centre approximatif d'un pays (pour placer un point quand on n'a que le code).
const CODE_CENTROID = {
  FR: [46.6, 2.4], GP: [16.25, -61.58], MQ: [14.64, -61.02], GF: [4.94, -52.33], RE: [-20.88, 55.45],
  YT: [-12.78, 45.23], BE: [50.85, 4.35], CH: [46.8, 8.2], LU: [49.8, 6.1], GB: [54, -2],
  DE: [51, 10], ES: [40, -3.7], PT: [39.5, -8], IT: [42.8, 12.8], NL: [52.1, 5.3],
  US: [39, -98], CA: [56.1, -106.3], BR: [-10, -52], MA: [31.8, -7.1], DZ: [28, 2.6],
  TN: [34, 9], SN: [14.5, -14.5], CI: [7.5, -5.5], CM: [5.7, 12.4], CD: [-2.9, 23.6],
  ML: [17.6, -4], GN: [10.4, -11], HT: [19, -72.3], MG: [-19, 46.7], NG: [9.1, 8.7], GH: [7.9, -1],
};
function centroid(code) { return code ? CODE_CENTROID[code.toUpperCase()] || null : null; }

module.exports = { available: !!geoip, fromIp, fromAddress, centroid, name, flag };

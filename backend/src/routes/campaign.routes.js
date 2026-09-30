'use strict';

/**
 * Campagnes de concert sur le site : roue de la fortune (places offertes) et
 * billetterie par carte (Stripe). Voir services/wheel.js et
 * services/web_tickets.js.
 */

const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const wheel = require('../services/wheel');
const webTickets = require('../services/web_tickets');
const webWatch = require('../services/web_watch');

const SALT = process.env.JWT_SECRET || 'vybzzz';
function ipHash(req) {
  return crypto.createHash('sha256').update(`${SALT}:${req.ip || ''}`).digest('hex').slice(0, 24);
}

// État public d'une campagne : places restantes, horaires, prix, billetterie.
router.get('/campaign/:slug', (req, res) => {
  const s = wheel.publicStatus(req.params.slug);
  if (!s) return res.status(404).json({ status: 'error', message: 'Campagne introuvable.' });
  res.set('Cache-Control', 'no-store');
  return res.json({ status: 'success', data: s });
});

// Un tirage. Le résultat est décidé ici ; la page ne fait que l'animer.
router.post('/wheel/:slug/spin', async (req, res) => {
  const b = req.body || {};
  if (!(b.consent === true || b.consent === 'true' || b.consent === 1 || b.consent === '1')) {
    return res.status(422).json({ status: 'error', message: 'Accepte le règlement pour jouer.' });
  }
  try {
    const r = await wheel.spin(req.params.slug, b.email, ipHash(req));
    if (r.error) return res.status(r.code || 422).json({ status: 'error', message: r.error });
    return res.json({ status: 'success', data: r });
  } catch (e) {
    console.error('[roue] tirage :', e.message);
    return res.status(500).json({ status: 'error', message: 'La roue est momentanément indisponible, réessaie.' });
  }
});

// Lien reçu par e-mail par un gagnant.
router.get('/wheel/claim', (req, res) => {
  const r = wheel.claim(req.query.t);
  const page = (titre, message, ok, watch) => `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>VybzzZ — ${titre}</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0A1226;color:#F4EFE3;
font-family:system-ui,-apple-system,sans-serif;text-align:center;padding:28px;line-height:1.6}
.c{max-width:440px}.i{font-size:54px;margin-bottom:10px}h1{font-size:1.5rem;margin:0 0 10px}
p{color:#B9C0D0;margin:0 0 24px}a{display:inline-block;background:#E6C76A;color:#0A1226;text-decoration:none;
font-weight:700;padding:14px 26px;border-radius:12px}b{color:#F4EFE3}</style></head>
<body><div class="c"><div class="i">${ok ? '🎉' : '⚠️'}</div><h1>${titre}</h1><p>${message}</p>
${watch ? `<a href="${watch}">Regarder le live sur le site</a><p style="margin:18px 0 0;font-size:.9rem">Garde ce lien : c'est ta place. Tu peux aussi <a href="https://vybzzz.online/app.html" style="all:unset;color:#E6C76A;text-decoration:underline;cursor:pointer">utiliser l'application</a> avec cette adresse.</p>` : `<a href="https://vybzzz.online/app.html">Ouvrir l'application VybzzZ</a>`}</div></body></html>`;

  res.set('Cache-Control', 'no-store');
  if (r.state === 'invalid') {
    return res.status(404).type('html').send(page('Lien invalide', 'Ce lien ne correspond à aucune place gagnée. Vérifie que tu utilises bien le dernier e-mail reçu.', false));
  }
  if (r.state === 'expired') {
    return res.status(410).type('html').send(page('Place expirée', 'Ta réservation a dépassé 24 heures et toutes les places ont été redistribuées. Tu peux encore réserver ton accès sur vybzzz.online.', false));
  }
  const who = `<b>${String(r.email).replace(/[<>&"]/g, '')}</b>`;
  const msg = r.account
    ? `C'est confirmé : ta place est ajoutée à ton compte VybzzZ ${who}. Ouvre l'app avec cette adresse pour rejoindre le live.`
    : `C'est confirmé ! Crée ton compte VybzzZ avec l'adresse ${who} (ou connecte-toi avec elle) : ta place y sera automatiquement.`;
  // Place attribuée : lien direct vers le live sur le site (sans l'app).
  const watch = r.granted && r.eventId ? webWatch.watchUrl(r.eventId, webWatch.issue(r.email, r.eventId, 'wheel')) : null;
  const msgWatch = watch
    ? `C'est confirmé : ta place est réservée pour ${who}. Le jour J, regarde le concert directement sur le site avec le bouton ci-dessous, ou dans l'app VybzzZ avec cette adresse.`
    : msg;
  return res.type('html').send(page('Ta place est confirmée', msgWatch, true, watch));
});

// Billetterie par carte : renvoie l'adresse de la page de paiement Stripe.
router.post('/tickets/web-checkout', async (req, res) => {
  const b = req.body || {};
  let eventId = Number(b.event_id);
  let page = 'index.html';
  if (b.campaign) {
    const s = wheel.publicStatus(String(b.campaign));
    if (!s) return res.status(404).json({ status: 'error', message: 'Campagne introuvable.' });
    if (!s.ticketing_open) return res.status(409).json({ status: 'error', message: 'La billetterie ouvre très bientôt.' });
    eventId = s.event_id;
    page = `${s.slug}.html`;
  }
  try {
    // from = 'live' : achat depuis live.html, retour direct sur le concert.
    const returnTo = !b.campaign && b.from === 'live' ? 'live' : 'page';
    const r = await webTickets.createCheckout({ eventId, rawEmail: b.email, campaign: b.campaign || null, page, returnTo });
    if (r.error) return res.status(r.code || 422).json({ status: 'error', message: r.error });
    return res.json({ status: 'success', data: { url: r.url } });
  } catch (e) {
    console.error('[billetterie] session Stripe :', e.message);
    return res.status(502).json({ status: 'error', message: 'Le paiement est momentanément indisponible, réessaie.' });
  }
});

module.exports = router;

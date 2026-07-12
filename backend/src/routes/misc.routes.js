'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { ok, list, fail, serializeUser } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');
const { saveUpload, PUBLIC_BASE_URL } = require('../uploads');
const mux = require('../services/mux');
const stripeService = require('../services/stripe');
const zegoService = require('../services/zego');

// GET /api/genres -> { status, data: [...] }
router.get('/genres', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM genres').all());
});

// POST /api/live/zego-token — token ZegoCloud généré côté serveur (jamais
// d'AppSign/ServerSecret dans l'app). Valable 4h (durée d'un concert), à
// refaire si le live dépasse cette fenêtre.
router.post('/live/zego-token', requireAuth, (req, res) => {
  if (!zegoService.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Live indisponible pour le moment.' });
  }
  try {
    const { token, appId, expiresAt } = zegoService.generateToken04(req.user.id);
    return res.json({ status: 'success', data: { token, app_id: appId, expires_at: expiresAt } });
  } catch (e) {
    console.error('[zego token]', e.message);
    return res.status(502).json({ status: 'error', message: `Erreur Zego : ${e.message}` });
  }
});

// POST /api/ideas — Boîte à idées (soumission depuis l'app)
router.post('/ideas', optionalAuth, (req, res) => {
  const b = req.body || {};
  if (!b.message) return fail(res, 'Le message est requis.', 422, { message: ['Le message est requis.'] });
  db.prepare(
    'INSERT INTO ideas (user_id, name, email, category, message) VALUES (?, ?, ?, ?, ?)'
  ).run(req.user?.id || b.user_id || null, b.name || req.user?.full_name || null,
    b.email || req.user?.email || null, b.category || 'Général', b.message);
  return res.json({ status: 'success', message: 'Merci, votre idée a bien été envoyée !' });
});

// POST /api/event/:id/like — like / unlike un concert (toggle via body { liked })
router.post('/event/:id/like', optionalAuth, (req, res) => {
  const liked = req.body?.liked === false ? false : true;
  db.prepare('UPDATE events SET likes_count = MAX(0, COALESCE(likes_count,0) + ?) WHERE id = ?')
    .run(liked ? 1 : -1, req.params.id);
  const row = db.prepare('SELECT likes_count FROM events WHERE id = ?').get(req.params.id);
  return res.json({ status: 'success', likes_count: row?.likes_count ?? 0 });
});

// GET /api/get-abusive-words -> { status, data: [...] }
router.get('/get-abusive-words', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM abusive_words').all());
});

// GET /api/settings/get-settings -> { status, data: {...} }
router.get('/settings/get-settings', (req, res) => {
  const rows = db.prepare('SELECT * FROM settings').all();
  const obj = {};
  for (const r of rows) obj[r.key] = r.value;
  return res.json({ status: 'success', data: obj });
});

// GET /api/settings/get-management -> { status, data: {...} }
router.get('/settings/get-management', (req, res) => {
  return res.json({
    status: 'success',
    data: {
      terms_url: 'https://vybzzz.com/terms',
      privacy_url: 'https://vybzzz.com/privacy',
      support_email: 'support@vybzzz.com',
    },
  });
});

// ─── Subscriptions (artistes) ───
// Lit la vraie table `subscriptions` geree dans l'admin (Abonnements) et la
// convertit au format attendu par le modele Flutter (Subscription.fromJson) :
// title/price/is_founder/seats_total/seats_remaining/... Voir
// docs/founder_plan_api_spec.md pour le detail des champs Founder.
//
// NB seats_remaining : pas encore de suivi des achats reels (aucune table
// d'abonnements payes pour l'instant) -> on renvoie seats_total tel quel.
// A brancher sur un vrai compteur d'achats des que /subscription/buy
// enregistrera reellement une souscription en base.
router.get('/subscription/get', (req, res) => {
  const rows = db.prepare('SELECT * FROM subscriptions WHERE active = 1 ORDER BY CAST(price AS REAL) ASC').all();

  // Un seul palier "Founder" visible a la fois (le moins cher parmi les
  // paliers actifs = le palier en cours). Les paliers suivants restent en
  // base, prets a prendre le relais des que l'admin desactive le precedent
  // (pas encore de suivi automatique des vraies ventes -> bascule manuelle).
  const founderRows = rows.filter((r) => (r.tier || '').toLowerCase() === 'founder');
  const otherRows = rows.filter((r) => (r.tier || '').toLowerCase() !== 'founder');
  const currentFounder = founderRows[0] || null;
  const nextFounder = founderRows[1] || null;
  const visibleRows = currentFounder ? [currentFounder, ...otherRows] : otherRows;

  const list = visibleRows.map((r) => {
    const seatsTotal = r.slot_from != null && r.slot_to != null ? r.slot_to - r.slot_from + 1 : null;
    const isCurrentFounder = currentFounder && r.id === currentFounder.id;
    // Prix annuel : champ libre rempli par l'admin (plus de formule auto x10).
    const annualPrice = r.price_annual || null;
    const perks = (r.perks || '')
      .split('\n')
      .map((p) => p.trim())
      .filter((p) => p.length > 0);
    return {
      id: r.id,
      title: r.name,
      price: r.price,
      price_type: r.period === 'year' ? 'yearly' : 'monthly',
      annual_price: annualPrice != null ? String(annualPrice) : null,
      perks,
      commission_type: r.commission != null ? 'percentage' : null,
      commission: r.commission != null ? String(r.commission) : null,
      artists_count: null,
      status: 'active',
      created_at: r.created_at,
      updated_at: r.created_at,
      is_founder: (r.tier || '').toLowerCase() === 'founder',
      seats_total: seatsTotal,
      seats_remaining: seatsTotal,
      next_price: isCurrentFounder && nextFounder ? nextFounder.price : null,
      next_price_in_seats: isCurrentFounder ? seatsTotal : null,
      public_price: null,
      badge: r.badge,
      iap_product_id: null,
      image: r.image,
    };
  });
  return res.json({ status: 'success', count: list.length, list });
});
// Appelé par l'app juste après un achat IAP réussi (déjà vérifié par
// Apple/Google via le SDK RevenueCat côté client) : sert au retour immédiat
// dans l'UI. Le webhook RevenueCat (routes/revenuecat.routes.js) reste la
// source de vérité serveur-à-serveur — celui-ci ne fait que réconcilier tout
// de suite, sans attendre la latence du webhook.
router.post('/subscription/buy', requireAuth, (req, res) => {
  const subscriptionsId = Number(req.body?.subscriptions_id);
  const sub = db.prepare('SELECT id FROM subscriptions WHERE id = ? AND active = 1').get(subscriptionsId);
  if (!sub) return fail(res, 'Abonnement introuvable.', 404);

  const existing = db.prepare(
    'SELECT id FROM user_subscriptions WHERE user_id = ? AND subscriptions_id = ?'
  ).get(req.user.id, subscriptionsId);
  if (existing) {
    db.prepare("UPDATE user_subscriptions SET status = 'active' WHERE id = ?").run(existing.id);
  } else {
    db.prepare(
      "INSERT INTO user_subscriptions (user_id, subscriptions_id, status) VALUES (?, ?, 'active')"
    ).run(req.user.id, subscriptionsId);
  }

  const fresh = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  return res.json({ status: 'success', data: serializeUser(fresh) });
});

// POST /api/subscription/checkout — paiement carte (Stripe Checkout), chemin
// web "0% commission Apple". Renvoie l'URL à ouvrir dans le navigateur ; le
// webhook Stripe active l'abonnement dès le paiement confirmé.
router.post('/subscription/checkout', requireAuth, (req, res) => {
  if (!stripeService.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Paiement carte indisponible pour le moment.' });
  }
  const subscriptionsId = Number(req.body?.subscriptions_id);
  const annual = req.body?.annual === true || req.body?.annual === '1' || req.body?.annual === 'true';
  const sub = db.prepare('SELECT * FROM subscriptions WHERE id = ? AND active = 1').get(subscriptionsId);
  if (!sub) return res.status(404).json({ status: 'error', message: 'Abonnement introuvable.' });

  const priceId = annual ? sub.stripe_price_id_annual : sub.stripe_price_id;
  if (!priceId) {
    return res.status(422).json({ status: 'error', message: "Ce plan n'a pas encore de tarif Stripe configuré." });
  }

  stripeService.createSubscriptionCheckout({
    priceId,
    userId: req.user.id,
    subscriptionsId,
    customerEmail: req.user.email,
    successUrl: `${PUBLIC_BASE_URL}/subscribe/merci`,
    cancelUrl: `${PUBLIC_BASE_URL}/subscribe/annule`,
  })
    .then((session) => res.json({ status: 'success', data: { checkout_url: session.url } }))
    .catch((e) => {
      console.error('[stripe checkout]', e.message);
      res.status(502).json({ status: 'error', message: `Erreur Stripe : ${e.message}` });
    });
});

// ─── Feed Clips ("Pour toi" / "Clips") — contenu curaté depuis l'admin,
// indépendant des concerts. Voir /api/admin/feed-clips pour la gestion. ───
const feedMuxHls = (id) => (id ? `https://stream.mux.com/${id}.m3u8` : null);
router.get('/feed-clips', (req, res) => {
  const feed = req.query.feed === 'clips' ? 'clips' : 'for_you';
  const rows = db
    .prepare('SELECT * FROM feed_clips WHERE feed = ? AND active = 1 ORDER BY position ASC, id ASC')
    .all(feed);
  const list = rows.map((r) => ({
    id: r.id,
    title: r.title,
    video_url: r.mux_playback_id ? feedMuxHls(r.mux_playback_id) : r.video_url,
    mux_playback_id: r.mux_playback_id,
  }));
  return res.json({ status: 'success', count: list.length, list });
});

// POST /api/feed-clips/submit — n'importe quel user connecté peut soumettre
// un short pour "Pour toi" ou "Clips" ; reste invisible (active=0) tant que
// l'admin ne l'a pas approuvé depuis "Clips (Feeds)" (contenu hors-scène
// filtré manuellement, pas de modération automatique).
router.post('/feed-clips/submit', requireAuth, (req, res) => {
  const b = req.body || {};
  const feed = b.feed === 'for_you' ? 'for_you' : 'clips';
  const video = saveUpload(req, ['video', 'file'], 'videos', 'events/videos');
  if (!video) {
    return res.status(422).json({ status: 'error', message: 'Fichier vidéo requis.' });
  }
  db.prepare(
    'INSERT INTO feed_clips (feed, title, video_url, active, user_id) VALUES (?, ?, ?, 0, ?)'
  ).run(feed, b.title || null, video, req.user.id);
  return res.json({ status: 'success', message: 'Envoyé ! Ton clip sera visible après validation.' });
});

// POST /api/feed-clips/submit-direct — variante Mux : le fichier est PUT
// directement sur Mux (le serveur ne touche jamais la vidéo), utile pour de
// gros fichiers. Renvoie une upload_url à PUT depuis l'app, plus rien à faire
// côté client ensuite : le webhook Mux finalise le clip automatiquement.
router.post('/feed-clips/submit-direct', requireAuth, (req, res) => {
  if (!mux.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Upload direct indisponible pour le moment.' });
  }
  const b = req.body || {};
  const feed = b.feed === 'for_you' ? 'for_you' : 'clips';
  const info = db.prepare(
    'INSERT INTO feed_clips (feed, title, active, user_id, upload_status) VALUES (?, ?, 0, ?, ?)'
  ).run(feed, b.title || null, req.user.id, 'waiting');
  const clipId = info.lastInsertRowid;

  mux.createDirectUpload({ passthrough: { kind: 'clip', id: clipId } })
    .then(({ uploadId, uploadUrl }) => {
      db.prepare('UPDATE feed_clips SET mux_upload_id = ? WHERE id = ?').run(uploadId, clipId);
      return res.json({ status: 'success', data: { upload_url: uploadUrl, clip_id: clipId } });
    })
    .catch((e) => {
      db.prepare('DELETE FROM feed_clips WHERE id = ?').run(clipId);
      console.error('[mux submit-direct]', e.message);
      return res.status(502).json({ status: 'error', message: `Erreur Mux : ${e.message}` });
    });
});

// ─── Packages (points / gifts) ───
router.get('/packages/list', (req, res) => ok(res, []));
router.post('/packages/buy', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Package purchased (demo).' })
);

// ─── Transactions / Wallet ───
router.post('/get-transactions', optionalAuth, (req, res) => ok(res, []));

// ─── Artist statistics ───
router.post('/get-artist-statistics', optionalAuth, (req, res) => {
  return res.json({
    status: 'success',
    data: { followers: 0, events: 0, tickets_sold: 0, revenue: '0' },
  });
});
router.post('/get-event-stats-by-user-id', optionalAuth, (req, res) =>
  res.json({ status: 'success', data: { total_events: 0, total_tickets: 0 } })
);

// ─── Support ───
router.post('/support/get-subjects', (req, res) =>
  ok(res, [{ id: 1, name: 'General' }, { id: 2, name: 'Payment' }, { id: 3, name: 'Technical' }])
);
router.post('/support/get-list', optionalAuth, (req, res) => ok(res, []));
router.post('/support/create', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Ticket created.' })
);
router.post('/support/get-details', optionalAuth, (req, res) => ok(res, {}));
router.post('/support/resolve', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Resolved.' })
);
router.post('/support/store-meta', (req, res) => res.json({ status: 'success' }));

// ─── Bank / Withdraw ───
router.post('/withdraw/add-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank added.' })
);
router.post('/withdraw/get-user-banks', requireAuth, (req, res) => ok(res, []));
router.post('/withdraw/update-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank updated.' })
);
router.post('/withdraw/delete-bank', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Bank deleted.' })
);
router.post('/withdraw/add', requireAuth, (req, res) =>
  res.json({ status: 'success', message: 'Withdrawal requested.' })
);
router.get('/following', optionalAuth, (req, res) => ok(res, []));

// ═══════════════════════════════════════════════════════════════════════
// NOUVELLES FEATURES (docs/BACKEND_CHANGES.md) — ce qui manquait à Hammad
// ═══════════════════════════════════════════════════════════════════════

// GET /api/event/:id/access  -> état d'accès du user courant
router.get('/event/:id/access', requireAuth, (req, res) => {
  const eventId = req.params.id;
  const ticket = db
    .prepare('SELECT * FROM tickets WHERE event_id = ? AND user_id = ?')
    .get(eventId, req.user.id);
  if (ticket) {
    return res.json({ status: 'success', has_access: true, access_type: 'ticket', expires_at: null });
  }
  const ghost = db
    .prepare("SELECT * FROM ghost_passes WHERE event_id = ? AND user_id = ? AND datetime(expires_at) > datetime('now') ORDER BY datetime(expires_at) DESC")
    .get(eventId, req.user.id);
  if (ghost) {
    return res.json({ status: 'success', has_access: true, access_type: 'ghost_pass', expires_at: ghost.expires_at });
  }
  return res.json({ status: 'success', has_access: false, access_type: 'none', expires_at: null });
});

// ─── Referral ───
router.post('/referral/generate', requireAuth, (req, res) => {
  let code = req.user.referral_code;
  if (!code) {
    code = `VYB${Math.floor(1000 + Math.random() * 9000)}`;
    db.prepare('UPDATE users SET referral_code = ? WHERE id = ?').run(code, req.user.id);
  }
  return res.json({ status: 'success', data: { code, link: `https://vybzzz.com/r/${code}` } });
});

router.get('/referral/me', requireAuth, (req, res) => {
  const rows = db.prepare('SELECT * FROM referrals WHERE referrer_id = ? ORDER BY id DESC').all(req.user.id);
  return ok(res, rows);
});

router.post('/referral/redeem', requireAuth, (req, res) => {
  const code = req.body?.code;
  const referrer = db.prepare('SELECT * FROM users WHERE referral_code = ?').get(code);
  if (!referrer) return fail(res, 'Invalid referral code.', 422);
  if (referrer.id === req.user.id) return fail(res, 'You cannot refer yourself.', 422);
  const existing = db.prepare('SELECT id FROM referrals WHERE referee_id = ?').get(req.user.id);
  if (existing) return fail(res, 'Referral already redeemed.', 422);

  const reward = referrer.is_artist ? 'free_ticket' : 'ghost_pass';
  db.prepare(
    "INSERT INTO referrals (code, referrer_id, referee_id, status, reward) VALUES (?, ?, ?, 'validated', ?)"
  ).run(code, referrer.id, req.user.id, reward);
  db.prepare('UPDATE users SET referred_by = ? WHERE id = ?').run(referrer.id, req.user.id);
  return res.json({ status: 'success', message: 'Referral redeemed.', data: { reward } });
});

// ─── Ghost pass (accès VIP temporaire gamifié, NON comptabilisé en vente) ───
router.post('/ghost-pass/grant', requireAuth, (req, res) => {
  const b = req.body || {};
  const minutes = parseInt(b.duration_minutes || 10, 10);
  const expires = new Date(Date.now() + minutes * 60000).toISOString().replace('T', ' ').slice(0, 19);
  db.prepare(
    'INSERT INTO ghost_passes (user_id, event_id, duration_minutes, expires_at) VALUES (?, ?, ?, ?)'
  ).run(req.user.id, b.event_id, minutes, expires);
  return res.json({ status: 'success', data: { event_id: b.event_id, duration_minutes: minutes, expires_at: expires } });
});

router.get('/ghost-pass/me', requireAuth, (req, res) => {
  const rows = db
    .prepare("SELECT * FROM ghost_passes WHERE user_id = ? AND datetime(expires_at) > datetime('now')")
    .all(req.user.id);
  return ok(res, rows);
});

// ─── Event Pulse (analytics agrégées, anonymisées) ───
router.post('/event/:id/signal', optionalAuth, (req, res) => {
  const b = req.body || {};
  db.prepare(
    'INSERT INTO event_signals (event_id, user_id, type, region) VALUES (?, ?, ?, ?)'
  ).run(req.params.id, req.user?.id || null, b.type || 'view', b.region || null);
  return res.json({ status: 'success' });
});

router.get('/event/:id/pulse', requireAuth, (req, res) => {
  const id = req.params.id;
  const total = db.prepare('SELECT COUNT(*) c FROM event_signals WHERE event_id = ?').get(id).c;
  const byType = db
    .prepare('SELECT type, COUNT(*) c FROM event_signals WHERE event_id = ? GROUP BY type')
    .all(id);
  return res.json({
    status: 'success',
    data: { total_signals: total, by_type: byType, top_areas: [], best_time: null },
  });
});

// ─── Shorts UGC (Mux Direct Upload) — alias générique, voir aussi
// /feed-clips/submit-direct qui crée déjà la ligne feed_clips associée. ───
router.post('/shorts/create-upload', requireAuth, (req, res) => {
  if (!mux.isConfigured()) {
    return res.status(503).json({ status: 'error', message: 'Mux non configuré côté serveur.' });
  }
  mux.createDirectUpload({ passthrough: { kind: 'shorts', id: req.user.id } })
    .then(({ uploadId, uploadUrl }) => res.json({ status: 'success', data: { upload_url: uploadUrl, upload_id: uploadId } }))
    .catch((e) => res.status(502).json({ status: 'error', message: `Erreur Mux : ${e.message}` }));
});

module.exports = router;

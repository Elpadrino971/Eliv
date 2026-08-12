'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { ok, list, fail, serializeUser } = require('../helpers');
const { requireAuth, optionalAuth } = require('../auth');
const { saveUpload, saveClipVideo, PUBLIC_BASE_URL } = require('../uploads');
const mux = require('../services/mux');
const stripeService = require('../services/stripe');
const zegoService = require('../services/zego');
const moderation = require('../services/moderation');
const CLIP_RETENTION_DAYS = Number(process.env.CLIP_RETENTION_DAYS) || 30;

// GET /api/artist/revenue-transactions — dernières entrées réelles du ledger
// (billets + cadeaux) pour l'écran "Revenus" (remplace la liste factice
// codée en dur "Ticket Sales +$1,240" / "Merch Drop" / "Bank Payout").
router.get('/artist/revenue-transactions', requireAuth, (req, res) => {
  const rows = db.prepare(
    `SELECT pe.*, e.name AS event_name
     FROM platform_earnings pe
     LEFT JOIN events e ON e.id = pe.source_id AND pe.source = 'ticket'
     WHERE pe.artist_id = ?
     ORDER BY pe.id DESC LIMIT 20`
  ).all(req.user.id);
  const list = rows.map((r) => {
    const isTicket = r.source === 'ticket';
    const amount = isTicket
      ? parseFloat(r.artist_share)
      : parseFloat(r.artist_share) / 100; // cadeaux en points, 1€ = 100 pts
    return {
      title: isTicket ? (r.event_name ? `Ticket — ${r.event_name}` : 'Ticket sale') : 'Virtual gift',
      date: r.created_at,
      amount: Math.round(amount * 100) / 100,
    };
  });
  return ok(res, list);
});

// GET /api/artist/dashboard-stats — résumé pour l'onglet Profil version artiste
// (gains totaux, fans, concerts, billets vendus) + variation vs la période
// précédente. Source de vérité : platform_earnings (ledger append-only, non
// affecté par les retraits), tickets, follows, events.
router.get('/artist/dashboard-stats', requireAuth, (req, res) => {
  const artistId = req.user.id;

  const now = new Date();
  const iso = (d) => d.toISOString().slice(0, 19).replace('T', ' ');
  const daysAgo = (n) => { const d = new Date(now); d.setDate(d.getDate() - n); return d; };
  const last30Start = iso(daysAgo(30));
  const prev30Start = iso(daysAgo(60));
  const nowIso = iso(now);
  const monthStart = iso(new Date(now.getFullYear(), now.getMonth(), 1));
  const prevMonthStart = iso(new Date(now.getFullYear(), now.getMonth() - 1, 1));

  const pct = (current, previous) => {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / previous) * 1000) / 10;
  };

  // Gains artiste (EUR) sur une fenêtre : billets en EUROS + cadeaux en POINTS
  // (1 € = 100 pts), les deux tracés dans platform_earnings.artist_share.
  const earningsBetween = (from, to) => {
    const row = db.prepare(
      `SELECT
         COALESCE(SUM(CASE WHEN source = 'ticket' THEN CAST(artist_share AS REAL) ELSE 0 END), 0) AS eur,
         COALESCE(SUM(CASE WHEN source = 'gift' THEN CAST(artist_share AS REAL) ELSE 0 END), 0) AS pts
       FROM platform_earnings WHERE artist_id = ? AND created_at >= ? AND created_at < ?`
    ).get(artistId, from, to);
    return row.eur + row.pts / 100;
  };
  const totalEarningsRow = db.prepare(
    `SELECT
       COALESCE(SUM(CASE WHEN source = 'ticket' THEN CAST(artist_share AS REAL) ELSE 0 END), 0) AS eur,
       COALESCE(SUM(CASE WHEN source = 'gift' THEN CAST(artist_share AS REAL) ELSE 0 END), 0) AS pts
     FROM platform_earnings WHERE artist_id = ?`
  ).get(artistId);
  const totalEarnings = totalEarningsRow.eur + totalEarningsRow.pts / 100;
  const earningsLast30 = earningsBetween(last30Start, nowIso);
  const earningsPrev30 = earningsBetween(prev30Start, last30Start);

  // Fans (follows)
  const fansTotal = db.prepare('SELECT COUNT(*) c FROM follows WHERE artist_id = ?').get(artistId).c;
  const fansLast30 = db.prepare(
    'SELECT COUNT(*) c FROM follows WHERE artist_id = ? AND created_at >= ? AND created_at < ?'
  ).get(artistId, last30Start, nowIso).c;
  const fansPrev30 = db.prepare(
    'SELECT COUNT(*) c FROM follows WHERE artist_id = ? AND created_at >= ? AND created_at < ?'
  ).get(artistId, prev30Start, last30Start).c;

  // Concerts (ce mois-ci vs le mois dernier, sur la date du concert)
  const showsThisMonth = db.prepare(
    'SELECT COUNT(*) c FROM events WHERE artist_id = ? AND start_date_time >= ? AND start_date_time < ?'
  ).get(artistId, monthStart, nowIso).c;
  const showsPrevMonth = db.prepare(
    'SELECT COUNT(*) c FROM events WHERE artist_id = ? AND start_date_time >= ? AND start_date_time < ?'
  ).get(artistId, prevMonthStart, monthStart).c;

  // "Streams" = billets vendus (live + replay confondus, pas de distinction
  // technique entre les deux : le même billet donne accès aux deux).
  const ticketsTotal = db.prepare(
    `SELECT COUNT(*) c FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.artist_id = ?`
  ).get(artistId).c;
  const ticketsLast30 = db.prepare(
    `SELECT COUNT(*) c FROM tickets t JOIN events e ON e.id = t.event_id
     WHERE e.artist_id = ? AND t.created_at >= ? AND t.created_at < ?`
  ).get(artistId, last30Start, nowIso).c;
  const ticketsPrev30 = db.prepare(
    `SELECT COUNT(*) c FROM tickets t JOIN events e ON e.id = t.event_id
     WHERE e.artist_id = ? AND t.created_at >= ? AND t.created_at < ?`
  ).get(artistId, prev30Start, last30Start).c;

  return ok(res, {
    total_earnings: Math.round(totalEarnings * 100) / 100,
    total_earnings_change_pct: pct(earningsLast30, earningsPrev30),
    fans_total: fansTotal,
    fans_change_pct: pct(fansLast30, fansPrev30),
    shows_this_month: showsThisMonth,
    shows_change_pct: pct(showsThisMonth, showsPrevMonth),
    tickets_total: ticketsTotal,
    tickets_change_pct: pct(ticketsLast30, ticketsPrev30),
  });
});

// GET /api/genres -> { status, data: [...] }
router.get('/genres', (req, res) => {
  return ok(res, db.prepare('SELECT * FROM genres').all());
});

// GET /api/splash-settings — fond d'écran + animation de la page de lancement,
// personnalisables depuis l'admin sans passer par une nouvelle version d'app.
// Valeurs vides -> le client retombe sur ses assets locaux par défaut.
router.get('/splash-settings', (req, res) => {
  const rows = db.prepare(
    `SELECT key, value FROM settings WHERE key IN ('splash_background_image', 'splash_background_video', 'splash_animation_style')`
  ).all();
  const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return ok(res, {
    background_image: map.splash_background_image || null,
    background_video: map.splash_background_video || null,
    animation_style: map.splash_animation_style || 'sparkles',
  });
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

// POST /api/live/:eventId/recording/start — enregistrement du concert pour le
// replay. Crée un Live Stream Mux (si le replay est activé et Mux configuré) et
// renvoie l'URL RTMP + la clé : l'app relaie le flux Zego vers cette URL, Mux
// enregistre, et à la fin du live le webhook `video.asset.ready` crée l'asset
// de replay (durée = replay_duration_days de l'event). Idempotent : si le flux
// existe déjà pour cet event, on renvoie les mêmes infos sans recréer.
router.post('/live/:eventId/recording/start', requireAuth, async (req, res) => {
  const event = db.prepare('SELECT * FROM events WHERE id = ?').get(req.params.eventId);
  if (!event) return fail(res, 'Event introuvable.', 404);
  if (event.artist_id !== req.user.id) return fail(res, 'Non autorisé.', 403);

  const replayEnabled = event.replay_enabled === null || event.replay_enabled === undefined
    ? true : !!event.replay_enabled;
  if (!replayEnabled) {
    return res.json({ status: 'success', data: { recording: false, reason: 'replay_disabled' } });
  }
  if (!mux.isConfigured()) {
    return res.json({ status: 'success', data: { recording: false, reason: 'mux_not_configured' } });
  }

  try {
    // Déjà un flux pour cet event -> on réutilise (reprise de live, retry app…).
    if (event.mux_live_stream_id && event.mux_stream_key) {
      return res.json({ status: 'success', data: {
        recording: true,
        ingest_url: mux.LIVE_INGEST_URL_RTMP,
        stream_key: event.mux_stream_key,
        // URL RTMP complète relayée par Zego (addPublishCdnUrl).
        rtmp_url: `${mux.LIVE_INGEST_URL_RTMP}/${event.mux_stream_key}`,
      }});
    }
    const { liveStreamId, streamKey, playbackId } = await mux.createLiveStream({
      passthrough: { kind: 'event', id: event.id },
    });
    db.prepare(
      `UPDATE events SET mux_live_stream_id = ?, mux_stream_key = ?, mux_live_playback_id = ?
       WHERE id = ?`
    ).run(liveStreamId, streamKey, playbackId, event.id);
    return res.json({ status: 'success', data: {
      recording: true,
      ingest_url: mux.LIVE_INGEST_URL_RTMP,
      stream_key: streamKey,
      rtmp_url: `${mux.LIVE_INGEST_URL_RTMP}/${streamKey}`,
    }});
  } catch (e) {
    console.error('[recording start]', e.message);
    // On n'échoue pas le live pour autant : l'app continue sans replay.
    return res.json({ status: 'success', data: { recording: false, reason: 'mux_error' } });
  }
});

// POST /api/live/:eventId/recording/stop — signal de fin. Mux finalise
// automatiquement l'enregistrement après l'arrêt du flux RTMP (fenêtre de
// reconnexion), donc rien de destructif ici : on laisse Mux générer l'asset de
// replay. Endpoint fourni pour cohérence côté app.
router.post('/live/:eventId/recording/stop', requireAuth, (req, res) => {
  const event = db.prepare('SELECT artist_id, status FROM events WHERE id = ?').get(req.params.eventId);
  if (!event) return fail(res, 'Event introuvable.', 404);
  if (event.artist_id !== req.user.id) return fail(res, 'Non autorisé.', 403);
  // L'hôte a quitté le live -> on clôt le concert tout de suite. On ne s'appuie
  // plus uniquement sur le webhook Mux `live_stream.idle` (qui ne se déclenche
  // pas si le relais n'a jamais poussé de vidéo), sinon l'event resterait
  // bloqué en `live` (live fantôme). Mux finalise l'asset de replay de son côté
  // à la fin du flux RTMP (fenêtre de reconnexion).
  db.prepare("UPDATE events SET status = 'completed' WHERE id = ? AND status = 'live'")
    .run(req.params.eventId);
  return res.json({ status: 'success', data: { stopped: true } });
});

// POST /api/contact-leads — formulaire "Devenir artiste" du site vitrine
// (public, non authentifié : appelé directement par site/artist.html en
// fetch()). Alimente la table contact_leads déjà visible dans l'admin
// (Contacts / Leads) — avant ce endpoint, le formulaire n'envoyait RIEN,
// juste un faux message de succès côté client.
router.post('/contact-leads', (req, res) => {
  const b = req.body || {};
  if (!b.name || !b.email) {
    return fail(res, 'Nom et email requis.', 422, {
      name: !b.name ? ['Le nom est requis.'] : undefined,
      email: !b.email ? ["L'email est requis."] : undefined,
    });
  }
  db.prepare('INSERT INTO contact_leads (name, email, phone, message) VALUES (?, ?, ?, ?)')
    .run(b.name, b.email, b.phone || null, b.message || null);
  return res.json({ status: 'success', message: 'Candidature envoyée.' });
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

// GET|POST /api/settings/get-management -> { status, count, list: [...] }
// L'app POST avec {role:'FAQ'} et lit ManagementModel.list (name=question,
// description=réponse). On sert la FAQ depuis la table faqs. Monté en GET ET
// POST (l'app fait un POST -> sinon 404 + skeletons infinis sur l'écran FAQ).
const getManagementHandler = (req, res) => {
  const rows = db.prepare('SELECT id, question, answer, created_at FROM faqs ORDER BY id ASC').all();
  const list = rows.map((r) => ({
    id: r.id,
    parent_id: null,
    role: 'FAQ',
    name: r.question,
    description: r.answer,
    image: null,
    created_at: r.created_at,
    updated_at: r.created_at,
  }));
  return res.json({ status: 'success', count: list.length, list });
};
router.get('/settings/get-management', getManagementHandler);
router.post('/settings/get-management', getManagementHandler);

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

  // Un seul palier "Founder" visible a la fois = le palier COURANT, choisi
  // automatiquement selon le nombre de Founder deja vendus (voir plus bas).
  // Les autres paliers restent en base, tries par plage de places.
  const founderRows = rows
    .filter((r) => (r.tier || '').toLowerCase() === 'founder')
    .sort((a, b) => (a.slot_from || 0) - (b.slot_from || 0));
  const otherRows = rows.filter((r) => (r.tier || '').toLowerCase() !== 'founder');

  // Auto-tiering Founder : le prix monte tout seul selon le nombre de Founder
  // déjà vendus (tous paliers confondus). On sert le palier dont la plage de
  // places [slot_from, slot_to] contient la prochaine place à vendre. Les
  // passages (ex. 24->25, 100->101) sont définis par slot_from/slot_to en
  // admin ; chaque palier a son propre prix + stripe_price_id.
  const founderSold = db
    .prepare(
      `SELECT COUNT(*) AS c FROM user_subscriptions us
       JOIN subscriptions s ON s.id = us.subscriptions_id
       WHERE LOWER(s.tier) = 'founder' AND us.status = 'active'`
    )
    .get().c || 0;
  const nextSeat = founderSold + 1;
  // Plafond total Founder = plus grande place définie (ex. 200). Une fois
  // TOUTES les places vendues, le pack Founder DISPARAÎT (n'est plus servi).
  const founderCap = founderRows.reduce((m, r) => Math.max(m, r.slot_to || 0), 0);
  const founderSoldOut = founderCap > 0 && founderSold >= founderCap;
  const currentFounder = founderSoldOut
    ? null
    : founderRows.find(
        (r) =>
          r.slot_from != null &&
          r.slot_to != null &&
          nextSeat >= r.slot_from &&
          nextSeat <= r.slot_to
      ) ||
      founderRows[0] || // paliers sans plage définie -> premier (rétro-compat)
      null;
  const nextFounder = currentFounder
    ? founderRows.find((r) => (r.slot_from || 0) > (currentFounder.slot_to || 0))
    : null;
  const visibleRows = currentFounder ? [currentFounder, ...otherRows] : otherRows;

  const list = visibleRows.map((r) => {
    const seatsTotal = r.slot_from != null && r.slot_to != null ? r.slot_to - r.slot_from + 1 : null;
    const isCurrentFounder = currentFounder && r.id === currentFounder.id;
    // Places restantes AVANT le prochain palier (= avant que le prix monte).
    const seatsRemaining = isCurrentFounder && r.slot_to != null
      ? Math.max(0, r.slot_to - founderSold)
      : seatsTotal;
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
      seats_remaining: seatsRemaining,
      next_price: isCurrentFounder && nextFounder ? nextFounder.price : null,
      next_price_in_seats: isCurrentFounder ? seatsRemaining : null,
      public_price: null,
      badge: r.badge,
      iap_product_id: r.revenuecat_product_id || null,
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
  return res.json({ status: 'success', data: serializeUser(fresh, { full: true }) });
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
router.post('/feed-clips/submit', requireAuth, async (req, res) => {
  const b = req.body || {};
  const feed = b.feed === 'for_you' ? 'for_you' : 'clips';
  const uploaded = await saveClipVideo(req, ['video', 'file']);
  if (!uploaded) {
    return res.status(422).json({ status: 'error', message: 'Fichier vidéo requis.' });
  }
  const expiresAt = uploaded.firebasePath ? `datetime('now', '+' || ${CLIP_RETENTION_DAYS} || ' days')` : 'NULL';
  const info = db.prepare(
    `INSERT INTO feed_clips (feed, title, video_url, active, user_id, firebase_path, expires_at)
     VALUES (?, ?, ?, 0, ?, ?, ${expiresAt})`
  ).run(feed, b.title || null, uploaded.url, req.user.id, uploaded.firebasePath);
  // Modération vidéo du clip soumis (asynchrone). Le clip reste de toute façon
  // invisible (active=0) tant que l'admin ne l'a pas validé.
  moderation.moderateVideo({ url: uploaded.url, targetType: 'clip', targetId: info.lastInsertRowid });
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

// ─── Packages / recharge de points (achat via IAP RevenueCat) ───
// Renvoie les packs actifs. Le vrai crédit de points se fait côté serveur
// quand RevenueCat notifie l'achat (webhook), jamais ici : /packages/buy ne
// crédite RIEN (sécurité — pas de crédit sur simple appel client).
router.get('/packages/list', (req, res) => {
  const rows = db.prepare(
    "SELECT * FROM packages WHERE active IS NULL OR active = 1 ORDER BY CAST(price AS REAL) ASC"
  ).all();
  const list = rows.map((p) => ({
    id: p.id,
    title: p.name,
    image: p.image || null,
    points: p.points,
    price: p.price,
    revenuecat_product_id: p.revenuecat_product_id || null,
    created_at: p.created_at,
  }));
  return res.json({ status: 'success', count: list.length, list });
});
// Conservé pour compat : ne crédite PAS (le crédit passe par le webhook IAP).
router.post('/packages/buy', optionalAuth, (req, res) =>
  res.json({ status: 'success', message: 'Le crédit se fait après validation du paiement.' })
);

// ─── Transactions / Wallet ───
router.post('/get-transactions', optionalAuth, (req, res) => ok(res, []));

// ─── Artist statistics ─── (dashboard "Studio" — anciennement un stub qui
// renvoyait toujours 0, peu importe les vraies données de l'artiste).
router.post('/get-artist-statistics', optionalAuth, (req, res) => {
  const artistId = req.user?.id || req.body?.id;
  const artist = db.prepare('SELECT * FROM users WHERE id = ?').get(artistId);
  if (!artist) {
    return res.json({
      status: 'success',
      data: {
        artist_name: null, total_tickets_sold: 0, current_wallet: '0', total_revenue: 0,
        followers_count: 0, event_count: 0, upcoming_events_count: 0, past_events_count: 0,
        average_rating: 0, hourly_velocity: [],
      },
    });
  }

  const eventCount = db.prepare('SELECT COUNT(*) c FROM events WHERE artist_id = ?').get(artistId).c;
  const upcoming = db.prepare(
    "SELECT COUNT(*) c FROM events WHERE artist_id = ? AND datetime(start_date_time) >= datetime('now')"
  ).get(artistId).c;
  const past = eventCount - upcoming;
  const ticketsSold = db.prepare(
    'SELECT COUNT(*) c FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.artist_id = ?'
  ).get(artistId).c;
  const revenue = db.prepare(
    "SELECT COALESCE(SUM(CAST(t.price_paid AS REAL)),0) r FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.artist_id = ?"
  ).get(artistId).r;
  const followers = db.prepare('SELECT COUNT(*) c FROM follows WHERE artist_id = ?').get(artistId).c;
  const avgRating = db.prepare(
    "SELECT AVG(r.rating) a FROM reviews r JOIN events e ON e.id = r.event_id WHERE e.artist_id = ?"
  ).get(artistId).a;

  // artistId vient de req.user.id en priorité (l'artiste consulte SES stats) ;
  // il ne retombe sur req.body.id que pour un appel non authentifié (page
  // publique d'un artiste). Dans ce cas-là il ne faut jamais renvoyer son
  // wallet/revenu réel à un tiers non connecté.
  const isSelf = !!(req.user && Number(req.user.id) === Number(artistId));
  return res.json({
    status: 'success',
    data: {
      artist_name: artist.artist_name || artist.full_name,
      total_tickets_sold: ticketsSold,
      current_wallet: isSelf ? (artist.wallet || '0') : null,
      total_revenue: isSelf ? Math.round(revenue) : null,
      followers_count: followers,
      event_count: eventCount,
      upcoming_events_count: upcoming,
      past_events_count: past,
      average_rating: avgRating ? Math.round(avgRating * 10) / 10 : 0,
      hourly_velocity: [],
    },
  });
});
router.post('/get-event-stats-by-user-id', optionalAuth, (req, res) => {
  const artistId = req.user?.id || req.body?.id;
  const total_events = db.prepare('SELECT COUNT(*) c FROM events WHERE artist_id = ?').get(artistId).c;
  const total_tickets = db.prepare(
    'SELECT COUNT(*) c FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.artist_id = ?'
  ).get(artistId).c;
  return res.json({ status: 'success', data: { total_events, total_tickets } });
});

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
// Ces 5 routes étaient des stubs : réponse "success" toujours renvoyée sans
// jamais rien écrire en base (add-bank n'insérait rien, get-user-banks
// renvoyait [] en dur, withdraw/add ne débitait rien ni ne créait de ligne
// dans `withdrawals`). Un artiste ajoutant son RIB et demandant un retrait
// n'était jamais payé. Corrigé pour persister réellement (table `banks` +
// `withdrawals` déjà utilisée côté admin).
function serializeBanksList(userId) {
  const list = db.prepare('SELECT * FROM banks WHERE user_id = ? ORDER BY id DESC').all(userId);
  return { status: 'success', count: list.length, list };
}

router.post('/withdraw/add-bank', requireAuth, (req, res) => {
  const b = req.body || {};
  db.prepare(
    `INSERT INTO banks (user_id, bank_name, account_name, account_number, swift_code, routing_number)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).run(req.user.id, b.bank_name || '', b.account_name || '', b.account_number || '', b.swift_code || '', b.routing_number || '');
  return res.json(serializeBanksList(req.user.id));
});
router.post('/withdraw/get-user-banks', requireAuth, (req, res) => {
  return res.json(serializeBanksList(req.user.id));
});
router.post('/withdraw/update-bank', requireAuth, (req, res) => {
  const b = req.body || {};
  const bankId = Number(b.bank_id || b.id);
  const bank = db.prepare('SELECT id FROM banks WHERE id = ? AND user_id = ?').get(bankId, req.user.id);
  if (!bank) return fail(res, 'Compte bancaire introuvable.', 404);
  db.prepare(
    `UPDATE banks SET bank_name = ?, account_name = ?, account_number = ?, swift_code = ?, routing_number = ?, updated_at = datetime('now')
     WHERE id = ?`
  ).run(b.bank_name || '', b.account_name || '', b.account_number || '', b.swift_code || '', b.routing_number || '', bankId);
  return res.json(serializeBanksList(req.user.id));
});
router.post('/withdraw/delete-bank', requireAuth, (req, res) => {
  const bankId = Number(req.body?.bank_id || req.body?.id);
  db.prepare('DELETE FROM banks WHERE id = ? AND user_id = ?').run(bankId, req.user.id);
  return res.json(serializeBanksList(req.user.id));
});
router.post('/withdraw/add', requireAuth, (req, res) => {
  const b = req.body || {};
  const amount = parseFloat(b.amount) || 0;
  if (amount <= 0) return fail(res, 'Montant invalide.', 422);
  const bank = db.prepare('SELECT * FROM banks WHERE id = ? AND user_id = ?').get(Number(b.bank_id), req.user.id);
  if (!bank) return fail(res, 'Compte bancaire introuvable.', 404);
  const user = db.prepare('SELECT wallet FROM users WHERE id = ?').get(req.user.id);
  const balance = parseFloat(user?.wallet) || 0;
  if (amount > balance) return fail(res, 'Solde insuffisant.', 402, { balance });
  const bankLabel = `${bank.bank_name} •••• ${(bank.account_number || '').slice(-4)}`;
  const doWithdraw = db.transaction(() => {
    db.prepare('UPDATE users SET wallet = ? WHERE id = ?').run((balance - amount).toFixed(2), req.user.id);
    db.prepare(
      `INSERT INTO withdrawals (user_id, amount, status, bank) VALUES (?, ?, 'pending', ?)`
    ).run(req.user.id, amount.toFixed(2), bankLabel);
  });
  doWithdraw();
  return res.json({ status: 'success', message: 'Withdrawal requested.' });
});
// Liste des artistes suivis par l'utilisateur. L'app fait un POST avec
// {user_id} ; on accepte aussi GET. Shape attendu par FollowModel :
// { data: { followers_count, following: [ {id, full_name, profile_image, email} ] } }.
function followingHandler(req, res) {
  const userId = req.user?.id || req.body?.user_id;
  if (!userId) return ok(res, { followers_count: 0, following: [] });
  const rows = db
    .prepare('SELECT u.* FROM users u JOIN follows f ON f.artist_id = u.id WHERE f.follower_id = ?')
    .all(userId);
  return ok(res, { followers_count: rows.length, following: rows.map((u) => serializeUser(u)) });
}
router.get('/following', optionalAuth, followingHandler);
router.post('/following', optionalAuth, followingHandler);

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

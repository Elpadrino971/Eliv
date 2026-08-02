'use strict';

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');

const { init } = require('./db');
const authRoutes = require('./routes/auth.routes');
const eventRoutes = require('./routes/events.routes');
const miscRoutes = require('./routes/misc.routes');
const adminRoutes = require('./routes/admin.routes');
const muxWebhookRoutes = require('./routes/mux.routes');
const stripeWebhookRoutes = require('./routes/stripe.routes');
const revenuecatWebhookRoutes = require('./routes/revenuecat.routes');

init();

const app = express();
app.use(cors());

// Webhooks Mux/Stripe : montés AVANT express.json() car la vérification de
// signature a besoin du corps brut exact (Buffer), pas du JSON déjà parsé.
app.use('/api/mux/webhook', express.raw({ type: '*/*' }), muxWebhookRoutes);
app.use('/api/stripe/webhook', express.raw({ type: '*/*' }), stripeWebhookRoutes);

// L'app Flutter envoie soit du form-urlencoded (Map<String,String>),
// soit du JSON, soit du multipart (uploads). On gère les trois.
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const fs = require('fs');
const uploadsDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true }); // dossier temp multer (créé au démarrage)
const upload = multer({ dest: uploadsDir });
app.use(upload.any()); // accepte n'importe quel champ fichier (profile_picture, images[], …)

// Fichiers statiques (covers, profils, vidéos, gifts) — mêmes chemins que l'API live
app.use('/profiles', express.static(path.join(__dirname, '..', 'storage', 'profiles')));
app.use('/events/covers', express.static(path.join(__dirname, '..', 'storage', 'covers')));
app.use('/events/videos', express.static(path.join(__dirname, '..', 'storage', 'videos')));
app.use('/giftImages', express.static(path.join(__dirname, '..', 'storage', 'gifts')));
app.use('/splash', express.static(path.join(__dirname, '..', 'storage', 'splash')));

// Santé
app.get('/', (req, res) => res.json({ status: 'success', service: 'vybzzz-backend', version: '1.0.0' }));
app.get('/api', (req, res) => res.json({ status: 'success', message: 'VYBZZZ API up' }));

// Pages de retour Stripe Checkout (success_url / cancel_url) — le webhook
// active déjà l'abonnement en tâche de fond, ces pages ne font qu'informer.
app.get('/subscribe/merci', (req, res) => res.send(
  '<html><body style="font-family:sans-serif;text-align:center;padding:60px;background:#071426;color:#f4efe6"><h1>Merci ! 🎉</h1><p>Ton abonnement est en cours d\'activation, retourne sur l\'app VybzzZ.</p></body></html>'
));
app.get('/subscribe/annule', (req, res) => res.send(
  '<html><body style="font-family:sans-serif;text-align:center;padding:60px;background:#071426;color:#f4efe6"><h1>Paiement annulé</h1><p>Aucun montant n\'a été prélevé. Retourne sur l\'app VybzzZ pour réessayer.</p></body></html>'
));

// Dashboard admin web (statique) sous /admin
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));

// API admin sous /api/admin
app.use('/api/admin', adminRoutes);

// Toutes les routes API sous /api (comme baseAPI = mainIP/api)
app.use('/api', authRoutes);
app.use('/api', eventRoutes);
app.use('/api', miscRoutes);

// Webhook RevenueCat : pas de signature HMAC (juste un header Authorization
// fixe), donc pas besoin de corps brut -> monté normalement après express.json().
app.use('/api/revenuecat/webhook', revenuecatWebhookRoutes);

// 404 JSON propre
app.use((req, res) => res.status(404).json({ status: 'error', message: `Not found: ${req.method} ${req.path}` }));

// Erreurs
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ status: 'error', message: err.message });
});

module.exports = app;

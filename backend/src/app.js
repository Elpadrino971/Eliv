'use strict';

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');

const { init } = require('./db');
const authRoutes = require('./routes/auth.routes');
const eventRoutes = require('./routes/events.routes');
const miscRoutes = require('./routes/misc.routes');

init();

const app = express();
app.use(cors());

// L'app Flutter envoie soit du form-urlencoded (Map<String,String>),
// soit du JSON, soit du multipart (uploads). On gère les trois.
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const upload = multer({ dest: path.join(__dirname, '..', 'uploads') });
app.use(upload.any()); // accepte n'importe quel champ fichier (profile_picture, images[], …)

// Fichiers statiques (covers, profils, vidéos, gifts) — mêmes chemins que l'API live
app.use('/profiles', express.static(path.join(__dirname, '..', 'storage', 'profiles')));
app.use('/events/covers', express.static(path.join(__dirname, '..', 'storage', 'covers')));
app.use('/events/videos', express.static(path.join(__dirname, '..', 'storage', 'videos')));
app.use('/giftImages', express.static(path.join(__dirname, '..', 'storage', 'gifts')));

// Santé
app.get('/', (req, res) => res.json({ status: 'success', service: 'vybzzz-backend', version: '1.0.0' }));
app.get('/api', (req, res) => res.json({ status: 'success', message: 'VYBZZZ API up' }));

// Toutes les routes API sous /api (comme baseAPI = mainIP/api)
app.use('/api', authRoutes);
app.use('/api', eventRoutes);
app.use('/api', miscRoutes);

// 404 JSON propre
app.use((req, res) => res.status(404).json({ status: 'error', message: `Not found: ${req.method} ${req.path}` }));

// Erreurs
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ status: 'error', message: err.message });
});

module.exports = app;

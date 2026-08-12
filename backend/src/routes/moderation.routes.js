'use strict';

/**
 * Webhook de callback Sightengine (modération vidéo/live asynchrone).
 * Sightengine POST ici le résultat frame par frame après avoir échantillonné
 * un replay ou surveillé un live. Monté sous /api/moderation dans app.js
 * (après express.json — le corps est du JSON classique).
 *
 * Authentifié par un jeton en query (?token=), vérifié dans le service. La
 * cible (type + id) est portée par la query (tt/tid) qu'on a nous-mêmes mise
 * dans l'URL de callback au lancement de la vérification.
 */

const express = require('express');
const router = express.Router();
const moderation = require('../services/moderation');

router.post('/callback', (req, res) => {
  if (!moderation.verifyCallbackToken(req.query.token)) {
    return res.status(401).json({ status: 'error', message: 'Jeton de callback invalide.' });
  }
  try {
    const result = moderation.handleCallback(req.query, req.body || {});
    return res.json({ status: 'success', ...result });
  } catch (e) {
    console.error('[moderation callback]', e.message);
    // On répond 200 quand même : inutile que Sightengine ré-essaie en boucle.
    return res.json({ status: 'success', handled: false });
  }
});

module.exports = router;

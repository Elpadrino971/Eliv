'use strict';

/**
 * Vue d'ensemble PUBLIQUE (OPRAS) pour la page apporteurs adossée à l'admin.
 * Ne renvoie que des AGRÉGATS (compteurs + compte à rebours 1er paiement) :
 * aucune donnée personnelle, aucune info par utilisateur. C'est volontairement
 * public/lecture seule pour pouvoir être branché sur une page légère montrée
 * aux apporteurs d'affaires, sans exposer l'admin.
 */

const express = require('express');
const router = express.Router();
const { platformCounters, payoutCountdown, ok } = require('../helpers');

router.get('/overview', (req, res) => {
  const counters = platformCounters();
  return ok(res, {
    users: counters.users_total,
    fans: counters.fans,
    artists: counters.artists,
    validated_artists: counters.validated_artists,
    payout: payoutCountdown(),
    generated_at: new Date().toISOString(),
  });
});

module.exports = router;

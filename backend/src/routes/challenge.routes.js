'use strict';
// VybzzZ Live Challenge — routes publiques (site vybzzz.online). Monté sur /api/challenge.
const express = require('express');
const { fail } = require('../helpers');
const ch = require('../services/challenge');

const router = express.Router();
const ipOf = (req) => (req.headers['x-forwarded-for'] || req.ip || '').toString().split(',')[0].trim();

// Config publique (dates, pondérations, lots) -> compte à rebours + page
router.get('/config', (req, res) => res.json({ status: 'success', data: ch.publicConfig() }));

// Inscription d'un artiste -> code + lien personnel
router.post('/register', (req, res) => {
  try {
    const b = req.body || {};
    const r = ch.registerArtist({ ...b, ip: ipOf(req) });
    return res.json({
      status: 'success',
      message: r.already ? 'Tu es déjà inscrit : voici ton lien.' : 'Inscription enregistrée.',
      data: { code: r.code, link: r.link, stage_name: r.stage_name, already: r.already },
    });
  } catch (e) {
    return fail(res, e.message, 422);
  }
});

// Infos publiques d'un artiste (page d'atterrissage du lien) + comptage du clic
router.get('/artist/:code', (req, res) => {
  const a = ch.artistByCode(req.params.code);
  if (!a || a.status === 'disqualified') return fail(res, 'Lien invalide.', 404);
  if (req.query.click !== '0') ch.countClick(a.id);
  return res.json({ status: 'success', data: { code: a.code, stage_name: a.stage_name } });
});

// Pré-inscription d'un fan via le lien
router.post('/join', (req, res) => {
  try {
    const b = req.body || {};
    const r = ch.joinViaLink({ code: b.code, email: b.email, name: b.name, ip: ipOf(req), ua: req.headers['user-agent'] });
    return res.json({ status: 'success', data: r });
  } catch (e) {
    return fail(res, e.message, 422);
  }
});

// Classement public (Top 40)
router.get('/leaderboard', (req, res) => {
  const rows = ch.leaderboard().slice(0, ch.CONFIG.topN).map((r) => ({
    rank: r.rank, stage_name: r.stage_name, score: r.score, eligible: r.eligible, lives: r.lives, referrals: r.referrals,
  }));
  return res.json({ status: 'success', data: { config: ch.publicConfig(), top: rows } });
});

// Tableau de bord de l'artiste (par son code personnel)
router.get('/stats/:code', (req, res) => {
  const a = ch.artistByCode(req.params.code);
  if (!a) return fail(res, 'Code inconnu.', 404);
  const row = ch.leaderboard().find((r) => r.id === a.id) || null;
  return res.json({
    status: 'success',
    data: {
      stage_name: a.stage_name, code: a.code, link: ch.linkFor(a.code), status: a.status, linked: !!a.user_id,
      stats: row,
    },
  });
});

module.exports = router;

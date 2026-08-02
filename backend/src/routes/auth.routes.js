'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { serializeUser, fail } = require('../helpers');
const { hash, compare, sign, requireAuth, optionalAuth } = require('../auth');
const { saveUpload } = require('../uploads');
const emailService = require('../services/email');

const OTP_TTL_MINUTES = 15;

// Code démo tant qu'aucun service d'email n'est configuré (voir services/email.js).
// Une fois RESEND_API_KEY défini, un vrai code aléatoire est généré et envoyé.
function newOtp() {
  return emailService.isConfigured() ? emailService.generateOtp() : '1234';
}

function otpExpiryIso() {
  return new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000).toISOString();
}

// otp_expires_at est NULL pour les comptes créés avant ce fix (ou tant que
// l'email n'est pas configuré) -> pas d'expiration forcée dans ce cas,
// comportement démo inchangé.
function otpExpired(user) {
  if (!user.otp_expires_at) return false;
  return new Date(user.otp_expires_at).getTime() < Date.now();
}

function authResponse(res, user, message = 'OK') {
  return res.json({
    status: 'success',
    message,
    token: sign(user),
    data: serializeUser(user, { full: true }),
  });
}

function genReferralCode(name) {
  const base = (name || 'VYB').replace(/[^a-zA-Z]/g, '').slice(0, 4).toUpperCase() || 'VYB';
  return `${base}${Math.floor(1000 + Math.random() * 9000)}`;
}

// POST /api/sign-up
router.post('/sign-up', (req, res) => {
  const b = req.body || {};
  const email = (b.email || '').trim().toLowerCase();
  if (!email) return fail(res, 'Validation error', 422, { email: ['The email field is required.'] });
  if (!b.password) return fail(res, 'Validation error', 422, { password: ['The password field is required.'] });

  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (existing) return fail(res, 'Validation error', 422, { email: ['The email has already been taken.'] });

  const isArtist = b.role === 'artist' || b.is_artist === '1' || b.is_artist === 1;
  const otp = newOtp();
  const info = db
    .prepare(
      `INSERT INTO users (email, password, full_name, artist_name, phone_number, role, is_artist,
        registration_type, otp_code, otp_expires_at, referral_code)
       VALUES (@email, @password, @full_name, @artist_name, @phone_number, @role, @is_artist,
        @registration_type, @otp_code, @otp_expires_at, @referral_code)`
    )
    .run({
      email,
      password: hash(b.password),
      full_name: b.full_name || null,
      artist_name: b.artist_name || null,
      phone_number: b.phone_number || null,
      role: isArtist ? 'artist' : 'user',
      is_artist: isArtist ? 1 : 0,
      registration_type: b.registration_type || 'email',
      otp_code: otp,
      otp_expires_at: emailService.isConfigured() ? otpExpiryIso() : null,
      referral_code: genReferralCode(b.full_name || b.artist_name),
    });

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
  if (emailService.isConfigured()) {
    emailService.sendOtpEmail(email, otp).catch((e) => console.error('[email] OTP sign-up:', e.message));
    return authResponse(res, user, 'Account created. Check your email for the verification code.');
  }
  return authResponse(res, user, 'Account created. Verify with OTP 1234 (demo).');
});

// POST /api/login
router.post('/login', (req, res) => {
  const b = req.body || {};
  const email = (b.email || '').trim().toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user || !compare(b.password, user.password)) {
    return fail(res, 'These credentials do not match our records.', 401);
  }
  return authResponse(res, user, 'Logged in.');
});

// POST /api/social-login  (Google/Apple : crée l'utilisateur s'il n'existe pas)
router.post('/social-login', (req, res) => {
  const b = req.body || {};
  const email = (b.email || '').trim().toLowerCase();
  if (!email) return fail(res, 'Validation error', 422, { email: ['The email field is required.'] });
  let user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) {
    const info = db
      .prepare(
        `INSERT INTO users (email, full_name, profile_image, registration_type, is_verified, referral_code)
         VALUES (?, ?, ?, ?, 1, ?)`
      )
      .run(email, b.full_name || null, b.profile_image || null, b.registration_type || 'google', genReferralCode(b.full_name));
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
  }
  return authResponse(res, user, 'Logged in.');
});

// POST /api/verify  (OTP)
router.post('/verify', (req, res) => {
  const b = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ? OR id = ?').get((b.email || '').toLowerCase(), b.user_id || 0);
  if (!user) return fail(res, 'User not found.', 404);
  if (String(b.otp_code || b.otp) !== String(user.otp_code)) return fail(res, 'Invalid OTP code.', 422);
  if (otpExpired(user)) return fail(res, 'OTP code expired. Request a new one.', 422);
  db.prepare('UPDATE users SET is_verified = 1, updated_at = datetime(\'now\') WHERE id = ?').run(user.id);
  const fresh = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  return authResponse(res, fresh, 'Verified.');
});

// POST /api/forget  (envoi d'un code de reset)
router.post('/forget', (req, res) => {
  const email = (req.body?.email || '').toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) return fail(res, 'No account for this email.', 404);
  const otp = newOtp();
  db.prepare('UPDATE users SET otp_code = ?, otp_expires_at = ? WHERE id = ?').run(
    otp,
    emailService.isConfigured() ? otpExpiryIso() : null,
    user.id
  );
  if (emailService.isConfigured()) {
    emailService.sendOtpEmail(email, otp).catch((e) => console.error('[email] OTP forget:', e.message));
    return res.json({ status: 'success', message: 'Reset code sent to your email.' });
  }
  return res.json({ status: 'success', message: 'Reset code sent (demo: 1234).' });
});

// POST /api/reset-password
router.post('/reset-password', (req, res) => {
  const b = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get((b.email || '').toLowerCase());
  if (!user) return fail(res, 'User not found.', 404);
  // otp_code était vérifié UNIQUEMENT s'il était fourni -> l'omettre du body
  // contournait totalement la vérification et permettait de changer le mot de
  // passe de N'IMPORTE QUEL compte (y compris admin) sans connaître son OTP.
  if (!b.otp_code || String(b.otp_code) !== String(user.otp_code)) {
    return fail(res, 'Invalid OTP.', 422);
  }
  if (otpExpired(user)) return fail(res, 'OTP code expired. Request a new one.', 422);
  db.prepare('UPDATE users SET password = ? WHERE id = ?').run(hash(b.password), user.id);
  return res.json({ status: 'success', message: 'Password updated.' });
});

// POST /api/update-password  (authentifié)
router.post('/update-password', requireAuth, (req, res) => {
  const b = req.body || {};
  if (!compare(b.old_password || b.current_password, req.user.password)) {
    return fail(res, 'Current password is incorrect.', 422);
  }
  db.prepare('UPDATE users SET password = ? WHERE id = ?').run(hash(b.password || b.new_password), req.user.id);
  return res.json({ status: 'success', message: 'Password changed.' });
});

// POST /api/get-user  (body: { id }) — sert à la fois à rafraîchir SON PROPRE
// profil (auth_controller.getUserModel) et à afficher le profil PUBLIC d'un
// autre user/artiste (event_controller.getUserModel, page artiste). Aucune
// auth requise n'est possible (usage public légitime), donc on ne renvoie les
// champs privés (email/téléphone/wallet/points/adresse) que si l'appelant EST
// ce user (token valide correspondant au même id) — jamais pour un tiers.
router.post('/get-user', optionalAuth, (req, res) => {
  const id = req.body?.id;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  if (!user) return fail(res, 'User not found.', 404);
  const isSelf = !!(req.user && Number(req.user.id) === Number(id));
  return res.json({ status: 'success', data: serializeUser(user, { full: isSelf }) });
});

// POST /api/update-profile  (authentifié ; accepte JSON ou multipart)
router.post('/update-profile', requireAuth, (req, res) => {
  const b = req.body || {};
  const fields = [
    'full_name', 'artist_name', 'phone_number', 'dob', 'bio', 'address',
    'latitude', 'longitude', 'experience', 'artist_bio',
  ];
  const sets = [];
  const vals = {};
  for (const f of fields) {
    if (b[f] !== undefined) { sets.push(`${f} = @${f}`); vals[f] = b[f]; }
  }
  // Devenir artiste : le parcours "Devenir artiste" (basic_info -> bank info)
  // envoie artist_name mais rien ne basculait jamais is_artist à 1 -> le compte
  // restait "fan" pour toujours malgré un profil artiste complet.
  if (b.artist_name !== undefined && String(b.artist_name).trim() !== '') {
    sets.push('is_artist = 1');
  }
  // multer est monté en upload.any() -> req.files est un TABLEAU. On passe par
  // saveUpload (qui trouve le fichier par nom de champ, le copie dans storage/
  // et renvoie l'URL absolue). L'ancien `req.files.profile_picture` était
  // toujours undefined -> la photo n'était jamais enregistrée.
  const uploadedPhoto = saveUpload(req, ['profile_picture', 'profile_image', 'image', 'photo'], 'profiles', 'profiles');
  if (uploadedPhoto) {
    sets.push('profile_image = @profile_image');
    vals.profile_image = uploadedPhoto;
  }
  // Photo de profil ARTISTE : champ multipart séparé ('artist_profile', cf.
  // auth_controller.dart:updateProfile -> hitMultipartAPI key2), jamais
  // recherché avant -> le fichier envoyé était toujours ignoré silencieusement.
  const uploadedArtistPhoto = saveUpload(req, ['artist_profile'], 'profiles', 'profiles');
  if (uploadedArtistPhoto) {
    sets.push('artist_profile = @artist_profile');
    vals.artist_profile = uploadedArtistPhoto;
  }
  if (sets.length) {
    vals.id = req.user.id;
    db.prepare(`UPDATE users SET ${sets.join(', ')}, updated_at = datetime('now') WHERE id = @id`).run(vals);
  }
  const fresh = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  return res.json({ status: 'success', message: 'Profile updated.', data: serializeUser(fresh, { full: true }) });
});

// POST /api/delete-account
router.post('/delete-account', requireAuth, (req, res) => {
  db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
  return res.json({ status: 'success', message: 'Account deleted.' });
});

module.exports = router;

'use strict';

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { serializeUser, fail } = require('../helpers');
const { hash, compare, sign, requireAuth } = require('../auth');

function authResponse(res, user, message = 'OK') {
  return res.json({
    status: 'success',
    message,
    token: sign(user),
    data: serializeUser(user),
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
  const info = db
    .prepare(
      `INSERT INTO users (email, password, full_name, artist_name, phone_number, role, is_artist,
        registration_type, otp_code, referral_code)
       VALUES (@email, @password, @full_name, @artist_name, @phone_number, @role, @is_artist,
        @registration_type, @otp_code, @referral_code)`
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
      otp_code: '1234', // démo : OTP fixe (en prod : envoi SMS/email)
      referral_code: genReferralCode(b.full_name || b.artist_name),
    });

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
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
  db.prepare('UPDATE users SET is_verified = 1, updated_at = datetime(\'now\') WHERE id = ?').run(user.id);
  const fresh = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
  return authResponse(res, fresh, 'Verified.');
});

// POST /api/forget  (envoi d'un code — démo : 1234)
router.post('/forget', (req, res) => {
  const email = (req.body?.email || '').toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) return fail(res, 'No account for this email.', 404);
  db.prepare('UPDATE users SET otp_code = ? WHERE id = ?').run('1234', user.id);
  return res.json({ status: 'success', message: 'Reset code sent (demo: 1234).' });
});

// POST /api/reset-password
router.post('/reset-password', (req, res) => {
  const b = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get((b.email || '').toLowerCase());
  if (!user) return fail(res, 'User not found.', 404);
  if (b.otp_code && String(b.otp_code) !== String(user.otp_code)) return fail(res, 'Invalid OTP.', 422);
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

// POST /api/get-user  (body: { id })
router.post('/get-user', (req, res) => {
  const id = req.body?.id;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  if (!user) return fail(res, 'User not found.', 404);
  return res.json({ status: 'success', data: serializeUser(user) });
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
  if (req.files?.profile_picture) {
    sets.push('profile_image = @profile_image');
    vals.profile_image = req.files.profile_picture;
  }
  if (sets.length) {
    vals.id = req.user.id;
    db.prepare(`UPDATE users SET ${sets.join(', ')}, updated_at = datetime('now') WHERE id = @id`).run(vals);
  }
  const fresh = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  return res.json({ status: 'success', message: 'Profile updated.', data: serializeUser(fresh) });
});

// POST /api/delete-account
router.post('/delete-account', requireAuth, (req, res) => {
  db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
  return res.json({ status: 'success', message: 'Account deleted.' });
});

module.exports = router;

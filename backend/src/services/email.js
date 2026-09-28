'use strict';

/**
 * Envoi d'email transactionnel via Resend (OTP de vérification / reset mot
 * de passe). Appel REST direct (fetch natif), pas de SDK ajouté.
 *
 * Tant que RESEND_API_KEY n'est pas configuré, isConfigured() renvoie false
 * et les routes appelantes (auth.routes.js) retombent sur l'ancien
 * comportement démo (OTP fixe '1234', pas d'email) -> rien ne casse pendant
 * que le domaine d'envoi est en cours de vérification côté Resend.
 */

const crypto = require('crypto');
const { db } = require('../db');

const RESEND_API_KEY = process.env.RESEND_API_KEY;
// A définir une fois le domaine vérifié dans Resend, ex: 'VYBZZZ <no-reply@vybzzz.online>'.
const EMAIL_FROM = process.env.EMAIL_FROM || 'VYBZZZ <onboarding@resend.dev>';

function isConfigured() {
  return Boolean(RESEND_API_KEY);
}

// Un e-mail qui n'arrive pas bloque une inscription. Chaque tentative est donc
// tracée, succès comme échec, et consultable depuis l'admin.
function logSend(recipient, kind, ok, error) {
  try {
    db.prepare('INSERT INTO email_log (recipient, kind, ok, error) VALUES (?, ?, ?, ?)')
      .run(String(recipient || '').slice(0, 120), kind || 'otp', ok ? 1 : 0,
           error ? String(error).slice(0, 300) : null);
    db.prepare("DELETE FROM email_log WHERE created_at < datetime('now','-30 days')").run();
  } catch (_) { /* la journalisation ne doit jamais bloquer un envoi */ }
}

async function sendEmail({ to, subject, html, kind }) {
  if (!isConfigured()) {
    const err = new Error('Email non configuré (RESEND_API_KEY manquant).');
    err.code = 'EMAIL_NOT_CONFIGURED';
    throw err;
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: EMAIL_FROM, to: [to], subject, html }),
    // Resend qui ne répond pas ne doit pas bloquer une inscription indéfiniment.
    signal: AbortSignal.timeout(8000),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = json.message || JSON.stringify(json);
    logSend(to, kind, false, `Resend ${res.status}: ${detail}`);
    throw new Error(`Resend API ${res.status}: ${detail}`);
  }
  logSend(to, kind, true, null);
  return json;
}

/** Derniers envois, pour le diagnostic dans l'admin. */
function recentLog(limit = 25) {
  return db.prepare('SELECT recipient, kind, ok, error, created_at FROM email_log ORDER BY id DESC LIMIT ?')
    .all(Math.min(limit, 100));
}
function counts(hours = 24) {
  const h = Math.min(hours, 720);
  return db.prepare(`SELECT COUNT(*) total, SUM(CASE WHEN ok = 0 THEN 1 ELSE 0 END) echecs
                       FROM email_log WHERE created_at >= datetime('now','-${h} hours')`).get();
}

/** L'expéditeur est-il encore l'adresse bac à sable de Resend ? Dans ce cas
 *  Resend REFUSE tout destinataire autre que le propriétaire du compte : les
 *  codes n'arrivent qu'à une seule personne, jamais aux inscrits. */
function usingSandboxSender() {
  return /resend\.dev/i.test(EMAIL_FROM);
}

// Code à 6 chiffres tiré du générateur cryptographique (Math.random est
// prévisible : un attaquant observant quelques codes peut en déduire les
// suivants).
function generateOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

const SITE = process.env.SITE_BASE_URL || 'https://vybzzz.online';
const API = process.env.PUBLIC_BASE_URL || 'https://api.vybzzz.online';

function otpEmailHtml(code, email) {
  // Lien de validation en un clic : indispensable tant que la saisie du code
  // est défaillante sur Android (voir otp_screen.dart). Il valide le compte
  // sans passer par les six cases de l'application.
  const link = email
    ? `${API}/api/verify-link?e=${encodeURIComponent(email)}&c=${encodeURIComponent(code)}`
    : null;
  return otpEmailBody(code, link);
}

function otpEmailBody(code, link) {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; color:#1a1a1a;">
      <h2 style="color:#c9a227; letter-spacing: 2px;">VYBZZZ</h2>
      <p>Voici ton code de vérification :</p>
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px;">${code}</p>
      ${link ? `<p style="margin:22px 0 26px">
        <a href="${link}" style="display:inline-block;background:#c9a227;color:#0A1226;text-decoration:none;
           font-weight:bold;padding:14px 26px;border-radius:10px;font-size:15px">Valider mon compte en un clic</a>
      </p>
      <p style="color:#666; font-size: 13px;">Si le bouton ne fonctionne pas, saisis le code ci-dessus dans l'application.</p>` : ''}
      <p style="color:#666; font-size: 14px;">
        Ce code expire dans 15 minutes. Si tu n'es pas à l'origine de cette
        demande, ignore simplement cet email.
      </p>
    </div>
  `;
}

async function sendOtpEmail(to, code) {
  return sendEmail({
    to,
    subject: `${code} — Ton code de vérification VybzzZ`,
    html: otpEmailHtml(code, to),
    kind: 'otp',
  });
}

module.exports = { isConfigured, sendEmail, generateOtp, sendOtpEmail, recentLog, counts, usingSandboxSender, EMAIL_FROM };

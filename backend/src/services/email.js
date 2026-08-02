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

const RESEND_API_KEY = process.env.RESEND_API_KEY;
// A définir une fois le domaine vérifié dans Resend, ex: 'VYBZZZ <no-reply@vybzzz.online>'.
const EMAIL_FROM = process.env.EMAIL_FROM || 'VYBZZZ <onboarding@resend.dev>';

function isConfigured() {
  return Boolean(RESEND_API_KEY);
}

async function sendEmail({ to, subject, html }) {
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
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(`Resend API ${res.status}: ${json.message || JSON.stringify(json)}`);
    throw err;
  }
  return json;
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function otpEmailHtml(code) {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; color:#1a1a1a;">
      <h2 style="color:#c9a227; letter-spacing: 2px;">VYBZZZ</h2>
      <p>Voici ton code de vérification :</p>
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px;">${code}</p>
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
    subject: `${code} — Ton code de vérification VYBZZZ`,
    html: otpEmailHtml(code),
  });
}

module.exports = { isConfigured, generateOtp, sendOtpEmail };

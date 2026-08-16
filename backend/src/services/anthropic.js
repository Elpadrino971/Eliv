'use strict';

/**
 * Génération de texte pour l'admin (descriptions de concert / bios artiste).
 * Multi-fournisseur, appel REST direct (fetch natif), pas de SDK :
 *   - Google Gemini  -> GRATUIT (clé Google AI Studio, gros quota gratuit).
 *   - Anthropic Claude -> payant (repli si pas de clé Gemini).
 * Configure GEMINI_API_KEY (recommandé, gratuit) OU ANTHROPIC_API_KEY.
 */

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-5';

function isConfigured() {
  return Boolean(GEMINI_API_KEY || ANTHROPIC_API_KEY);
}

async function _gemini(prompt, maxTokens) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: maxTokens, temperature: 0.9 },
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`Gemini API ${res.status}: ${json.error?.message || JSON.stringify(json)}`);
  }
  const text = (json.candidates?.[0]?.content?.parts || [])
    .map((p) => p.text || '')
    .join('');
  return text.trim();
}

async function _anthropic(prompt, maxTokens) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`Anthropic API ${res.status}: ${json.error?.message || JSON.stringify(json)}`);
  }
  return (json.content?.[0]?.text || '').trim();
}

async function generateText(prompt, { maxTokens = 300 } = {}) {
  if (!isConfigured()) {
    const err = new Error('IA non configurée (GEMINI_API_KEY ou ANTHROPIC_API_KEY manquant).');
    err.code = 'AI_NOT_CONFIGURED';
    throw err;
  }
  // Gemini d'abord (gratuit), sinon Claude.
  if (GEMINI_API_KEY) return _gemini(prompt, maxTokens);
  return _anthropic(prompt, maxTokens);
}

module.exports = { isConfigured, generateText };

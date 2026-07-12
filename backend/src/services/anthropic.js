'use strict';

/**
 * Génération de texte via l'API Claude (Anthropic) — utilisé pour rédiger
 * des descriptions de concert / bios artiste dans l'admin panel. Appel REST
 * direct (fetch natif), pas de SDK ajouté.
 */

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const MODEL = 'claude-sonnet-5';

function isConfigured() {
  return Boolean(ANTHROPIC_API_KEY);
}

async function generateText(prompt, { maxTokens = 300 } = {}) {
  if (!isConfigured()) {
    const err = new Error('IA non configurée (ANTHROPIC_API_KEY manquant).');
    err.code = 'ANTHROPIC_NOT_CONFIGURED';
    throw err;
  }
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  const json = await res.json();
  if (!res.ok) {
    const err = new Error(`Anthropic API ${res.status}: ${json.error?.message || JSON.stringify(json)}`);
    throw err;
  }
  return (json.content?.[0]?.text || '').trim();
}

module.exports = { isConfigured, generateText };

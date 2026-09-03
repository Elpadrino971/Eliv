#!/usr/bin/env node
'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Serveur MCP VybzzZ
//
// Expose la plateforme VybzzZ à un client MCP (Claude Desktop, un agent, …) sous
// forme d'outils : stats, répartition par pays, utilisateurs, concerts,
// réunions VIBE et assistant IA de réunion.
//
// Il s'appuie sur l'API admin existante (api.vybzzz.online/api). Il se connecte
// une fois avec un compte admin (variables d'env), garde le token JWT en cache,
// et le rafraîchit automatiquement en cas d'expiration.
//
// Config (variables d'environnement) :
//   VYBZZZ_API_BASE        (def. https://api.vybzzz.online/api)
//   VYBZZZ_ADMIN_EMAIL     e-mail du compte admin
//   VYBZZZ_ADMIN_PASSWORD  mot de passe du compte admin
//
// Lancement : node server.js  (transport stdio)
// ─────────────────────────────────────────────────────────────────────────────

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';

const API_BASE = (process.env.VYBZZZ_API_BASE || 'https://api.vybzzz.online/api').replace(/\/$/, '');
const ADMIN_EMAIL = process.env.VYBZZZ_ADMIN_EMAIL || '';
const ADMIN_PASSWORD = process.env.VYBZZZ_ADMIN_PASSWORD || '';

let _token = null;

async function login() {
  if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
    throw new Error('Identifiants manquants : définis VYBZZZ_ADMIN_EMAIL et VYBZZZ_ADMIN_PASSWORD.');
  }
  const r = await fetch(API_BASE + '/admin/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.token) throw new Error('Connexion admin refusée : ' + (j.message || r.status));
  _token = j.token;
  return _token;
}

// Appel API admin, avec (re)login automatique sur 401.
async function apiAdmin(method, path, body, _retried) {
  if (!_token) await login();
  const opt = { method, headers: { Authorization: 'Bearer ' + _token } };
  if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
  const r = await fetch(API_BASE + '/admin' + path, opt);
  if (r.status === 401 && !_retried) { _token = null; return apiAdmin(method, path, body, true); }
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((j && j.message) || ('Erreur API ' + r.status));
  return j.data !== undefined ? j.data : j;
}

const qs = (obj) => {
  const p = Object.entries(obj || {}).filter(([, v]) => v !== undefined && v !== null && v !== '');
  return p.length ? '?' + p.map(([k, v]) => k + '=' + encodeURIComponent(v)).join('&') : '';
};

// ─── Définition des outils ───
const TOOLS = [
  {
    name: 'get_stats',
    description: 'Statistiques globales de la plateforme VybzzZ : nombre de fans, d’artistes, de concerts, de packages, de parrainages, revenus totaux, artistes validés, compte à rebours du 1er paiement.',
    inputSchema: { type: 'object', properties: {} },
    run: () => apiAdmin('GET', '/stats'),
  },
  {
    name: 'get_geo',
    description: 'Répartition géographique des utilisateurs : classement des pays (code, nom, drapeau, nombre) et points pour une carte. Indique aussi combien d’utilisateurs sont localisés et si la capture IP est active.',
    inputSchema: { type: 'object', properties: {} },
    run: () => apiAdmin('GET', '/geo'),
  },
  {
    name: 'list_users',
    description: 'Liste les utilisateurs. Filtre par type et recherche texte.',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['all', 'user', 'artist'], description: 'all (défaut), user (fans), artist' },
        search: { type: 'string', description: 'Recherche (nom, e-mail, ville…)' },
      },
    },
    run: (a) => apiAdmin('GET', '/users' + qs({ type: a.type || 'all', search: a.search })),
  },
  {
    name: 'list_artists',
    description: 'Liste des artistes de la plateforme (nom de scène, genre, statut).',
    inputSchema: { type: 'object', properties: {} },
    run: () => apiAdmin('GET', '/artists-list'),
  },
  {
    name: 'list_events',
    description: 'Liste des concerts / événements (titre, artiste, date, statut).',
    inputSchema: { type: 'object', properties: {} },
    run: () => apiAdmin('GET', '/events'),
  },
  {
    name: 'list_meetings',
    description: 'Liste des réunions internes VIBE (titre, type, date, statut).',
    inputSchema: { type: 'object', properties: {} },
    run: () => apiAdmin('GET', '/vibe/meetings'),
  },
  {
    name: 'get_meeting',
    description: 'Détail d’une réunion VIBE (notes, actions décidées) par son id.',
    inputSchema: {
      type: 'object',
      properties: { id: { type: 'number', description: 'Identifiant de la réunion' } },
      required: ['id'],
    },
    run: (a) => apiAdmin('GET', '/vibe/meetings/' + a.id),
  },
  {
    name: 'meeting_assist',
    description: 'Assistant IA de réunion : prépare des arguments clés (mode "points"), rédige une réponse à ce qu’on vient de dire (mode "reply" + input), ou répond à une question libre (mode "ask" + input). Utilise le contexte de la réunion et le pipeline CRM.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'number', description: 'Identifiant de la réunion' },
        mode: { type: 'string', enum: ['points', 'reply', 'ask'], description: 'points | reply | ask' },
        input: { type: 'string', description: 'Ce qu’on vient de te dire (reply) ou ta question (ask)' },
      },
      required: ['id', 'mode'],
    },
    run: (a) => apiAdmin('POST', '/vibe/meetings/' + a.id + '/assist', { mode: a.mode, input: a.input || '' }),
  },
];

const TOOL_MAP = Object.fromEntries(TOOLS.map((t) => [t.name, t]));

// ─── Serveur MCP ───
const server = new Server(
  { name: 'vybzzz', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const tool = TOOL_MAP[req.params.name];
  if (!tool) return { isError: true, content: [{ type: 'text', text: 'Outil inconnu : ' + req.params.name }] };
  try {
    const data = await tool.run(req.params.arguments || {});
    return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
  } catch (e) {
    return { isError: true, content: [{ type: 'text', text: 'Erreur : ' + (e && e.message ? e.message : String(e)) }] };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
// stderr uniquement (stdout est réservé au protocole MCP).
console.error('[vybzzz-mcp] prêt — API:', API_BASE, '| outils:', TOOLS.length);

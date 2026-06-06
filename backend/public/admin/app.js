'use strict';
// ════════════════════════════════════════════════════════════════════
// VYBZZZ — Admin dashboard (SPA vanilla JS). Thème bleu nuit + or.
// ════════════════════════════════════════════════════════════════════

const API = '/api/admin';
let token = localStorage.getItem('vybzzz_admin_token') || '';
let admin = JSON.parse(localStorage.getItem('vybzzz_admin') || 'null');
let currentRows = [];          // dernières lignes chargées (pour les éditions)
const EDIT = {};               // registre des handlers d'édition par type

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function toast(msg) {
  const t = document.createElement('div');
  t.className = 'toast'; t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2600);
}

async function api(method, path, body) {
  const opt = { method, headers: {} };
  if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
  if (token) opt.headers['Authorization'] = 'Bearer ' + token;
  const r = await fetch(API + path, opt);
  const j = await r.json().catch(() => ({}));
  if (r.status === 401) { logout(); throw new Error('unauth'); }
  if (!r.ok) throw new Error(j.message || 'Erreur serveur');
  return j;
}

// ─── Auth ───
async function login() {
  $('login-error').textContent = '';
  const email = $('login-email').value.trim();
  const password = $('login-password').value;
  try {
    const r = await fetch(API + '/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const j = await r.json();
    if (!r.ok) throw new Error(j.message || 'Échec de connexion');
    token = j.token; admin = j.admin;
    localStorage.setItem('vybzzz_admin_token', token);
    localStorage.setItem('vybzzz_admin', JSON.stringify(admin));
    boot();
  } catch (e) { $('login-error').textContent = e.message; }
}
function logout() {
  token = ''; admin = null;
  localStorage.removeItem('vybzzz_admin_token');
  localStorage.removeItem('vybzzz_admin');
  $('app').classList.add('hidden');
  $('login').classList.remove('hidden');
}

// ─── Navigation ───
const NAV = [
  { group: 'Overview', items: [{ id: 'dashboard', label: 'Dashboard', ic: '🏠' }] },
  { group: 'Management', items: [
    { id: 'users', label: 'Users', ic: '👥' },
    { id: 'genres', label: 'Genres', ic: '🎵' },
    { id: 'user-genres', label: 'User Genre', ic: '🏷️' },
    { id: 'events', label: 'Events', ic: '📅' },
    { id: 'packages', label: 'Packages', ic: '📦' },
    { id: 'subscriptions', label: 'Subscription', ic: '💳' },
    { id: 'abusive', label: 'Abusive', ic: '🚫' },
    { id: 'reviews', label: 'Reviews', ic: '⭐' },
  ] },
  { group: 'Finance', items: [
    { id: 'withdrawals', label: 'Withdrawals', ic: '🏦' },
    { id: 'transactions', label: 'Transactions', ic: '💸' },
    { id: 'reports', label: 'Reports', ic: '📈' },
  ] },
  { group: 'Support & Content', items: [
    { id: 'leads', label: 'Contact Leads', ic: '📞' },
    { id: 'faqs', label: 'FAQS', ic: '❓' },
    { id: 'cms', label: 'CMS', ic: '📄' },
  ] },
  { group: 'Account', items: [{ id: 'profile', label: 'Profile', ic: '👤' }] },
];

function renderNav() {
  $('nav').innerHTML = NAV.map((g) =>
    `<div class="group">${g.group}</div>` +
    g.items.map((i) => `<a href="#${i.id}" data-id="${i.id}"><span class="ic">${i.ic}</span><span class="lbl">${i.label}</span></a>`).join('')
  ).join('');
}

function setActive(id) {
  document.querySelectorAll('#nav a').forEach((a) => a.classList.toggle('active', a.dataset.id === id));
}

function boot() {
  $('login').classList.add('hidden');
  $('app').classList.remove('hidden');
  $('admin-name').textContent = admin?.full_name || admin?.email || 'Admin';
  renderNav();
  route();
}

function route() {
  const id = (location.hash.replace('#', '') || 'dashboard');
  setActive(id);
  const fn = ROUTES[id] || ROUTES.dashboard;
  fn();
}

// ════════════════════════════════════════════════════════════════════
// Helpers d'affichage
// ════════════════════════════════════════════════════════════════════
function initials(name, email) {
  const s = (name || email || '?').trim();
  return s.slice(0, 2).toUpperCase();
}
function avatar(row) {
  if (row.profile_image && /^https?:/.test(row.profile_image)) return `<div class="av"><img src="${esc(row.profile_image)}"></div>`;
  return `<div class="av">${esc(initials(row.full_name, row.email))}</div>`;
}
function badge(status) {
  const s = (status || '').toLowerCase();
  return `<span class="badge ${esc(s)}">${esc(status || '—')}</span>`;
}
function fmtDate(d) {
  if (!d) return '—';
  const dt = new Date(d.replace(' ', 'T'));
  if (isNaN(dt)) return d;
  return dt.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

/**
 * Monte une table avec recherche + pagination côté client.
 * cfg = { columns:[{label, render(row)}], rows, perPage }
 */
function mountTable(host, cfg) {
  const perPage = cfg.perPage || 10;
  let page = 1, search = '';
  const filtered = () => {
    if (!search) return cfg.rows;
    const q = search.toLowerCase();
    return cfg.rows.filter((r) => JSON.stringify(r).toLowerCase().includes(q));
  };
  function render() {
    const rows = filtered();
    const pages = Math.max(1, Math.ceil(rows.length / perPage));
    if (page > pages) page = pages;
    const slice = rows.slice((page - 1) * perPage, page * perPage);
    host.querySelector('tbody').innerHTML = slice.length
      ? slice.map((r) => '<tr>' + cfg.columns.map((c) => `<td>${c.render(r)}</td>`).join('') + '</tr>').join('')
      : `<tr><td colspan="${cfg.columns.length}"><div class="empty">Aucune donnée</div></td></tr>`;
    host.querySelector('.tcard-bottom .info').textContent =
      `Affichage de ${rows.length ? (page - 1) * perPage + 1 : 0} à ${Math.min(page * perPage, rows.length)} sur ${rows.length}`;
    const pager = host.querySelector('.pager');
    let html = `<button ${page === 1 ? 'disabled' : ''} data-p="prev">Préc.</button>`;
    for (let i = 1; i <= pages; i++) html += `<button class="${i === page ? 'active' : ''}" data-p="${i}">${i}</button>`;
    html += `<button ${page === pages ? 'disabled' : ''} data-p="next">Suiv.</button>`;
    pager.innerHTML = html;
    pager.querySelectorAll('button').forEach((b) => b.onclick = () => {
      if (b.dataset.p === 'prev') page--; else if (b.dataset.p === 'next') page++; else page = +b.dataset.p;
      render();
    });
  }
  host.querySelector('.search input').oninput = (e) => { search = e.target.value; page = 1; render(); };
  render();
}

/** Coquille de page-table (header + carte + thead + tbody + footer). */
function tableShell(title, columns, headRight = '') {
  return `
    <div class="head-row"><h1 class="page-title">${esc(title)}</h1>${headRight}</div>
    <div class="tcard">
      <div class="tcard-top">
        <div class="left">Show 10 entries</div>
        <div class="search"><input placeholder="Search…"></div>
      </div>
      <div style="overflow-x:auto"><table>
        <thead><tr>${columns.map((c) => `<th>${esc(c.label)}</th>`).join('')}</tr></thead>
        <tbody></tbody>
      </table></div>
      <div class="tcard-bottom"><span class="info"></span><div class="pager"></div></div>
    </div>`;
}

// ─── Modale générique ───
function modal({ title, fields, onSave }) {
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  bg.innerHTML = `<div class="modal"><h3>${esc(title)}</h3>${fields.map((f) =>
    `<label>${esc(f.label)}</label>` + (f.type === 'textarea'
      ? `<textarea data-k="${f.name}">${esc(f.value || '')}</textarea>`
      : f.type === 'checkbox'
        ? `<label style="display:flex;gap:8px;align-items:center"><input type="checkbox" data-k="${f.name}" style="width:auto" ${f.value ? 'checked' : ''}> ${esc(f.hint || '')}</label>`
        : `<input type="${f.type || 'text'}" data-k="${f.name}" value="${esc(f.value || '')}">`)
  ).join('')}
    <div class="modal-actions"><button class="cancel">Annuler</button><button class="btn gold save">Enregistrer</button></div></div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  bg.querySelector('.save').onclick = async () => {
    const data = {};
    bg.querySelectorAll('[data-k]').forEach((el) => {
      data[el.dataset.k] = el.type === 'checkbox' ? el.checked : el.value;
    });
    try { await onSave(data); bg.remove(); } catch (e) { toast(e.message); }
  };
}

async function confirmDelete(fn) {
  if (!confirm('Confirmer la suppression ?')) return;
  try { await fn(); } catch (e) { toast(e.message); }
}

// ════════════════════════════════════════════════════════════════════
// PAGES
// ════════════════════════════════════════════════════════════════════
const view = () => $('view');

// Dashboard
async function pageDashboard() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/stats');
  const today = new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  const cards = [
    { ic: '👥', bg: 'rgba(216,180,90,.15)', col: '#d8b45a', n: data.total_users, l: 'Total Users', bar: '70%', barc: '#d8b45a' },
    { ic: '📅', bg: 'rgba(31,157,87,.15)', col: '#4ade80', n: data.total_events, l: 'Total Events', bar: '55%', barc: '#1f9d57' },
    { ic: '📦', bg: 'rgba(224,65,63,.15)', col: '#ff8a87', n: data.total_packages, l: 'Total Packages', bar: '40%', barc: '#e0413f' },
    { ic: '💰', bg: 'rgba(224,167,58,.15)', col: '#e0a73a', n: '$' + Number(data.total_revenue).toLocaleString('en-US'), l: 'Total Revenue', bar: '85%', barc: '#e0a73a' },
  ];
  view().innerHTML = `
    <div class="dash-banner">
      <div><h2>Dashboard Overview</h2><p>Welcome back, Admin • Voici le résumé de la plateforme</p></div>
      <div class="dash-date">📅 ${today}</div>
    </div>
    <div class="cards">${cards.map((c) => `
      <div class="card">
        <div class="row"><div class="ic-box" style="background:${c.bg};color:${c.col}">${c.ic}</div><div class="num">${c.n}</div></div>
        <div class="lbl">${c.l}</div><div class="bar"><i style="width:${c.bar};background:${c.barc}"></i></div>
      </div>`).join('')}</div>`;
}

// Users (avec tabs)
async function pageUsers() {
  let type = 'all';
  async function load() {
    view().querySelector('#utable')?.replaceChildren();
    const { data, counts } = await api('GET', '/users?type=' + (type === 'all' ? '' : type));
    const cols = [
      { label: '#', render: (r) => r.id },
      { label: 'User Info', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
      { label: 'Phone', render: (r) => esc(r.phone_number || '—') },
      { label: 'Address', render: (r) => esc(r.address || 'N/A') },
      { label: 'Status', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn status" data-act="status" data-id="${r.id}" data-s="${r.status}">Update Status</button><button class="btn del" data-act="del" data-id="${r.id}">Delete</button>` },
    ];
    const host = view().querySelector('#utable');
    host.innerHTML = `<div class="tabs">
      <button data-t="all" class="${type === 'all' ? 'active' : ''}">All (${counts.all})</button>
      <button data-t="user" class="${type === 'user' ? 'active' : ''}">User (${counts.user})</button>
      <button data-t="artist" class="${type === 'artist' ? 'active' : ''}">Artists (${counts.artist})</button>
    </div>` + tableShellInner(cols);
    host.querySelectorAll('.tabs button').forEach((b) => b.onclick = () => { type = b.dataset.t; load(); });
    mountTable(host, { columns: cols, rows: data });
    host.querySelectorAll('[data-act]').forEach((b) => b.onclick = async () => {
      const id = b.dataset.id;
      if (b.dataset.act === 'del') return confirmDelete(async () => { await api('DELETE', '/users/' + id); toast('Supprimé'); load(); });
      const next = b.dataset.s === 'active' ? 'pending' : 'active';
      await api('POST', `/users/${id}/status`, { status: next }); toast('Statut → ' + next); load();
    });
  }
  view().innerHTML = `<div class="head-row"><h1 class="page-title">Users</h1><button class="add-btn" id="adduser">+ Add</button></div><div id="utable"></div>`;
  view().querySelector('#adduser').onclick = () => modal({
    title: 'Ajouter un utilisateur',
    fields: [{ name: 'full_name', label: 'Nom complet' }, { name: 'email', label: 'Email', type: 'email' }, { name: 'password', label: 'Mot de passe', type: 'password' }, { name: 'is_artist', label: 'Artiste ?', type: 'checkbox', hint: 'Compte artiste' }],
    onSave: async (d) => { await api('POST', '/users', d); toast('Utilisateur créé'); load(); },
  });
  load();
}

// tableShell sans le head-row (réutilisé dans pages à tabs)
function tableShellInner(columns) {
  return `<div class="tcard">
    <div class="tcard-top"><div class="left">Show 10 entries</div><div class="search"><input placeholder="Search…"></div></div>
    <div style="overflow-x:auto"><table><thead><tr>${columns.map((c) => `<th>${esc(c.label)}</th>`).join('')}</tr></thead><tbody></tbody></table></div>
    <div class="tcard-bottom"><span class="info"></span><div class="pager"></div></div>
  </div>`;
}

// Générique : page liste simple
async function listPage({ title, endpoint, columns, addLabel, onAdd }) {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', endpoint);
  currentRows = data;
  const headRight = addLabel ? `<button class="add-btn" id="addbtn">${esc(addLabel)}</button>` : '';
  view().innerHTML = tableShell(title, columns, headRight);
  mountTable(view().querySelector('.tcard'), { columns, rows: data });
  if (addLabel) view().querySelector('#addbtn').onclick = () => onAdd(() => route());
}

// Genres (CRUD)
function pageGenres() {
  EDIT.genre = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier le genre', fields: [{ name: 'name', label: 'Nom', value: r.name }], onSave: async (d) => { await api('PUT', '/genres/' + id, d); toast('Modifié'); route(); } });
  };
  listPage({
    title: 'Genres', endpoint: '/genres', addLabel: '+ Add',
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Genre', render: (r) => esc(r.name) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="genre:${r.id}">Edit</button><button class="btn del" data-del="/genres/${r.id}">Delete</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un genre', fields: [{ name: 'name', label: 'Nom du genre' }], onSave: async (d) => { await api('POST', '/genres', d); toast('Ajouté'); reload(); } }),
  });
}

// User Genres
function pageUserGenres() {
  listPage({
    title: 'User Genres', endpoint: '/user-genres', columns: [
      { label: '#', render: (r) => r.user_id },
      { label: 'User Info', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
      { label: 'Genre', render: (r) => esc(r.genre) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
    ],
  });
}

// Events
function pageEvents() {
  listPage({
    title: 'Events', endpoint: '/events', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Event', render: (r) => `<div class="nm">${esc(r.name)}</div>` },
      { label: 'Artist', render: (r) => esc(r.artist || '—') },
      { label: 'Price', render: (r) => '$' + esc(r.ticket_price || '0') },
      { label: 'Status', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.start_date_time) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/events/${r.id}">Delete</button>` },
    ],
  });
}

// Packages
function pagePackages() {
  listPage({
    title: 'Packages', endpoint: '/packages', addLabel: '+ Add', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Name', render: (r) => esc(r.name) },
      { label: 'Points', render: (r) => esc(r.points) },
      { label: 'Price', render: (r) => '$' + esc(r.price) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/packages/${r.id}">Delete</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un package', fields: [{ name: 'name', label: 'Nom' }, { name: 'points', label: 'Points' }, { name: 'price', label: 'Prix' }], onSave: async (d) => { await api('POST', '/packages', d); toast('Ajouté'); reload(); } }),
  });
}

// Subscriptions
function pageSubscriptions() {
  listPage({
    title: 'Subscriptions', endpoint: '/subscriptions', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Name', render: (r) => esc(r.name) },
      { label: 'Tier', render: (r) => esc(r.tier) },
      { label: 'Price', render: (r) => '$' + esc(r.price) },
      { label: 'Period', render: (r) => esc(r.period) },
      { label: 'Active', render: (r) => badge(r.active ? 'active' : 'pending') },
    ],
  });
}

// Abusive (CRUD)
function pageAbusive() {
  listPage({
    title: 'Abusive Words', endpoint: '/abusive', addLabel: '+ Add', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Word', render: (r) => esc(r.word) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/abusive/${r.id}">Delete</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un mot', fields: [{ name: 'word', label: 'Mot interdit' }], onSave: async (d) => { await api('POST', '/abusive', d); toast('Ajouté'); reload(); } }),
  });
}

// Reviews
function pageReviews() {
  listPage({
    title: 'Reviews', endpoint: '/reviews', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'User', render: (r) => esc(r.user || r.email || '—') },
      { label: 'Event', render: (r) => esc(r.event || '—') },
      { label: 'Rating', render: (r) => '⭐'.repeat(r.rating || 0) },
      { label: 'Comment', render: (r) => esc(r.comment || '') },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/reviews/${r.id}">Delete</button>` },
    ],
  });
}

// Withdrawals
async function pageWithdrawals() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/withdrawals');
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'User', render: (r) => esc(r.artist_name || r.user || r.email || '—') },
    { label: 'Amount', render: (r) => '$' + esc(r.amount) },
    { label: 'Bank', render: (r) => esc(r.bank || '—') },
    { label: 'Status', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `<button class="btn status" data-wd="${r.id}" data-s="approved">Approve</button><button class="btn del" data-wd="${r.id}" data-s="rejected" data-rej="1">Reject</button>` },
  ];
  view().innerHTML = tableShell('Withdrawals', cols);
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
  view().querySelectorAll('[data-wd]').forEach((b) => b.onclick = async () => {
    await api('POST', `/withdrawals/${b.dataset.wd}/status`, { status: b.dataset.s });
    toast('Statut → ' + b.dataset.s); pageWithdrawals();
  });
}

// Transactions
function pageTransactions() {
  listPage({
    title: 'Transactions', endpoint: '/transactions', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Receipt', render: (r) => esc(r.receipt_number) },
      { label: 'User', render: (r) => esc(r.user || r.email || '—') },
      { label: 'Event', render: (r) => esc(r.event || '—') },
      { label: 'Amount', render: (r) => '$' + esc(r.price_paid || '0') },
      { label: 'Status', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
    ],
  });
}

// Reports
async function pageReports() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/reports');
  view().innerHTML = `
    <h1 class="page-title">Reports</h1>
    <div class="cards" style="margin-bottom:18px">
      <div class="card"><div class="row"><div class="ic-box" style="background:rgba(224,167,58,.15);color:#e0a73a">💰</div><div class="num">$${Number(data.revenue).toLocaleString('en-US')}</div></div><div class="lbl">Revenue total</div></div>
      <div class="card"><div class="row"><div class="ic-box" style="background:rgba(59,130,246,.15);color:#7eb0ff">🎟️</div><div class="num">${data.tickets_sold}</div></div><div class="lbl">Billets vendus</div></div>
    </div>
    <div class="report-grid">
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">Top concerts (ventes)</h3>${(data.top_events || []).map((e) => `<div class="kv"><span>${esc(e.name)}</span><span>${e.sales}</span></div>`).join('') || '<div class="empty">—</div>'}</div>
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">Events par genre</h3>${(data.by_genre || []).map((g) => `<div class="kv"><span>${esc(g.name)}</span><span>${g.events}</span></div>`).join('') || '<div class="empty">—</div>'}</div>
    </div>`;
}

// Contact Leads
function pageLeads() {
  listPage({
    title: 'Contact Leads', endpoint: '/contact-leads', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Name', render: (r) => esc(r.name) },
      { label: 'Email', render: (r) => esc(r.email) },
      { label: 'Phone', render: (r) => esc(r.phone || '—') },
      { label: 'Message', render: (r) => esc(r.message || '') },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/contact-leads/${r.id}">Delete</button>` },
    ],
  });
}

// FAQ (CRUD)
function pageFaqs() {
  EDIT.faq = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier la FAQ', fields: [{ name: 'question', label: 'Question', value: r.question }, { name: 'answer', label: 'Réponse', type: 'textarea', value: r.answer }], onSave: async (d) => { await api('PUT', '/faqs/' + id, d); toast('Modifiée'); route(); } });
  };
  listPage({
    title: 'FAQS', endpoint: '/faqs', addLabel: '+ Add',
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Question', render: (r) => esc(r.question) },
      { label: 'Réponse', render: (r) => esc(r.answer) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="faq:${r.id}">Edit</button><button class="btn del" data-del="/faqs/${r.id}">Delete</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter une FAQ', fields: [{ name: 'question', label: 'Question' }, { name: 'answer', label: 'Réponse', type: 'textarea' }], onSave: async (d) => { await api('POST', '/faqs', d); toast('Ajoutée'); reload(); } }),
  });
}

// CMS
async function pageCms() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/cms');
  view().innerHTML = `<h1 class="page-title">CMS</h1><div class="cms-grid">${data.map((p) => `
    <div class="tcard">
      <h3 style="color:var(--gold);margin-bottom:8px">${esc(p.title || p.slug)}</h3>
      <label style="color:var(--muted);font-size:13px">Titre</label>
      <input data-slug="${esc(p.slug)}" data-f="title" value="${esc(p.title || '')}" style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:10px;margin:6px 0 10px">
      <label style="color:var(--muted);font-size:13px">Contenu</label>
      <textarea data-slug="${esc(p.slug)}" data-f="content" style="width:100%;min-height:120px;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:10px;margin-top:6px">${esc(p.content || '')}</textarea>
      <div style="text-align:right;margin-top:10px"><button class="btn gold" data-save="${esc(p.slug)}">Enregistrer</button></div>
    </div>`).join('')}</div>`;
  view().querySelectorAll('[data-save]').forEach((b) => b.onclick = async () => {
    const slug = b.dataset.save;
    const title = view().querySelector(`[data-slug="${slug}"][data-f="title"]`).value;
    const content = view().querySelector(`[data-slug="${slug}"][data-f="content"]`).value;
    await api('PUT', '/cms/' + slug, { title, content }); toast('Page enregistrée');
  });
}

// Profile
async function pageProfile() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/profile');
  view().innerHTML = `<h1 class="page-title">Profile</h1>
    <div class="tcard" style="max-width:520px">
      <label style="color:var(--muted);font-size:13px">Nom</label>
      <input id="pf-name" value="${esc(data.full_name || '')}" style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:11px;margin:6px 0 14px">
      <label style="color:var(--muted);font-size:13px">Email</label>
      <input value="${esc(data.email)}" disabled style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--muted);border-radius:8px;padding:11px;margin:6px 0 14px">
      <label style="color:var(--muted);font-size:13px">Nouveau mot de passe</label>
      <input id="pf-pass" type="password" placeholder="••••••" style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:11px;margin:6px 0 18px">
      <button class="btn gold" id="pf-save">Enregistrer</button>
    </div>`;
  view().querySelector('#pf-save').onclick = async () => {
    const body = { full_name: view().querySelector('#pf-name').value };
    const pass = view().querySelector('#pf-pass').value;
    if (pass) body.password = pass;
    await api('POST', '/profile', body); toast('Profil mis à jour');
  };
}

// Délégation globale unique : boutons Delete (data-del) et Edit (data-edit="type:id")
document.addEventListener('click', (e) => {
  const del = e.target.closest('[data-del]');
  if (del) { confirmDelete(async () => { await api('DELETE', del.dataset.del); toast('Supprimé'); route(); }); return; }
  const ed = e.target.closest('[data-edit]');
  if (ed) { const [type, id] = ed.dataset.edit.split(':'); EDIT[type]?.(id); }
});

const ROUTES = {
  dashboard: pageDashboard, users: pageUsers, genres: pageGenres, 'user-genres': pageUserGenres,
  events: pageEvents, packages: pagePackages, subscriptions: pageSubscriptions, abusive: pageAbusive,
  reviews: pageReviews, withdrawals: pageWithdrawals, transactions: pageTransactions, reports: pageReports,
  leads: pageLeads, faqs: pageFaqs, cms: pageCms, profile: pageProfile,
};

// ─── Init ───
window.addEventListener('hashchange', route);
$('login-btn').onclick = login;
$('login-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') login(); });
$('logout-btn').onclick = logout;
if (token && admin) boot(); else { $('login').classList.remove('hidden'); }

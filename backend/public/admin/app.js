'use strict';
// ════════════════════════════════════════════════════════════════════
// VYBZZZ — Dashboard admin (SPA vanilla JS). Thème bleu nuit + or. FR.
// ════════════════════════════════════════════════════════════════════

const API = '/api/admin';
let token = localStorage.getItem('vybzzz_admin_token') || '';
let admin = JSON.parse(localStorage.getItem('vybzzz_admin') || 'null');
let currentRows = [];
const EDIT = {};

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
  if (body instanceof FormData) { opt.body = body; }
  else if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
  if (token) opt.headers['Authorization'] = 'Bearer ' + token;
  const r = await fetch(API + path, opt);
  const j = await r.json().catch(() => ({}));
  if (r.status === 401) { logout(); throw new Error('Session expirée'); }
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

// ─── Navigation (FR) ───
const NAV = [
  { group: 'Vue d\'ensemble', items: [{ id: 'dashboard', label: 'Tableau de bord', ic: '🏠' }] },
  { group: 'Gestion', items: [
    { id: 'users', label: 'Utilisateurs', ic: '👥' },
    { id: 'genres', label: 'Genres', ic: '🎵' },
    { id: 'user-genres', label: 'Genres par user', ic: '🏷️' },
    { id: 'events', label: 'Concerts', ic: '📅' },
    { id: 'packages', label: 'Packages', ic: '📦' },
    { id: 'subscriptions', label: 'Abonnements', ic: '💳' },
    { id: 'referrals', label: 'Parrainages', ic: '🤝' },
    { id: 'abusive', label: 'Mots interdits', ic: '🚫' },
    { id: 'reviews', label: 'Avis', ic: '⭐' },
  ] },
  { group: 'Finance', items: [
    { id: 'withdrawals', label: 'Retraits', ic: '🏦' },
    { id: 'transactions', label: 'Transactions', ic: '💸' },
    { id: 'reports', label: 'Rapports', ic: '📈' },
  ] },
  { group: 'Support & contenu', items: [
    { id: 'ideas', label: 'Boîte à idées', ic: '💡' },
    { id: 'leads', label: 'Contacts / Leads', ic: '📞' },
    { id: 'faqs', label: 'FAQ', ic: '❓' },
    { id: 'cms', label: 'CMS', ic: '📄' },
  ] },
  { group: 'Compte', items: [{ id: 'profile', label: 'Profil', ic: '👤' }] },
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
  (ROUTES[id] || ROUTES.dashboard)();
}

// ─── Helpers d'affichage ───
function initials(name, email) { return (name || email || '?').trim().slice(0, 2).toUpperCase(); }
function avatar(row) {
  if (row.profile_image && /^https?:/.test(row.profile_image)) return `<div class="av"><img src="${esc(row.profile_image)}"></div>`;
  return `<div class="av">${esc(initials(row.full_name, row.email))}</div>`;
}
const STATUS_FR = { active: 'Actif', pending: 'En attente', live: 'En direct', published: 'Publié', completed: 'Terminé', cancelled: 'Annulé', approved: 'Approuvé', rejected: 'Refusé', validated: 'Validé', new: 'Nouveau', reviewed: 'Vu', implemented: 'Implémenté' };
function badge(status) {
  const s = (status || '').toLowerCase();
  return `<span class="badge ${esc(s)}">${esc(STATUS_FR[s] || status || '—')}</span>`;
}
function fmtDate(d) {
  if (!d) return '—';
  const dt = new Date(String(d).replace(' ', 'T'));
  return isNaN(dt) ? d : dt.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

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

function tableShell(title, columns, headRight = '') {
  return `
    <div class="head-row"><h1 class="page-title">${esc(title)}</h1>${headRight}</div>
    <div class="tcard">
      <div class="tcard-top">
        <div class="left">Afficher 10 entrées</div>
        <div class="search"><input placeholder="Rechercher…"></div>
      </div>
      <div style="overflow-x:auto"><table>
        <thead><tr>${columns.map((c) => `<th>${esc(c.label)}</th>`).join('')}</tr></thead>
        <tbody></tbody>
      </table></div>
      <div class="tcard-bottom"><span class="info"></span><div class="pager"></div></div>
    </div>`;
}
function tableShellInner(columns) {
  return `<div class="tcard">
    <div class="tcard-top"><div class="left">Afficher 10 entrées</div><div class="search"><input placeholder="Rechercher…"></div></div>
    <div style="overflow-x:auto"><table><thead><tr>${columns.map((c) => `<th>${esc(c.label)}</th>`).join('')}</tr></thead><tbody></tbody></table></div>
    <div class="tcard-bottom"><span class="info"></span><div class="pager"></div></div>
  </div>`;
}

// ─── Modale (supporte text / textarea / checkbox / select / date / number) ───
function modal({ title, fields, onSave, wide }) {
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  const fieldHtml = (f) => {
    if (f.type === 'textarea') return `<textarea data-k="${f.name}">${esc(f.value || '')}</textarea>`;
    if (f.type === 'checkbox') return `<label style="display:flex;gap:8px;align-items:center"><input type="checkbox" data-k="${f.name}" style="width:auto" ${f.value ? 'checked' : ''}> ${esc(f.hint || '')}</label>`;
    if (f.type === 'select') return `<select data-k="${f.name}">${(f.options || []).map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(f.value) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
    if (f.type === 'file') return `<input type="file" data-k="${f.name}" accept="${esc(f.accept || 'image/*')}">`;
    return `<input type="${f.type || 'text'}" data-k="${f.name}" value="${esc(f.value ?? '')}" placeholder="${esc(f.placeholder || '')}">`;
  };
  bg.innerHTML = `<div class="modal" ${wide ? 'style="width:560px"' : ''}><h3>${esc(title)}</h3>${fields.map((f) => `<label>${esc(f.label)}</label>${fieldHtml(f)}`).join('')}
    <div class="modal-actions"><button class="cancel">Annuler</button><button class="btn gold save">Enregistrer</button></div></div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  bg.querySelector('.save').onclick = async () => {
    const els = [...bg.querySelectorAll('[data-k]')];
    const hasFile = els.some((el) => el.type === 'file' && el.files && el.files.length);
    let data;
    if (hasFile) {
      data = new FormData();
      els.forEach((el) => {
        if (el.type === 'file') { if (el.files && el.files[0]) data.append(el.dataset.k, el.files[0]); }
        else if (el.type === 'checkbox') data.append(el.dataset.k, el.checked ? '1' : '0');
        else data.append(el.dataset.k, el.value);
      });
    } else {
      data = {};
      els.forEach((el) => { data[el.dataset.k] = el.type === 'checkbox' ? el.checked : el.value; });
    }
    try { await onSave(data); bg.remove(); } catch (e) { toast(e.message); }
  };
}

async function confirmDelete(fn) {
  if (!confirm('Confirmer la suppression ?')) return;
  try { await fn(); } catch (e) { toast(e.message); }
}

const view = () => $('view');

// ════════════════════════════════════════════════════════════════════
// PAGES
// ════════════════════════════════════════════════════════════════════
// ─── Graphiques SVG (sans dépendance) ───
function svgLine(values, labels, color = '#d8b45a') {
  const w = 560, h = 190, pad = 34, n = values.length, max = Math.max(1, ...values);
  const x = (i) => pad + (i * (w - 2 * pad)) / Math.max(1, n - 1);
  const y = (v) => h - pad - (v / max) * (h - 2 * pad);
  const pts = values.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const grid = [0, 0.5, 1].map((f) => { const yy = h - pad - f * (h - 2 * pad); return `<line x1="${pad}" y1="${yy}" x2="${w - pad}" y2="${yy}" stroke="#1b2a3d" stroke-width="1"/>`; }).join('');
  const dots = values.map((v, i) => `<circle cx="${x(i)}" cy="${y(v)}" r="3.5" fill="${color}"/>`).join('');
  const lbls = labels.map((l, i) => `<text x="${x(i)}" y="${h - 8}" fill="#aeb7c2" font-size="11" text-anchor="middle">${esc(l)}</text>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" preserveAspectRatio="xMidYMid meet">${grid}
    <polyline points="${pad},${h - pad} ${pts} ${x(n - 1)},${h - pad}" fill="${color}22"/>
    <polyline points="${pts}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"/>${dots}${lbls}</svg>`;
}
function svgBars(values, labels, color = '#3b82f6') {
  const w = 560, h = 190, pad = 34, n = values.length, max = Math.max(1, ...values), step = (w - 2 * pad) / n, bw = step * 0.55;
  const bars = values.map((v, i) => {
    const bx = pad + i * step + (step - bw) / 2, bh = (v / max) * (h - 2 * pad), by = h - pad - bh;
    return `<rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="4" fill="${color}"/><text x="${bx + bw / 2}" y="${by - 5}" fill="#aeb7c2" font-size="10" text-anchor="middle">${v}</text>`;
  }).join('');
  const lbls = labels.map((l, i) => `<text x="${pad + i * step + step / 2}" y="${h - 8}" fill="#aeb7c2" font-size="11" text-anchor="middle">${esc(l)}</text>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" preserveAspectRatio="xMidYMid meet">${bars}${lbls}</svg>`;
}
function goalBar(label, current, target, color, fmt = (x) => x) {
  const pct = Math.min(100, Math.round((current / Math.max(1, target)) * 100));
  return `<div style="margin-bottom:16px">
    <div style="display:flex;justify-content:space-between;margin-bottom:6px;font-size:14px"><span>${esc(label)}</span>
      <span style="color:${color};font-weight:700">${fmt(current)} / ${fmt(target)} <span style="color:var(--muted)">(${pct}%)</span></span></div>
    <div class="bar" style="height:10px"><i style="width:${pct}%;background:${color}"></i></div></div>`;
}

async function pageDashboard() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const [{ data: s }, { data: ch }] = await Promise.all([api('GET', '/stats'), api('GET', '/chart-data')]);
  const today = new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  const euro = (x) => '$' + Number(x).toLocaleString('fr-FR');
  const cards = [
    { ic: '👥', bg: 'rgba(59,130,246,.15)', col: '#7eb0ff', n: s.total_users, l: 'Utilisateurs', bar: '70%', barc: '#3b82f6' },
    { ic: '🎤', bg: 'rgba(216,180,90,.15)', col: '#d8b45a', n: s.total_artists, l: 'Artistes', bar: '60%', barc: '#d8b45a' },
    { ic: '📅', bg: 'rgba(31,157,87,.15)', col: '#4ade80', n: s.total_events, l: 'Concerts', bar: '55%', barc: '#1f9d57' },
    { ic: '🤝', bg: 'rgba(168,85,247,.15)', col: '#c084fc', n: s.total_referrals, l: 'Parrainages', bar: '45%', barc: '#a855f7' },
    { ic: '💰', bg: 'rgba(224,167,58,.15)', col: '#e0a73a', n: euro(s.total_revenue), l: 'Revenus', bar: '85%', barc: '#e0a73a' },
  ];
  view().innerHTML = `
    <div class="dash-banner">
      <div><h2>Tableau de bord</h2><p>Bienvenue, Admin • Voici le résumé de la plateforme</p></div>
      <div class="dash-date">📅 ${today}</div>
    </div>
    <div class="cards">${cards.map((c) => `
      <div class="card"><div class="row"><div class="ic-box" style="background:${c.bg};color:${c.col}">${c.ic}</div><div class="num">${c.n}</div></div>
        <div class="lbl">${c.l}</div><div class="bar"><i style="width:${c.bar};background:${c.barc}"></i></div></div>`).join('')}</div>
    <div class="report-grid" style="margin-top:22px">
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">📈 Revenus (6 derniers mois)</h3>${svgLine(ch.revenue, ch.labels, '#d8b45a')}</div>
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">🎟️ Billets vendus / mois</h3>${svgBars(ch.tickets, ch.labels, '#3b82f6')}</div>
    </div>
    <div class="tcard" style="margin-top:18px">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
        <h3 style="color:var(--gold)">🎯 Objectifs à atteindre</h3>
        <button class="btn gold" id="editGoals">Modifier les objectifs</button>
      </div>
      ${goalBar("Chiffre d'affaires", ch.goals.revenue.current, ch.goals.revenue.target, '#e0a73a', euro)}
      ${goalBar('Utilisateurs', ch.goals.users.current, ch.goals.users.target, '#3b82f6')}
      ${goalBar('Artistes', ch.goals.artists.current, ch.goals.artists.target, '#d8b45a')}
    </div>`;
  view().querySelector('#editGoals').onclick = () => modal({
    title: 'Modifier les objectifs', fields: [
      { name: 'goal_revenue', label: "Objectif chiffre d'affaires ($)", type: 'number', value: ch.goals.revenue.target },
      { name: 'goal_users', label: 'Objectif utilisateurs', type: 'number', value: ch.goals.users.target },
      { name: 'goal_artists', label: 'Objectif artistes', type: 'number', value: ch.goals.artists.target },
    ],
    onSave: async (d) => { await api('PUT', '/goals', d); toast('Objectifs enregistrés'); route(); },
  });
}

// Utilisateurs (onglets)
let usersTab = 'all';
function userEditForm(r) {
  modal({
    title: "Modifier l'utilisateur", fields: [
      { name: 'full_name', label: 'Nom complet', value: r.full_name },
      { name: 'photo', label: 'Photo / avatar (fichier)', type: 'file', accept: 'image/*' },
      { name: 'photo', label: 'Ou coller une URL', value: r.profile_image, placeholder: 'https://… (bulle artiste)' },
      { name: 'phone_number', label: 'Téléphone', value: r.phone_number },
      { name: 'address', label: 'Adresse', value: r.address },
      { name: 'is_artist', label: 'Artiste ?', type: 'checkbox', value: !!r.is_artist, hint: 'Compte artiste' },
    ],
    onSave: async (d) => { await api('PUT', '/users/' + r.id, d); toast('Utilisateur modifié'); route(); },
  });
}
async function pageUsers() {
  EDIT.user = (id) => { const r = currentRows.find((x) => x.id == id); if (r) userEditForm(r); };
  const { data, counts } = await api('GET', '/users?type=' + (usersTab === 'all' ? '' : usersTab));
  currentRows = data;
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Utilisateur', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
    { label: 'Téléphone', render: (r) => esc(r.phone_number || '—') },
    { label: 'Adresse', render: (r) => esc(r.address || 'N/A') },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `<button class="btn edit" data-edit="user:${r.id}">Modifier</button><button class="btn status" data-status="${r.id}">Statut</button><button class="btn del" data-del="/users/${r.id}">Supprimer</button>` },
  ];
  view().innerHTML = `<div class="head-row"><h1 class="page-title">Utilisateurs</h1><button class="add-btn" id="adduser">+ Ajouter</button></div>
    <div class="tabs">
      <button data-t="all" class="${usersTab === 'all' ? 'active' : ''}">Tous (${counts.all})</button>
      <button data-t="user" class="${usersTab === 'user' ? 'active' : ''}">Utilisateurs (${counts.user})</button>
      <button data-t="artist" class="${usersTab === 'artist' ? 'active' : ''}">Artistes (${counts.artist})</button>
    </div>${tableShellInner(cols)}`;
  view().querySelectorAll('.tabs button').forEach((b) => b.onclick = () => { usersTab = b.dataset.t; pageUsers(); });
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
  view().querySelector('#adduser').onclick = () => modal({
    title: 'Ajouter un utilisateur',
    fields: [{ name: 'full_name', label: 'Nom complet' }, { name: 'email', label: 'Email', type: 'email' }, { name: 'password', label: 'Mot de passe', type: 'password' }, { name: 'is_artist', label: 'Artiste ?', type: 'checkbox', hint: 'Compte artiste' }],
    onSave: async (d) => { await api('POST', '/users', d); toast('Utilisateur créé'); pageUsers(); },
  });
}

// Liste générique
async function listPage({ title, endpoint, columns, addLabel, onAdd }) {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', endpoint);
  currentRows = data;
  const headRight = addLabel ? `<button class="add-btn" id="addbtn">${esc(addLabel)}</button>` : '';
  view().innerHTML = tableShell(title, columns, headRight);
  mountTable(view().querySelector('.tcard'), { columns, rows: data });
  if (addLabel) view().querySelector('#addbtn').onclick = () => onAdd(() => route());
}

// Genres
function pageGenres() {
  EDIT.genre = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier le genre', fields: [{ name: 'name', label: 'Nom', value: r.name }], onSave: async (d) => { await api('PUT', '/genres/' + id, d); toast('Modifié'); route(); } });
  };
  listPage({
    title: 'Genres', endpoint: '/genres', addLabel: '+ Ajouter',
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Genre', render: (r) => esc(r.name) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="genre:${r.id}">Modifier</button><button class="btn del" data-del="/genres/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un genre', fields: [{ name: 'name', label: 'Nom du genre' }], onSave: async (d) => { await api('POST', '/genres', d); toast('Ajouté'); reload(); } }),
  });
}

function pageUserGenres() {
  async function openAdd(reload) {
    const [{ data: users }, { data: genres }] = await Promise.all([api('GET', '/users-list'), api('GET', '/genres')]);
    modal({
      title: 'Associer un genre à un utilisateur', fields: [
        { name: 'user_id', label: 'Utilisateur', type: 'select', options: [{ value: '', label: '— Choisir —' }, ...users.map((u) => ({ value: u.id, label: u.name }))] },
        { name: 'genre_id', label: 'Genre', type: 'select', options: [{ value: '', label: '— Choisir —' }, ...genres.map((g) => ({ value: g.id, label: g.name }))] },
      ],
      onSave: async (d) => { await api('POST', '/user-genres', d); toast('Association ajoutée'); reload(); },
    });
  }
  listPage({
    title: 'Genres par utilisateur', endpoint: '/user-genres', addLabel: '+ Associer un genre', onAdd: (reload) => openAdd(reload),
    columns: [
      { label: '#', render: (r) => r.user_id },
      { label: 'Utilisateur', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
      { label: 'Genre', render: (r) => esc(r.genre) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/user-genres?user_id=${r.user_id}&genre_id=${r.genre_id}">Supprimer</button>` },
    ],
  });
}

// Concerts (CRUD + Mux)
async function openEventForm(row) {
  const [{ data: artists }, { data: genres }] = await Promise.all([api('GET', '/artists-list'), api('GET', '/genres')]);
  modal({
    title: row ? 'Modifier le concert' : 'Ajouter un concert', wide: true,
    fields: [
      { name: 'name', label: 'Nom du concert', value: row?.name },
      { name: 'artist_id', label: 'Artiste', type: 'select', value: row?.artist_id, options: [{ value: '', label: '— Choisir —' }, ...artists.map((a) => ({ value: a.id, label: a.name }))] },
      { name: 'genre_id', label: 'Genre', type: 'select', value: row?.genre_id, options: [{ value: '', label: '— Choisir —' }, ...genres.map((g) => ({ value: g.id, label: g.name }))] },
      { name: 'status', label: 'Statut', type: 'select', value: row?.status || 'published', options: [{ value: 'published', label: 'Publié' }, { value: 'live', label: 'En direct' }, { value: 'completed', label: 'Terminé' }, { value: 'cancelled', label: 'Annulé' }] },
      { name: 'ticket_price', label: 'Prix du billet ($)', type: 'number', value: row?.ticket_price || '0' },
      { name: 'start_date_time', label: 'Date/heure (AAAA-MM-JJ HH:MM:SS)', value: row?.start_date_time, placeholder: '2026-12-26 19:30:00' },
      { name: 'mux_playback_id', label: 'Vidéo — Mux Playback ID', value: row?.mux_playback_id, placeholder: 'colle l\'ID Mux (ou laisse vide)' },
      { name: 'cover', label: 'Image de couverture (fichier)', type: 'file', accept: 'image/*' },
      { name: 'cover_image', label: 'Ou nom de fichier / URL', value: row?.cover_image },
      { name: 'description', label: 'Description', type: 'textarea', value: row?.description },
      { name: 'is_banner', label: 'Mettre en bannière (carrousel accueil) ?', type: 'checkbox', value: !!row?.is_banner, hint: 'Afficher dans le carrousel' },
    ],
    onSave: async (d) => {
      if (row) { await api('PUT', '/events/' + row.id, d); toast('Concert mis à jour'); }
      else { await api('POST', '/events', d); toast('Concert créé'); }
      route();
    },
  });
}
function pageEvents() {
  EDIT.event = (id) => { const r = currentRows.find((x) => x.id == id); if (r) openEventForm(r); };
  listPage({
    title: 'Concerts', endpoint: '/events', addLabel: '+ Ajouter un concert',
    onAdd: () => openEventForm(null),
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Concert', render: (r) => `<div class="nm">${esc(r.name)}</div>${r.mux_playback_id ? '<div class="em">🎬 vidéo Mux</div>' : ''}` },
      { label: 'Artiste', render: (r) => esc(r.artist || '—') },
      { label: 'Prix', render: (r) => '$' + esc(r.ticket_price || '0') },
      { label: 'Statut', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.start_date_time) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="event:${r.id}">Modifier</button><button class="btn del" data-del="/events/${r.id}">Supprimer</button>` },
    ],
  });
}

function pagePackages() {
  EDIT.pkg = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier le package', fields: [{ name: 'name', label: 'Nom', value: r.name }, { name: 'points', label: 'Points', value: r.points }, { name: 'price', label: 'Prix', value: r.price }], onSave: async (d) => { await api('PUT', '/packages/' + id, d); toast('Modifié'); route(); } });
  };
  listPage({
    title: 'Packages', endpoint: '/packages', addLabel: '+ Ajouter', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Points', render: (r) => esc(r.points) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="pkg:${r.id}">Modifier</button><button class="btn del" data-del="/packages/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un package', fields: [{ name: 'name', label: 'Nom' }, { name: 'points', label: 'Points' }, { name: 'price', label: 'Prix' }], onSave: async (d) => { await api('POST', '/packages', d); toast('Ajouté'); reload(); } }),
  });
}

function subForm(row) {
  modal({
    title: row ? "Modifier l'abonnement" : 'Ajouter un abonnement', fields: [
      { name: 'name', label: 'Nom', value: row?.name },
      { name: 'tier', label: 'Palier', value: row?.tier },
      { name: 'price', label: 'Prix ($)', type: 'number', value: row?.price || '0' },
      { name: 'period', label: 'Période', type: 'select', value: row?.period || 'month', options: [{ value: 'month', label: 'Mois' }, { value: 'year', label: 'An' }] },
      { name: 'slot_from', label: 'Places : de (n°)', type: 'number', value: row?.slot_from, placeholder: '1' },
      { name: 'slot_to', label: 'Places : à (n°)', type: 'number', value: row?.slot_to, placeholder: '24' },
      { name: 'image', label: 'Image de l\'abonnement (fichier)', type: 'file', accept: 'image/*' },
      { name: 'active', label: 'Actif ?', type: 'checkbox', value: row ? !!row.active : true, hint: 'Visible dans l\'app' },
    ],
    onSave: async (d) => { if (row) { await api('PUT', '/subscriptions/' + row.id, d); toast('Modifié'); } else { await api('POST', '/subscriptions', d); toast('Ajouté'); } route(); },
  });
}
function pageSubscriptions() {
  EDIT.sub = (id) => { const r = currentRows.find((x) => x.id == id); if (r) subForm(r); };
  listPage({
    title: 'Abonnements', endpoint: '/subscriptions', addLabel: '+ Ajouter', onAdd: () => subForm(null), columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Palier', render: (r) => esc(r.tier) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'Période', render: (r) => esc(r.period === 'year' ? 'an' : 'mois') },
      { label: 'Actif', render: (r) => badge(r.active ? 'active' : 'pending') },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="sub:${r.id}">Modifier</button><button class="btn del" data-del="/subscriptions/${r.id}">Supprimer</button>` },
    ],
  });
}

// Parrainages
async function pageReferrals() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data, rule, monthly } = await api('GET', '/referrals');
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Parrain', render: (r) => esc(r.referrer || '—') },
    { label: 'Filleul', render: (r) => `${esc(r.referee || '—')} ${r.referee_is_artist ? '🎤' : ''}` },
    { label: 'Récompense', render: (r) => esc(r.reward || rule.rate + '%') },
    { label: 'Ce mois', render: (r) => { const n = monthly[r.referrer_id] || 0; return `${n}/${rule.cap}` + (n >= rule.cap ? ' <span class="badge rejected">plafond</span>' : ''); } },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `${r.status !== 'validated' ? `<button class="btn status" data-val="${r.id}">Valider</button>` : ''}<button class="btn del" data-del="/referrals/${r.id}">Supprimer</button>` },
  ];
  view().innerHTML = `
    <div class="head-row"><h1 class="page-title">Parrainages</h1>
      <div style="display:flex;gap:10px">
        <button class="add-btn" id="addRef">+ Ajouter</button>
        <button class="add-btn" id="ruleBtn" style="background:transparent;border:1px solid var(--gold);color:var(--gold)">⚙️ ${rule.rate}% · max ${rule.cap}/mois</button>
      </div></div>
    <p style="color:var(--muted);margin-bottom:14px">Règle actuelle : <b style="color:var(--gold)">${rule.rate}%</b> par nouvel artiste parrainé, plafonné à <b style="color:var(--gold)">${rule.cap}</b> parrainages par mois.</p>
    ${tableShellInner(cols)}`;
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
  view().querySelector('#addRef').onclick = async () => {
    const { data: users } = await api('GET', '/users-list');
    const opts = [{ value: '', label: '— Choisir —' }, ...users.map((u) => ({ value: u.id, label: u.name }))];
    modal({
      title: 'Ajouter un parrainage', fields: [
        { name: 'referrer_id', label: 'Parrain', type: 'select', options: opts },
        { name: 'referee_id', label: 'Filleul', type: 'select', options: opts },
        { name: 'status', label: 'Statut', type: 'select', value: 'validated', options: [{ value: 'validated', label: 'Validé' }, { value: 'pending', label: 'En attente' }] },
      ],
      onSave: async (d) => { await api('POST', '/referrals', d); toast('Parrainage ajouté'); route(); },
    });
  };
  view().querySelector('#ruleBtn').onclick = () => modal({
    title: 'Règle de parrainage', fields: [
      { name: 'rate', label: 'Pourcentage par nouvel artiste (%)', type: 'number', value: rule.rate },
      { name: 'cap', label: 'Plafond mensuel (nombre de parrainages)', type: 'number', value: rule.cap },
    ],
    onSave: async (d) => { await api('PUT', '/referral-settings', d); toast('Règle enregistrée'); route(); },
  });
  view().querySelectorAll('[data-val]').forEach((b) => b.onclick = async () => { await api('POST', `/referrals/${b.dataset.val}/validate`); toast('Validé'); route(); });
}

function pageAbusive() {
  listPage({
    title: 'Mots interdits', endpoint: '/abusive', addLabel: '+ Ajouter', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Mot', render: (r) => esc(r.word) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/abusive/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un mot', fields: [{ name: 'word', label: 'Mot interdit' }], onSave: async (d) => { await api('POST', '/abusive', d); toast('Ajouté'); reload(); } }),
  });
}

function pageReviews() {
  listPage({
    title: 'Avis', endpoint: '/reviews', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Utilisateur', render: (r) => esc(r.user || r.email || '—') },
      { label: 'Concert', render: (r) => esc(r.event || '—') },
      { label: 'Note', render: (r) => '⭐'.repeat(r.rating || 0) },
      { label: 'Commentaire', render: (r) => esc(r.comment || '') },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/reviews/${r.id}">Supprimer</button>` },
    ],
  });
}

async function pageWithdrawals() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/withdrawals');
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Utilisateur', render: (r) => esc(r.artist_name || r.user || r.email || '—') },
    { label: 'Montant', render: (r) => '$' + esc(r.amount) },
    { label: 'Banque', render: (r) => esc(r.bank || '—') },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `<button class="btn status" data-wd="${r.id}" data-s="approved">Approuver</button><button class="btn del" data-wd="${r.id}" data-s="rejected">Refuser</button>` },
  ];
  view().innerHTML = tableShell('Retraits', cols);
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
  view().querySelectorAll('[data-wd]').forEach((b) => b.onclick = async () => {
    await api('POST', `/withdrawals/${b.dataset.wd}/status`, { status: b.dataset.s });
    toast('Statut → ' + (STATUS_FR[b.dataset.s] || b.dataset.s)); pageWithdrawals();
  });
}

function pageTransactions() {
  listPage({
    title: 'Transactions', endpoint: '/transactions', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Reçu', render: (r) => esc(r.receipt_number) },
      { label: 'Utilisateur', render: (r) => esc(r.user || r.email || '—') },
      { label: 'Concert', render: (r) => esc(r.event || '—') },
      { label: 'Montant', render: (r) => '$' + esc(r.price_paid || '0') },
      { label: 'Statut', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
    ],
  });
}

async function pageReports() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/reports');
  view().innerHTML = `
    <h1 class="page-title">Rapports</h1>
    <div class="cards" style="margin-bottom:18px">
      <div class="card"><div class="row"><div class="ic-box" style="background:rgba(224,167,58,.15);color:#e0a73a">💰</div><div class="num">$${Number(data.revenue).toLocaleString('fr-FR')}</div></div><div class="lbl">Revenus totaux</div></div>
      <div class="card"><div class="row"><div class="ic-box" style="background:rgba(59,130,246,.15);color:#7eb0ff">🎟️</div><div class="num">${data.tickets_sold}</div></div><div class="lbl">Billets vendus</div></div>
    </div>
    <div class="report-grid">
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">Top concerts (ventes)</h3>${(data.top_events || []).map((e) => `<div class="kv"><span>${esc(e.name)}</span><span>${e.sales}</span></div>`).join('') || '<div class="empty">—</div>'}</div>
      <div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">Concerts par genre</h3>${(data.by_genre || []).map((g) => `<div class="kv"><span>${esc(g.name)}</span><span>${g.events}</span></div>`).join('') || '<div class="empty">—</div>'}</div>
    </div>`;
}

// Boîte à idées
async function pageIdeas() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/ideas');
  const STATUSES = [['new', 'Nouveau'], ['reviewed', 'Vu'], ['implemented', 'Implémenté'], ['rejected', 'Refusé']];
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Auteur', render: (r) => `<div class="nm">${esc(r.author || 'Anonyme')}</div><div class="em">${esc(r.email || '')}</div>` },
    { label: 'Catégorie', render: (r) => esc(r.category || '—') },
    { label: 'Idée', render: (r) => esc(r.message) },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `<select class="idea-st" data-id="${r.id}" style="background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:7px;padding:6px;margin-right:6px">${STATUSES.map(([v, l]) => `<option value="${v}" ${r.status === v ? 'selected' : ''}>${l}</option>`).join('')}</select><button class="btn del" data-del="/ideas/${r.id}">Supprimer</button>` },
  ];
  view().innerHTML = tableShell('💡 Boîte à idées', cols);
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
  view().addEventListener('change', async (e) => {
    const s = e.target.closest('.idea-st'); if (!s) return;
    await api('POST', `/ideas/${s.dataset.id}/status`, { status: s.value }); toast('Statut mis à jour');
  });
}

function pageLeads() {
  listPage({
    title: 'Contacts / Leads', endpoint: '/contact-leads', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Email', render: (r) => esc(r.email) },
      { label: 'Téléphone', render: (r) => esc(r.phone || '—') },
      { label: 'Message', render: (r) => esc(r.message || '') },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/contact-leads/${r.id}">Supprimer</button>` },
    ],
  });
}

function pageFaqs() {
  EDIT.faq = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier la FAQ', fields: [{ name: 'question', label: 'Question', value: r.question }, { name: 'answer', label: 'Réponse', type: 'textarea', value: r.answer }], onSave: async (d) => { await api('PUT', '/faqs/' + id, d); toast('Modifiée'); route(); } });
  };
  listPage({
    title: 'FAQ', endpoint: '/faqs', addLabel: '+ Ajouter',
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Question', render: (r) => esc(r.question) },
      { label: 'Réponse', render: (r) => esc(r.answer) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="faq:${r.id}">Modifier</button><button class="btn del" data-del="/faqs/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter une FAQ', fields: [{ name: 'question', label: 'Question' }, { name: 'answer', label: 'Réponse', type: 'textarea' }], onSave: async (d) => { await api('POST', '/faqs', d); toast('Ajoutée'); reload(); } }),
  });
}

async function pageCms() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/cms');
  view().innerHTML = `<h1 class="page-title">CMS — pages du site</h1><div class="cms-grid">${data.map((p) => `
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

async function pageProfile() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/profile');
  view().innerHTML = `<h1 class="page-title">Profil</h1>
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

// Délégation globale Supprimer / Modifier / Statut
document.addEventListener('click', (e) => {
  const del = e.target.closest('[data-del]');
  if (del) { confirmDelete(async () => { await api('DELETE', del.dataset.del); toast('Supprimé'); route(); }); return; }
  const ed = e.target.closest('[data-edit]');
  if (ed) { const [type, id] = ed.dataset.edit.split(':'); EDIT[type]?.(id); return; }
  const st = e.target.closest('[data-status]');
  if (st) {
    const r = currentRows.find((x) => x.id == st.dataset.status);
    const next = r?.status === 'active' ? 'pending' : 'active';
    api('POST', `/users/${st.dataset.status}/status`, { status: next })
      .then(() => { toast('Statut → ' + (STATUS_FR[next] || next)); route(); }).catch((err) => toast(err.message));
  }
});

const ROUTES = {
  dashboard: pageDashboard, users: pageUsers, genres: pageGenres, 'user-genres': pageUserGenres,
  events: pageEvents, packages: pagePackages, subscriptions: pageSubscriptions, referrals: pageReferrals,
  abusive: pageAbusive, reviews: pageReviews, withdrawals: pageWithdrawals, transactions: pageTransactions,
  reports: pageReports, ideas: pageIdeas, leads: pageLeads, faqs: pageFaqs, cms: pageCms, profile: pageProfile,
};

window.addEventListener('hashchange', route);
$('login-btn').onclick = login;
$('login-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') login(); });
$('logout-btn').onclick = logout;
if (token && admin) boot(); else { $('login').classList.remove('hidden'); }

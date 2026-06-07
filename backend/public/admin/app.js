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
  if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
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
const STATUS_FR = { active: 'Actif', pending: 'En attente', live: 'En direct', published: 'Publié', completed: 'Terminé', cancelled: 'Annulé', approved: 'Approuvé', rejected: 'Refusé', validated: 'Validé' };
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
    return `<input type="${f.type || 'text'}" data-k="${f.name}" value="${esc(f.value ?? '')}" placeholder="${esc(f.placeholder || '')}">`;
  };
  bg.innerHTML = `<div class="modal" ${wide ? 'style="width:560px"' : ''}><h3>${esc(title)}</h3>${fields.map((f) => `<label>${esc(f.label)}</label>${fieldHtml(f)}`).join('')}
    <div class="modal-actions"><button class="cancel">Annuler</button><button class="btn gold save">Enregistrer</button></div></div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  bg.querySelector('.save').onclick = async () => {
    const data = {};
    bg.querySelectorAll('[data-k]').forEach((el) => { data[el.dataset.k] = el.type === 'checkbox' ? el.checked : el.value; });
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
async function pageDashboard() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/stats');
  const today = new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  const cards = [
    { ic: '👥', bg: 'rgba(59,130,246,.15)', col: '#7eb0ff', n: data.total_users, l: 'Utilisateurs', bar: '70%', barc: '#3b82f6' },
    { ic: '🎤', bg: 'rgba(216,180,90,.15)', col: '#d8b45a', n: data.total_artists, l: 'Artistes', bar: '60%', barc: '#d8b45a' },
    { ic: '📅', bg: 'rgba(31,157,87,.15)', col: '#4ade80', n: data.total_events, l: 'Concerts', bar: '55%', barc: '#1f9d57' },
    { ic: '🤝', bg: 'rgba(168,85,247,.15)', col: '#c084fc', n: data.total_referrals, l: 'Parrainages', bar: '45%', barc: '#a855f7' },
    { ic: '💰', bg: 'rgba(224,167,58,.15)', col: '#e0a73a', n: '$' + Number(data.total_revenue).toLocaleString('fr-FR'), l: 'Revenus', bar: '85%', barc: '#e0a73a' },
  ];
  view().innerHTML = `
    <div class="dash-banner">
      <div><h2>Tableau de bord</h2><p>Bienvenue, Admin • Voici le résumé de la plateforme</p></div>
      <div class="dash-date">📅 ${today}</div>
    </div>
    <div class="cards">${cards.map((c) => `
      <div class="card">
        <div class="row"><div class="ic-box" style="background:${c.bg};color:${c.col}">${c.ic}</div><div class="num">${c.n}</div></div>
        <div class="lbl">${c.l}</div><div class="bar"><i style="width:${c.bar};background:${c.barc}"></i></div>
      </div>`).join('')}</div>`;
}

// Utilisateurs (onglets)
async function pageUsers() {
  let type = 'all';
  async function load() {
    const { data, counts } = await api('GET', '/users?type=' + (type === 'all' ? '' : type));
    const cols = [
      { label: '#', render: (r) => r.id },
      { label: 'Utilisateur', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
      { label: 'Téléphone', render: (r) => esc(r.phone_number || '—') },
      { label: 'Adresse', render: (r) => esc(r.address || 'N/A') },
      { label: 'Statut', render: (r) => badge(r.status) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
      { label: 'Action', render: (r) => `<button class="btn status" data-act="status" data-id="${r.id}" data-s="${r.status}">Statut</button><button class="btn del" data-act="del" data-id="${r.id}">Supprimer</button>` },
    ];
    const host = view().querySelector('#utable');
    host.innerHTML = `<div class="tabs">
      <button data-t="all" class="${type === 'all' ? 'active' : ''}">Tous (${counts.all})</button>
      <button data-t="user" class="${type === 'user' ? 'active' : ''}">Utilisateurs (${counts.user})</button>
      <button data-t="artist" class="${type === 'artist' ? 'active' : ''}">Artistes (${counts.artist})</button>
    </div>` + tableShellInner(cols);
    host.querySelectorAll('.tabs button').forEach((b) => b.onclick = () => { type = b.dataset.t; load(); });
    mountTable(host, { columns: cols, rows: data });
    host.querySelectorAll('[data-act]').forEach((b) => b.onclick = async () => {
      const id = b.dataset.id;
      if (b.dataset.act === 'del') return confirmDelete(async () => { await api('DELETE', '/users/' + id); toast('Supprimé'); load(); });
      const next = b.dataset.s === 'active' ? 'pending' : 'active';
      await api('POST', `/users/${id}/status`, { status: next }); toast('Statut → ' + (STATUS_FR[next] || next)); load();
    });
  }
  view().innerHTML = `<div class="head-row"><h1 class="page-title">Utilisateurs</h1><button class="add-btn" id="adduser">+ Ajouter</button></div><div id="utable"><div class="empty">Chargement…</div></div>`;
  view().querySelector('#adduser').onclick = () => modal({
    title: 'Ajouter un utilisateur',
    fields: [{ name: 'full_name', label: 'Nom complet' }, { name: 'email', label: 'Email', type: 'email' }, { name: 'password', label: 'Mot de passe', type: 'password' }, { name: 'is_artist', label: 'Artiste ?', type: 'checkbox', hint: 'Compte artiste' }],
    onSave: async (d) => { await api('POST', '/users', d); toast('Utilisateur créé'); load(); },
  });
  load();
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
  listPage({
    title: 'Genres par utilisateur', endpoint: '/user-genres', columns: [
      { label: '#', render: (r) => r.user_id },
      { label: 'Utilisateur', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(r.full_name || 'N/A')}</div><div class="em">${esc(r.email)}</div></div></div>` },
      { label: 'Genre', render: (r) => esc(r.genre) },
      { label: 'Date', render: (r) => fmtDate(r.created_at) },
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
      { name: 'cover_image', label: 'Image de couverture (nom de fichier ou URL)', value: row?.cover_image },
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
  listPage({
    title: 'Packages', endpoint: '/packages', addLabel: '+ Ajouter', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Points', render: (r) => esc(r.points) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'Action', render: (r) => `<button class="btn del" data-del="/packages/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un package', fields: [{ name: 'name', label: 'Nom' }, { name: 'points', label: 'Points' }, { name: 'price', label: 'Prix' }], onSave: async (d) => { await api('POST', '/packages', d); toast('Ajouté'); reload(); } }),
  });
}

function pageSubscriptions() {
  listPage({
    title: 'Abonnements', endpoint: '/subscriptions', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Palier', render: (r) => esc(r.tier) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'Période', render: (r) => esc(r.period === 'year' ? 'an' : 'mois') },
      { label: 'Actif', render: (r) => badge(r.active ? 'active' : 'pending') },
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
    <div class="head-row"><h1 class="page-title">Parrainages</h1><button class="add-btn" id="ruleBtn">⚙️ Règle : ${rule.rate}% · max ${rule.cap}/mois</button></div>
    <p style="color:var(--muted);margin-bottom:14px">Règle actuelle : <b style="color:var(--gold)">${rule.rate}%</b> par nouvel artiste parrainé, plafonné à <b style="color:var(--gold)">${rule.cap}</b> parrainages par mois.</p>
    ${tableShellInner(cols)}`;
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
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

// Délégation globale Supprimer / Modifier
document.addEventListener('click', (e) => {
  const del = e.target.closest('[data-del]');
  if (del) { confirmDelete(async () => { await api('DELETE', del.dataset.del); toast('Supprimé'); route(); }); return; }
  const ed = e.target.closest('[data-edit]');
  if (ed) { const [type, id] = ed.dataset.edit.split(':'); EDIT[type]?.(id); }
});

const ROUTES = {
  dashboard: pageDashboard, users: pageUsers, genres: pageGenres, 'user-genres': pageUserGenres,
  events: pageEvents, packages: pagePackages, subscriptions: pageSubscriptions, referrals: pageReferrals,
  abusive: pageAbusive, reviews: pageReviews, withdrawals: pageWithdrawals, transactions: pageTransactions,
  reports: pageReports, leads: pageLeads, faqs: pageFaqs, cms: pageCms, profile: pageProfile,
};

window.addEventListener('hashchange', route);
$('login-btn').onclick = login;
$('login-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') login(); });
$('logout-btn').onclick = logout;
if (token && admin) boot(); else { $('login').classList.remove('hidden'); }

'use strict';
// ════════════════════════════════════════════════════════════════════
// VYBZZZ — Dashboard admin (SPA vanilla JS). Thème bleu nuit + or. FR.
// ════════════════════════════════════════════════════════════════════

const API = '/api/admin';
let token = localStorage.getItem('vybzzz_admin_token') || '';
let admin = JSON.parse(localStorage.getItem('vybzzz_admin') || 'null');
let currentRows = [];
const EDIT = {};
const DUP = {};

// ─── Fuseaux horaires courants (offset en minutes vs UTC) ───
// Sert a convertir l'heure LOCALE du lieu du concert en UTC pour le stockage,
// afin que chaque spectateur la voie ensuite dans SON propre fuseau (app cote client).
const TZ_OFFSETS = [
  { value: '-720', label: 'GMT-12' }, { value: '-660', label: 'GMT-11' },
  { value: '-600', label: 'GMT-10 (Hawaii)' }, { value: '-540', label: 'GMT-9 (Alaska)' },
  { value: '-480', label: 'GMT-8 (Los Angeles)' }, { value: '-420', label: 'GMT-7 (Denver)' },
  { value: '-360', label: 'GMT-6 (Mexico)' }, { value: '-300', label: 'GMT-5 (New York)' },
  { value: '-240', label: 'GMT-4 (Guadeloupe)' }, { value: '-180', label: 'GMT-3 (Guyane, Cayenne)' },
  { value: '-120', label: 'GMT-2' }, { value: '-60', label: 'GMT-1 (Açores)' },
  { value: '0', label: 'GMT+0 (Londres)' }, { value: '60', label: 'GMT+1 (Paris, Berlin)' },
  { value: '120', label: 'GMT+2 (Le Caire, Athenes)' }, { value: '180', label: 'GMT+3 (Moscou)' },
  { value: '210', label: 'GMT+3:30 (Teheran)' }, { value: '240', label: 'GMT+4 (Dubai)' },
  { value: '270', label: 'GMT+4:30 (Kaboul)' }, { value: '300', label: 'GMT+5 (Karachi)' },
  { value: '330', label: 'GMT+5:30 (Inde)' }, { value: '345', label: 'GMT+5:45 (Nepal)' },
  { value: '360', label: 'GMT+6 (Dacca)' }, { value: '420', label: 'GMT+7 (Bangkok)' },
  { value: '480', label: 'GMT+8 (Pekin, Singapour)' }, { value: '540', label: 'GMT+9 (Tokyo)' },
  { value: '570', label: 'GMT+9:30 (Adelaide)' }, { value: '600', label: 'GMT+10 (Sydney)' },
  { value: '660', label: 'GMT+11' }, { value: '720', label: 'GMT+12 (Auckland)' },
];

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
  { group: 'Vue d\'ensemble', items: [
    { id: 'dashboard', label: 'Tableau de bord', ic: '🏠' },
    { id: 'audience', label: 'Audience du site', ic: '📊' },
    { id: 'lives', label: 'Lives en direct', ic: '🔴' },
  ] },
  { group: 'Gestion', items: [
    { id: 'users', label: 'Utilisateurs', ic: '👥' },
    { id: 'geo', label: 'Pays / Carte', ic: '🌍' },
    { id: 'genres', label: 'Genres', ic: '🎵' },
    { id: 'user-genres', label: 'Genres par user', ic: '🏷️' },
    { id: 'events', label: 'Concerts', ic: '📅' },
    { id: 'feed-clips', label: 'Feeds (Pour toi / Clips)', ic: '🎬' },
    { id: 'packages', label: 'Packages', ic: '📦' },
    { id: 'subscriptions', label: 'Abonnements', ic: '💳' },
    { id: 'referrals', label: 'Parrainages', ic: '🤝' },
    { id: 'abusive', label: 'Mots interdits', ic: '🚫' },
    { id: 'reviews', label: 'Avis', ic: '⭐' },
    { id: 'splash', label: 'Page de lancement', ic: '🚀' },
  ] },
  { group: 'Finance', items: [
    { id: 'apporteurs', label: 'Apporteurs / Agences', ic: '🏢' },
    { id: 'withdrawals', label: 'Retraits', ic: '🏦' },
    { id: 'transactions', label: 'Transactions', ic: '💸' },
    { id: 'reports', label: 'Rapports', ic: '📈' },
  ] },
  { group: 'Support & contenu', items: [
    { id: 'support', label: 'Support (tickets app)', ic: '🎧' },
    { id: 'ideas', label: 'Boîte à idées', ic: '💡' },
    { id: 'leads', label: 'Contacts / Leads', ic: '📞' },
    { id: 'faqs', label: 'FAQ', ic: '❓' },
    { id: 'cms', label: 'CMS', ic: '📄' },
    { id: 'legal', label: 'Textes légaux', ic: '⚖️' },
    { id: 'challenge', label: 'Live Challenge', ic: '🏆' },
    { id: 'merch', label: 'Boutique merch', ic: '👕' },
  ] },
  { group: 'Pilotage interne', items: [
    { id: 'vibe', label: 'Réunions & CRM', ic: '🎯' },
  ] },
  { group: 'Compte', items: [
    { id: 'access', label: 'Accès & rôles', ic: '🔐' },
    { id: 'apikeys', label: 'API / Atelier', ic: '🔌' },
    { id: 'profile', label: 'Profil', ic: '👤' },
  ] },
];

// Modules délégables à un compte "staff" (doit refléter DELEGATABLE_MODULES
// côté backend). Un staff ne voit QUE les modules cochés pour lui.
const DELEGATABLE_MODULES = [
  { id: 'vibe', label: 'Réunions & CRM' },
];

// Un module est-il visible pour le compte connecté ? Seuls les comptes
// role='staff' sont restreints ; super-admin (et anciennes sessions sans
// rôle) voient tout. 'access' reste réservé au super-admin.
function allowedModule(id) {
  const isStaff = admin && admin.role === 'staff';
  if (id === 'access') return !isStaff;   // gestion des accès = super-admin uniquement
  if (!isStaff) return true;              // super-admin (ou ancienne session) = tout
  return Array.isArray(admin.scopes) && admin.scopes.includes(id);
}

function renderNav() {
  $('nav').innerHTML = NAV.map((g) => {
    const items = g.items.filter((i) => allowedModule(i.id));
    if (!items.length) return '';
    return `<div class="group">${g.group}</div>` +
      items.map((i) => `<a href="#${i.id}" data-id="${i.id}"><span class="ic">${i.ic}</span><span class="lbl">${i.label}</span></a>`).join('');
  }).join('');
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
  // Un module peut porter un paramètre dans le hash (ex. #audience?days=30) :
  // il ne fait pas partie de l'identifiant du module.
  let id = (location.hash.replace('#', '').split('?')[0] || 'dashboard');
  // Un staff qui vise un module non autorisé est renvoyé vers son 1er module.
  if (!allowedModule(id)) {
    const first = NAV.flatMap((g) => g.items).find((i) => allowedModule(i.id));
    id = first ? first.id : 'vibe';
    if (location.hash.replace('#', '').split('?')[0] !== id) { location.hash = id; return; }
  }
  setActive(id);
  (ROUTES[id] || ROUTES.dashboard)();
}

// ─── Helpers d'affichage ───
function initials(name, email) { return (name || email || '?').trim().slice(0, 2).toUpperCase(); }
function displayName(row) { return row.artist_name || row.full_name || 'N/A'; }
function avatar(row) {
  if (row.profile_image && /^https?:/.test(row.profile_image)) return `<div class="av"><img src="${esc(row.profile_image)}"></div>`;
  return `<div class="av">${esc(initials(displayName(row), row.email))}</div>`;
}
const STATUS_FR = { active: 'Actif', pending: 'En attente', live: 'En direct', published: 'Publié', completed: 'Terminé', cancelled: 'Annulé', approved: 'Approuvé (attente inscription)', rejected: 'Refusé', validated: 'Validé', new: 'Nouveau', reviewed: 'Vu', implemented: 'Implémenté', converted: 'Converti · actif' };
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
function modal({ title, fields, onSave, wide, afterRender }) {
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  const fieldHtml = (f) => {
    if (f.type === 'textarea') return `<textarea data-k="${f.name}">${esc(f.value || '')}</textarea>`;
    if (f.type === 'checkbox') return `<label style="display:flex;gap:8px;align-items:center"><input type="checkbox" data-k="${f.name}" style="width:auto" ${f.value ? 'checked' : ''}> ${esc(f.hint || '')}</label>`;
    if (f.type === 'select') return `<select data-k="${f.name}">${(f.options || []).map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(f.value) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
    if (f.type === 'file') return `<input type="file" data-k="${f.name}" accept="${esc(f.accept || 'image/*')}">`;
    if (f.type === 'datetime') return `<input type="datetime-local" step="1" data-k="${f.name}" value="${esc((f.value || '').replace(' ', 'T'))}">`;
    return `<input type="${f.type || 'text'}" data-k="${f.name}" value="${esc(f.value ?? '')}" placeholder="${esc(f.placeholder || '')}">`;
  };
  // datetime-local renvoie "AAAA-MM-JJTHH:MM[:SS]" : on remet le format
  // "AAAA-MM-JJ HH:MM:SS" attendu par le backend (secondes ajoutees si absentes).
  const normalizeDatetime = (v) => {
    if (!v) return v;
    const withSeconds = v.length === 16 ? `${v}:00` : v;
    return withSeconds.replace('T', ' ');
  };
  bg.innerHTML = `<div class="modal" ${wide ? 'style="width:560px"' : ''}><h3>${esc(title)}</h3>${fields.map((f) => `<label>${esc(f.label)}</label>${fieldHtml(f)}`).join('')}
    <div class="modal-actions"><button class="cancel">Annuler</button><button class="btn gold save">Enregistrer</button></div></div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  afterRender?.(bg);
  bg.querySelector('.save').onclick = async () => {
    const els = [...bg.querySelectorAll('[data-k]')];
    const hasFile = els.some((el) => el.type === 'file' && el.files && el.files.length);
    let data;
    if (hasFile) {
      data = new FormData();
      els.forEach((el) => {
        if (el.type === 'file') { if (el.files && el.files[0]) data.append(el.dataset.k, el.files[0]); }
        else if (el.type === 'checkbox') data.append(el.dataset.k, el.checked ? '1' : '0');
        else if (el.type === 'datetime-local') data.append(el.dataset.k, normalizeDatetime(el.value));
        else data.append(el.dataset.k, el.value);
      });
    } else {
      data = {};
      els.forEach((el) => {
        data[el.dataset.k] = el.type === 'checkbox'
          ? el.checked
          : el.type === 'datetime-local'
            ? normalizeDatetime(el.value)
            : el.value;
      });
    }
    try { await onSave(data); bg.remove(); } catch (e) { toast(e.message); }
  };
}

async function confirmDelete(fn) {
  if (!confirm('Confirmer la suppression ?')) return;
  try { await fn(); } catch (e) { toast(e.message); }
}

// ─── Mux : upload direct (le fichier PUT directement sur Mux, jamais sur
// notre serveur) + badge de statut + mode "Concert PRO" (live stream régie). ───
function muxDirectUpload(uploadUrl, file, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', uploadUrl);
    xhr.setRequestHeader('Content-Type', file.type || 'video/mp4');
    xhr.upload.onprogress = (e) => { if (e.lengthComputable && onProgress) onProgress(Math.round((e.loaded / e.total) * 100)); };
    xhr.onload = () => (xhr.status >= 200 && xhr.status < 300) ? resolve() : reject(new Error(`Échec upload Mux (${xhr.status})`));
    xhr.onerror = () => reject(new Error('Erreur réseau pendant l\'upload Mux.'));
    xhr.send(file);
  });
}
function muxBadge(status) {
  const map = { waiting: ['pending', 'Mux : en traitement…'], ready: ['active', 'Mux : prêt ✓'], errored: ['rejected', 'Mux : erreur'], expired: ['completed', 'Mux : expiré'] };
  const [cls, label] = map[status] || [];
  return cls ? `<span class="badge ${cls}">${esc(label)}</span>` : '';
}
function openMuxUploadDialog(kind, refId) {
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  bg.innerHTML = `<div class="modal"><h3>Uploader la vidéo vers Mux</h3>
    <p style="color:var(--muted);font-size:13px;margin-bottom:10px">Le fichier part directement vers Mux (jamais stocké sur notre serveur). Pour un concert long, laisse l'onglet ouvert le temps de l'envoi.</p>
    <label>Fichier vidéo</label><input type="file" id="muxfile" accept="video/*">
    <div id="muxprogress" style="margin-top:14px;color:var(--muted);font-size:13px">En attente du fichier…</div>
    <div class="modal-actions"><button class="cancel">Fermer</button><button class="btn gold" id="muxstart">Envoyer</button></div></div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  bg.querySelector('#muxstart').onclick = async () => {
    const file = bg.querySelector('#muxfile').files[0];
    const prog = bg.querySelector('#muxprogress');
    if (!file) { toast('Choisis un fichier vidéo'); return; }
    try {
      prog.textContent = 'Préparation de l\'upload…';
      const { data } = await api('POST', '/mux/direct-upload', { kind, ref_id: refId });
      await muxDirectUpload(data.upload_url, file, (pct) => { prog.textContent = `Envoi en cours… ${pct}%`; });
      prog.textContent = 'Envoyé ! Traitement Mux en cours (quelques minutes pour un concert). Rafraîchis la liste ensuite.';
      toast('Vidéo envoyée à Mux — traitement en cours');
      route();
    } catch (e) { prog.textContent = ''; toast(e.message); }
  };
}
async function toggleMuxLiveStream(eventId, hasLive) {
  try {
    if (hasLive) {
      await api('DELETE', `/events/${eventId}/mux/live-stream`);
      toast('Live stream arrêté');
      route();
      return;
    }
    const { data } = await api('POST', `/events/${eventId}/mux/live-stream`);
    const bg = document.createElement('div');
    bg.className = 'modal-bg';
    bg.innerHTML = `<div class="modal"><h3>Live stream Mux créé</h3>
      <p style="color:var(--muted);font-size:13px;margin-bottom:10px">Colle ces infos dans l'encodeur de la régie (OBS / vMix / Teradek…).</p>
      <label>URL d'ingest (RTMP)</label><input value="${esc(data.ingest_url)}" readonly onclick="this.select()">
      <label>Clé de stream (secrète)</label><input value="${esc(data.stream_key)}" readonly onclick="this.select()">
      <label>Playback ID</label><input value="${esc(data.playback_id)}" readonly onclick="this.select()">
      <div class="modal-actions"><button class="btn gold cancel">Fermer</button></div></div>`;
    document.body.appendChild(bg);
    bg.querySelector('.cancel').onclick = () => { bg.remove(); route(); };
    bg.onclick = (e) => { if (e.target === bg) { bg.remove(); route(); } };
  } catch (e) { toast(e.message); }
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
    { ic: '✅', bg: 'rgba(34,197,94,.15)', col: '#4ade80', n: s.validated_artists ?? 0, l: 'Artistes validés', bar: '40%', barc: '#22c55e' },
    { ic: '📅', bg: 'rgba(31,157,87,.15)', col: '#4ade80', n: s.total_events, l: 'Concerts', bar: '55%', barc: '#1f9d57' },
    { ic: '🤝', bg: 'rgba(168,85,247,.15)', col: '#c084fc', n: s.total_referrals, l: 'Parrainages', bar: '45%', barc: '#a855f7' },
    { ic: '💰', bg: 'rgba(224,167,58,.15)', col: '#e0a73a', n: euro(s.total_revenue), l: 'Revenus', bar: '85%', barc: '#e0a73a' },
  ];
  view().innerHTML = `
    <div class="dash-banner">
      <div><h2>Tableau de bord</h2><p>Bienvenue, Admin • Voici le résumé de la plateforme</p></div>
      <div class="dash-date">📅 ${today}</div>
    </div>
    ${s.payout ? `<div class="tcard" style="margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;border:1px solid rgba(216,180,90,.4)">
      <div>
        <div style="color:var(--gold);font-weight:700;letter-spacing:1px;font-size:12px">⏳ 1ER PAIEMENT DANS</div>
        <div style="font-size:36px;font-weight:800;line-height:1.1">${s.payout.reached ? '🎉 Débloqué' : s.payout.days_left + " <span style='font-size:16px;color:#96a0c2'>jours</span>"}</div>
      </div>
      <div style="text-align:right;color:#96a0c2;font-size:13px;line-height:1.6">
        Départ ${new Date(s.payout.start_at).toLocaleDateString('fr-FR')}<br>1er paiement le <b style="color:#d8b45a">${new Date(s.payout.target_at).toLocaleDateString('fr-FR')}</b>
      </div>
    </div>` : ''}
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
      { name: 'artist_name', label: "Nom d'artiste (prioritaire, ex. Burna Boy)", value: r.artist_name },
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
    { label: 'Utilisateur', render: (r) => `<div class="uinfo">${avatar(r)}<div><div class="nm">${esc(displayName(r))}</div><div class="em">${r.artist_name && r.full_name ? esc(r.full_name) + ' · ' : ''}${esc(r.email)}</div></div></div>` },
    { label: "Nom d'artiste", render: (r) => esc(r.artist_name || '—') },
    { label: 'Téléphone', render: (r) => esc(r.phone_number || '—') },
    { label: 'Adresse', render: (r) => esc(r.address || 'N/A') },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    { label: 'Action', render: (r) => `<button class="btn edit" data-edit="user:${r.id}">Modifier</button><button class="btn status" data-status="${r.id}">Statut</button><button class="btn grant" data-grantsub="${r.id}">Abonner</button><button class="btn del" data-del="/users/${r.id}">Supprimer</button>` },
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
// ─── Pays / Carte (répartition géographique des utilisateurs) ───
let _worldSvgCache = null;
async function loadWorldSvg() {
  if (_worldSvgCache) return _worldSvgCache;
  const r = await fetch('assets/world.svg');
  _worldSvgCache = await r.text();
  return _worldSvgCache;
}
async function pageGeo() {
  view().innerHTML = '<div class="head-row"><h1 class="page-title">Pays / Carte</h1></div><p style="color:var(--muted)">Chargement…</p>';
  let res;
  try { res = await api('GET', '/geo'); } catch (e) { view().innerHTML = '<p style="color:#f88">' + esc(e.message) + '</p>'; return; }
  const d = res.data || {};
  const countries = d.countries || [];
  const max = countries.reduce((m, c) => Math.max(m, c.count), 0) || 1;

  const badge = d.geoip_active
    ? '<span style="font-size:.72rem;color:#7ee0a8;border:1px solid rgba(126,224,168,.4);border-radius:99px;padding:3px 10px">Capture IP active</span>'
    : '<span style="font-size:.72rem;color:#e0c07e;border:1px solid rgba(224,192,126,.4);border-radius:99px;padding:3px 10px">Repli adresse (geoip inactif)</span>';

  const list = countries.length
    ? countries.map((c) => `
      <div class="geo-row">
        <span class="geo-flag">${c.flag}</span>
        <span class="geo-name">${esc(c.name)}</span>
        <span class="geo-bar"><i style="width:${Math.round((c.count / max) * 100)}%"></i></span>
        <span class="geo-count">${c.count}</span>
      </div>`).join('')
    : '<p style="color:var(--muted)">Aucun utilisateur localisé pour l’instant. Les pays se rempliront à mesure des connexions.</p>';

  view().innerHTML = `
    <div class="head-row"><h1 class="page-title">Pays / Carte</h1>${badge}</div>
    <div class="geo-stats">
      <div class="geo-stat"><b>${d.total_located || 0}</b><span>utilisateurs localisés</span></div>
      <div class="geo-stat"><b>${d.total_countries || 0}</b><span>pays / territoires</span></div>
      <div class="geo-stat"><b>${countries[0] ? countries[0].flag + ' ' + esc(countries[0].name) : '—'}</b><span>1ᵉʳ marché</span></div>
    </div>
    <div class="geo-grid">
      <div class="geo-map card" id="geoMap"><div style="color:var(--muted);padding:40px;text-align:center">Chargement de la carte…</div></div>
      <div class="geo-list card"><h3 style="margin:0 0 14px">Classement des pays</h3>${list}</div>
    </div>`;

  // Carte : injecte le SVG monde et colore chaque pays selon l'activité (choroplèthe dorée).
  try {
    const svg = await loadWorldSvg();
    const host = document.getElementById('geoMap');
    if (host) {
      host.innerHTML = svg;
      const el = host.querySelector('svg');
      if (el) { el.removeAttribute('width'); el.removeAttribute('height'); el.style.width = '100%'; el.style.height = 'auto'; }
      countries.forEach((c) => {
        const p = host.querySelector('path#' + c.code.toLowerCase());
        if (!p) return;
        const ratio = c.count / max;
        p.style.fill = 'rgba(230,199,106,' + (0.28 + 0.62 * ratio).toFixed(2) + ')';
        p.style.stroke = '#E6C76A';
        p.style.strokeWidth = '0.4';
        const t = document.createElementNS('http://www.w3.org/2000/svg', 'title');
        t.textContent = c.name + ' — ' + c.count + ' utilisateur' + (c.count > 1 ? 's' : '');
        p.appendChild(t);
      });
    }
  } catch (_) {
    const host = document.getElementById('geoMap');
    if (host) host.innerHTML = '<p style="color:var(--muted);padding:30px">Carte indisponible (le classement ci-contre reste à jour).</p>';
  }
}

// ─── Clés API (publication machine-à-machine, ex : Atelier) ───
async function pageApiKeys() {
  view().innerHTML = '<div class="head-row"><h1 class="page-title">API / Atelier</h1><button class="add-btn" id="newkey">+ Générer une clé</button></div><p style="color:var(--muted)">Chargement…</p>';
  let rows = [];
  try { rows = (await api('GET', '/api-keys')).data || []; } catch (e) { view().innerHTML = '<p style="color:#f88">' + esc(e.message) + '</p>'; return; }

  const list = rows.length ? `
    <table class="tbl"><thead><tr><th>Nom</th><th>Clé</th><th>Dernier usage</th><th>État</th><th></th></tr></thead>
    <tbody>${rows.map((k) => `<tr>
      <td>${esc(k.name || '—')}</td>
      <td style="font-family:monospace">${esc(k.prefix || '—')}</td>
      <td>${k.last_used_at ? fmtDate(k.last_used_at) : '<span class="em">jamais</span>'}</td>
      <td>${k.active ? '<span class="badge active">Active</span>' : '<span class="badge cancelled">Révoquée</span>'}</td>
      <td>${k.active ? `<button class="btn status revoke" data-id="${k.id}">Révoquer</button>` : ''}</td>
    </tr>`).join('')}</tbody></table>` : '<p style="color:var(--muted)">Aucune clé pour l’instant.</p>';

  view().innerHTML = `
    <div class="head-row"><h1 class="page-title">API / Atelier</h1><button class="add-btn" id="newkey">+ Générer une clé</button></div>
    <p style="color:var(--muted);max-width:70ch">Ces clés permettent à un service externe (ex. <b>Atelier</b>) de publier des clips dans le feed VybzzZ via l’API <code>/api/v1/publish</code> (en-tête <code>X-API-Key</code>). La clé complète n’est affichée <b>qu’une seule fois</b>, à la création.</p>
    ${list}`;

  view().querySelector('#newkey').onclick = () => {
    modal({
      title: 'Générer une clé API',
      fields: [{ name: 'name', label: 'Nom (ex : Atelier – production)', value: '' }],
      onSave: async (d) => {
        const r = await api('POST', '/api-keys', { name: d.name });
        const key = r.data && r.data.key;
        showKeyOnce(key);
      },
    });
  };
  view().querySelectorAll('.revoke').forEach((b) => b.onclick = async () => {
    if (!confirm('Révoquer cette clé ? Les services qui l’utilisent perdront l’accès.')) return;
    await api('DELETE', '/api-keys/' + b.dataset.id); toast('Clé révoquée'); pageApiKeys();
  });
}
function showKeyOnce(key) {
  const bg = document.createElement('div'); bg.className = 'modal-bg';
  bg.innerHTML = `<div class="modal">
    <h3 style="margin:0 0 8px">🔑 Ta clé API</h3>
    <p style="color:var(--muted);margin:0 0 12px">Copie-la maintenant : elle ne sera <b>plus jamais</b> affichée.</p>
    <textarea readonly style="width:100%;font-family:monospace;min-height:64px">${esc(key || '')}</textarea>
    <div style="display:flex;gap:8px;margin-top:12px"><button class="btn gold" id="k-copy">📋 Copier</button><button class="btn" id="k-done">Fermer</button></div>
  </div>`;
  document.body.appendChild(bg);
  bg.querySelector('#k-copy').onclick = () => { navigator.clipboard?.writeText(key); toast('Copié'); };
  bg.querySelector('#k-done').onclick = () => { bg.remove(); pageApiKeys(); };
  bg.onclick = (e) => { if (e.target === bg) { bg.remove(); pageApiKeys(); } };
}

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

// Reconstruit l'heure LOCALE du lieu ("2026-06-07 02:30:00") a partir de l'UTC
// stocke + de son offset, pour pre-remplir le formulaire d'edition avec
// l'heure du lieu (pas l'UTC brut, illisible pour l'admin).
function utcToLocalDisplay(utcIso, offsetMinutes) {
  if (!utcIso) return '';
  const off = Number(offsetMinutes) || 0;
  const d = new Date(utcIso);
  if (isNaN(d.getTime())) return utcIso;
  const local = new Date(d.getTime() + off * 60000);
  const p = (n) => String(n).padStart(2, '0');
  return `${local.getUTCFullYear()}-${p(local.getUTCMonth() + 1)}-${p(local.getUTCDate())} ${p(local.getUTCHours())}:${p(local.getUTCMinutes())}:${p(local.getUTCSeconds())}`;
}

// Concerts (CRUD + Mux)
async function openEventForm(row, { duplicate = false } = {}) {
  const [{ data: artists }, { data: genres }] = await Promise.all([api('GET', '/artists-list'), api('GET', '/genres')]);
  modal({
    title: duplicate ? 'Dupliquer le concert' : (row ? 'Modifier le concert' : 'Ajouter un concert'), wide: true,
    fields: [
      { name: 'name', label: 'Nom du concert', value: row?.name },
      { name: 'artist_id', label: 'Artiste', type: 'select', value: row?.artist_id, options: [{ value: '', label: '— Choisir —' }, ...artists.map((a) => ({ value: a.id, label: a.name }))] },
      { name: 'genre_id', label: 'Genre', type: 'select', value: row?.genre_id, options: [{ value: '', label: '— Choisir —' }, ...genres.map((g) => ({ value: g.id, label: g.name }))] },
      { name: 'status', label: 'Statut', type: 'select', value: row?.status || 'published', options: [{ value: 'published', label: 'Publié' }, { value: 'live', label: 'En direct' }, { value: 'completed', label: 'Terminé' }, { value: 'cancelled', label: 'Annulé' }] },
      { name: 'ticket_price', label: 'Prix du billet ($)', type: 'number', value: row?.ticket_price || '0' },
      { name: 'start_date_time', label: 'Date/heure LOCALE du lieu (calendrier)', type: 'datetime', value: row ? utcToLocalDisplay(row.start_date_time, row.tz_offset_minutes) : '' },
      { name: 'tz_offset_minutes', label: 'Fuseau horaire du lieu', type: 'select', value: row?.tz_offset_minutes ?? '0', options: TZ_OFFSETS },
      { name: 'mux_playback_id', label: 'Vidéo — Mux Playback ID', value: row?.mux_playback_id, placeholder: 'colle l\'ID Mux (ou laisse vide)' },
      { name: 'cover', label: 'Image de couverture (fichier)', type: 'file', accept: 'image/*' },
      { name: 'cover_image', label: 'Ou nom de fichier / URL', value: row?.cover_image },
      { name: 'description', label: 'Description', type: 'textarea', value: row?.description },
      { name: 'is_banner', label: 'Mettre en bannière (carrousel accueil) ?', type: 'checkbox', value: !!row?.is_banner, hint: 'Afficher dans le carrousel' },
      { name: 'replay_enabled', label: 'Replay activé (concert rejouable) ?', type: 'checkbox', value: row ? !!row.replay_enabled : true, hint: 'Rejouable après le live' },
      { name: 'replay_duration_days', label: 'Durée du replay', type: 'select', value: row?.replay_duration_days ?? 60, options: [7, 14, 30, 60].map((d) => ({ value: d, label: d + ' jours' })) },
      { name: 'geo_mode', label: 'Géo-blocage (par secteur)', type: 'select', value: row?.geo_mode || 'off', options: [
        { value: 'off', label: 'Aucun — visible partout' },
        { value: 'block', label: 'Bloquer les pays listés (les locaux viennent sur place)' },
        { value: 'only', label: 'Autoriser UNIQUEMENT les pays listés' },
      ], hint: 'Restreint la diffusion en ligne par pays' },
      { name: 'geo_countries', label: 'Pays concernés (codes ISO-2)', value: row?.geo_countries || '', hint: 'Ex : FR,GF,BE — séparés par des virgules. Vide = pas de géo-blocage.' },
      { name: 'geo_block_hours', label: 'Durée du géo-blocage (heures)', type: 'number',
        value: (row?.geo_block_until && row?.start_date_time)
          ? Math.max(0, Math.round((new Date(row.geo_block_until) - new Date(row.start_date_time)) / 3600000))
          : '',
        hint: 'Ex : 4 → bloqué 4h dès le début du concert, puis la diffusion REPART automatiquement. Vide ou 0 = permanent.' },
    ],
    afterRender: (bg) => attachAiDescriptionButton(bg, 'event'),
    onSave: async (d) => {
      if (row && !duplicate) { await api('PUT', '/events/' + row.id, d); toast('Concert mis à jour'); }
      else { await api('POST', '/events', d); toast(duplicate ? 'Concert dupliqué' : 'Concert créé'); }
      route();
    },
  });
}

// Ajoute un bouton "✨ Générer avec IA" juste après le champ description du
// modal en cours (event ou artist) : lit nom/genre/artiste déjà saisis dans
// le formulaire, appelle Claude côté backend, remplit le textarea.
function attachAiDescriptionButton(bg, kind) {
  const textarea = bg.querySelector('[data-k="description"]') || bg.querySelector('[data-k="artist_bio"]');
  if (!textarea) return;
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'btn dup';
  btn.style.marginTop = '8px';
  btn.textContent = '✨ Générer avec IA';
  btn.onclick = async () => {
    const label = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Génération…';
    try {
      const nameEl = bg.querySelector('[data-k="name"]') || bg.querySelector('[data-k="artist_name"]');
      const artistEl = bg.querySelector('[data-k="artist_id"]');
      const genreEl = bg.querySelector('[data-k="genre_id"]');
      const { data } = await api('POST', '/ai/generate-description', {
        kind,
        name: nameEl?.value,
        artist_name: kind === 'artist' ? nameEl?.value : artistEl?.selectedOptions?.[0]?.textContent,
        genre: genreEl?.selectedOptions?.[0]?.textContent,
      });
      textarea.value = data.text;
    } catch (e) { toast(e.message); }
    finally { btn.disabled = false; btn.textContent = label; }
  };
  textarea.insertAdjacentElement('afterend', btn);
}
function pageEvents() {
  EDIT.event = (id) => { const r = currentRows.find((x) => x.id == id); if (r) openEventForm(r); };
  DUP.event = (id) => { const r = currentRows.find((x) => x.id == id); if (r) openEventForm(r, { duplicate: true }); };
  listPage({
    title: 'Concerts', endpoint: '/events', addLabel: '+ Ajouter un concert',
    onAdd: () => openEventForm(null),
    columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Concert', render: (r) => `<div class="nm">${esc(r.name)}</div>${r.mux_playback_id ? '<div class="em">🎬 vidéo Mux</div>' : ''}` },
      { label: 'Artiste', render: (r) => esc(r.artist || '—') },
      { label: 'Prix', render: (r) => '$' + esc(r.ticket_price || '0') },
      { label: 'Statut', render: (r) => badge(r.status) },
      { label: 'Vidéo', render: (r) => `${muxBadge(r.mux_upload_status)}${r.mux_live_stream_id ? '<div class="em">🔴 live en cours</div>' : ''}${r.replay_expires_at ? `<div class="em">replay jusqu'au ${fmtDate(r.replay_expires_at)}</div>` : ''}` },
      { label: 'Date', render: (r) => fmtDate(r.start_date_time) },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="event:${r.id}">Modifier</button><button class="btn dup" data-dup="event:${r.id}">Dupliquer</button><button class="btn grant" data-muxupload="event:${r.id}">🎬 Upload</button><button class="btn status" data-muxlive="event:${r.id}:${r.mux_live_stream_id ? 1 : 0}">${r.mux_live_stream_id ? '⏹ Stop live' : '🔴 Live Mux'}</button><button class="btn del" data-del="/events/${r.id}">Supprimer</button>` },
    ],
  });
}

async function feedClipForm(row, { duplicate = false } = {}) {
  // Liste des artistes pour le rattachement (le clip apparaît alors dans la
  // grille de la fiche artiste). Dégrade sans bloquer si l'appel échoue.
  let artists = [];
  try { const r = await api('GET', '/artists-list'); artists = r.data || []; } catch (e) { artists = []; }
  const artistOpts = [{ value: '', label: '— Officiel (aucun artiste) —' }];
  // Préserve le rattachement actuel même si l'auteur n'est pas un artiste.
  if (row?.user_id && !artists.some((a) => a.id == row.user_id)) {
    artistOpts.push({ value: String(row.user_id), label: (row.submitted_by || ('user #' + row.user_id)) + ' (auteur actuel)' });
  }
  artists.forEach((a) => artistOpts.push({ value: String(a.id), label: a.name }));
  modal({
    title: duplicate ? 'Dupliquer le clip' : (row ? 'Modifier le clip' : 'Ajouter un clip'),
    fields: [
      { name: 'feed', label: 'Type', type: 'select', value: row?.feed || 'for_you', options: [{ value: 'for_you', label: '🟦 Short (Pour toi — vertical/portrait)' }, { value: 'clips', label: '🟨 Clip musical (paysage 16:9)' }], hint: 'Short = contenu vertical (actu/promo). Clip = clip musical horizontal.' },
      { name: 'artist_id', label: 'Artiste (apparaît sur sa fiche profil)', type: 'select', value: row?.user_id ? String(row.user_id) : '', options: artistOpts, hint: 'Laisse « Officiel » si le clip n\'appartient à aucun artiste' },
      { name: 'title', label: 'Titre / légende (optionnel)', value: row?.title },
      { name: 'video', label: 'Fichier vidéo (upload direct)', type: 'file', accept: 'video/*' },
      { name: 'mux_playback_id', label: 'Ou Mux Playback ID (si déjà sur Mux)', value: row?.mux_playback_id, placeholder: 'laisse vide si tu uploades un fichier' },
      { name: 'position', label: 'Ordre (0 = premier)', type: 'number', value: row?.position ?? 0 },
      { name: 'active', label: 'Actif ?', type: 'checkbox', value: row ? !!row.active : true, hint: 'Visible dans l\'app' },
    ],
    onSave: async (d) => {
      if (row && !duplicate) { await api('PUT', '/feed-clips/' + row.id, d); toast('Clip modifié'); }
      else { await api('POST', '/feed-clips', d); toast(duplicate ? 'Clip dupliqué' : 'Clip ajouté'); }
      route();
    },
  });
}
// Extrait des Mux Playback IDs d'un texte libre (liste collée ou fichier .md) :
// gère les URLs mux (image/stream.mux.com/<ID>/…), les puces markdown, et les
// IDs bruts séparés par espaces / virgules / retours ligne / pipes.
function parsePlaybackIds(text) {
  const ids = new Set();
  const urlRe = /(?:image|stream)\.mux\.com\/([A-Za-z0-9]+)/g;
  let m;
  while ((m = urlRe.exec(text))) ids.add(m[1]);
  String(text).split(/[\s,;|]+/).forEach((tok) => {
    const t = tok.replace(/^[-*>#`.]+/, '').replace(/[`.]+$/, '').trim();
    if (/^[A-Za-z0-9]{20,}$/.test(t)) ids.add(t);
  });
  return [...ids];
}

// Ajout MULTIPLE de clips. Deux méthodes dans le même dialogue :
//  A) Coller / importer une liste de Playback IDs (ex. fichier .md) -> chaque
//     ID devient un clip ajouté À LA SUITE (les vidéos sont déjà sur Mux).
//  B) Uploader plusieurs fichiers vidéo (envoi direct Mux, 1 clip / fichier).
async function bulkUploadDialog() {
  let artists = [];
  try { const r = await api('GET', '/artists-list'); artists = r.data || []; } catch (e) { artists = []; }
  const artistOpts = ['<option value="">— Officiel (aucun artiste) —</option>']
    .concat(artists.map((a) => `<option value="${a.id}">${esc(a.name)}</option>`)).join('');
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  bg.innerHTML = `<div class="modal" style="max-width:580px">
    <h3>Ajouter plusieurs vidéos</h3>
    <label>Feed</label>
    <select id="bu-feed"><option value="for_you">🟦 Short (Pour toi — vertical/portrait)</option><option value="clips">🟨 Clip musical (paysage 16:9)</option></select>
    <label style="margin-top:10px">Artiste (optionnel — apparaît sur sa fiche)</label>
    <select id="bu-artist">${artistOpts}</select>

    <div style="margin-top:16px;padding-top:14px;border-top:1px solid var(--line)">
      <b style="font-size:14px">A · Par Playback ID Mux</b>
      <p style="color:var(--muted);font-size:12px;margin:4px 0 8px">Colle une liste (un ID par ligne), ou importe un fichier .md/.txt. Les URLs Mux et les puces markdown sont acceptées. Chaque ID s'ajoute à la suite du feed.</p>
      <input type="file" id="bu-idfile" accept=".md,.txt,text/*" style="margin-bottom:8px">
      <textarea id="bu-ids" rows="5" placeholder="Ixf100DM00MIBOSiPjVkEfbToOgso01NuVin19ugUXbjQA
EcO013Q00m3BON019ydIrEUd3YaAES4J9nx02arl7U862P4" style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:10px;font-family:monospace;font-size:12px"></textarea>
      <label style="display:flex;gap:8px;align-items:center;font-size:13px;color:var(--muted);margin:8px 0"><input type="checkbox" id="bu-active" checked style="width:auto"> Publier tout de suite (sinon « en attente »)</label>
      <div style="display:flex;align-items:center;gap:10px"><button class="btn gold" id="bu-addids">Ajouter ces IDs (<span id="bu-idcount">0</span>)</button></div>
    </div>

    <div style="margin-top:16px;padding-top:14px;border-top:1px solid var(--line)">
      <b style="font-size:14px">B · Uploader des fichiers vidéo</b>
      <p style="color:var(--muted);font-size:12px;margin:4px 0 8px">Sélection multiple. Chaque fichier part directement vers Mux (jamais stocké chez nous) et arrive « en attente ».</p>
      <input type="file" id="bu-files" accept="video/*" multiple>
      <div id="bu-list" style="margin-top:10px;max-height:200px;overflow:auto"></div>
      <button class="btn gold" id="bu-start" style="margin-top:8px">Envoyer les fichiers</button>
    </div>

    <div class="modal-actions"><button class="cancel">Fermer</button></div>
  </div>`;
  document.body.appendChild(bg);
  const close = () => bg.remove();
  bg.querySelector('.cancel').onclick = close;
  bg.onclick = (e) => { if (e.target === bg) close(); };
  const feedOf = () => bg.querySelector('#bu-feed').value;
  const artistOf = () => bg.querySelector('#bu-artist').value || null;

  // ── Méthode A : Playback IDs ──
  const idsArea = bg.querySelector('#bu-ids');
  const idCount = bg.querySelector('#bu-idcount');
  const refreshIdCount = () => { idCount.textContent = parsePlaybackIds(idsArea.value).length; };
  idsArea.oninput = refreshIdCount;
  bg.querySelector('#bu-idfile').onchange = (e) => {
    const f = e.target.files[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      idsArea.value = (idsArea.value ? idsArea.value + '\n' : '') + reader.result;
      refreshIdCount();
    };
    reader.readAsText(f);
  };
  bg.querySelector('#bu-addids').onclick = async () => {
    const ids = parsePlaybackIds(idsArea.value);
    if (!ids.length) { toast('Aucun Playback ID valide détecté'); return; }
    try {
      const { data } = await api('POST', '/feed-clips/bulk', {
        feed: feedOf(), artist_id: artistOf(),
        active: bg.querySelector('#bu-active').checked, playback_ids: ids,
      });
      toast(`${data?.count ?? ids.length} clip(s) ajouté(s)`);
      close();
      pageFeedClips();
    } catch (e) { toast(e.message); }
  };
  refreshIdCount();

  // ── Méthode B : upload de fichiers ──
  const listEl = bg.querySelector('#bu-list');
  const filesInput = bg.querySelector('#bu-files');
  const renderList = () => {
    const fs = [...filesInput.files];
    listEl.innerHTML = fs.length ? fs.map((f, i) => `
      <div style="display:flex;align-items:center;gap:10px;margin:6px 0">
        <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:13px">${esc(f.name)}</span>
        <div style="width:110px;background:#0A1226;border-radius:6px;overflow:hidden;height:8px"><div id="bu-bar-${i}" style="height:8px;width:0;background:var(--gold)"></div></div>
        <span id="bu-pct-${i}" class="em" style="width:44px;text-align:right">0%</span>
      </div>`).join('') : '<div class="em">Aucun fichier sélectionné.</div>';
  };
  filesInput.onchange = renderList;
  renderList();
  bg.querySelector('#bu-start').onclick = async () => {
    const fs = [...filesInput.files];
    if (!fs.length) { toast('Choisis au moins une vidéo'); return; }
    const feed = feedOf();
    const artistId = artistOf();
    const startBtn = bg.querySelector('#bu-start');
    startBtn.disabled = true; startBtn.style.opacity = '.5';
    let ok = 0, fail = 0;
    for (let i = 0; i < fs.length; i++) {
      const f = fs[i];
      const bar = bg.querySelector(`#bu-bar-${i}`);
      const pct = bg.querySelector(`#bu-pct-${i}`);
      try {
        const { data } = await api('POST', '/mux/direct-upload', {
          kind: 'clip', feed, artist_id: artistId, title: f.name.replace(/\.[^.]+$/, ''),
        });
        await muxDirectUpload(data.upload_url, f, (p) => {
          if (bar) bar.style.width = p + '%';
          if (pct) pct.textContent = p + '%';
        });
        if (pct) { pct.textContent = '✓'; pct.style.color = 'var(--gold)'; }
        ok++;
      } catch (e) {
        if (pct) { pct.textContent = '✗'; pct.style.color = '#ff6b6b'; pct.title = e.message; }
        fail++;
      }
    }
    toast(`${ok} vidéo(s) envoyée(s)${fail ? `, ${fail} échec(s)` : ''} — traitement Mux en cours`);
    startBtn.disabled = false; startBtn.style.opacity = '1';
    if (ok) setTimeout(() => { close(); pageFeedClips(); }, 900);
  };
}
function pageFeedClips() {
  EDIT.feedclip = (id) => { const r = currentRows.find((x) => x.id == id); if (r) feedClipForm(r); };
  DUP.feedclip = (id) => { const r = currentRows.find((x) => x.id == id); if (r) feedClipForm(r, { duplicate: true }); };
  const feedBadge = (f) => f === 'clips'
    ? '<span class="badge" style="background:rgba(230,199,106,.18);color:var(--gold);font-weight:700">🟨 Clips</span>'
    : '<span class="badge" style="background:rgba(90,160,255,.18);color:#7ab8ff;font-weight:700">🟦 Pour toi</span>';
  // Miniature : Mux génère une image du clip → on l'affiche pour repérer
  // le contenu d'un coup d'œil. Format adapté (paysage pour un clip, portrait
  // pour un short). Repli sur une icône si pas de Mux (fichier uploadé).
  const phBox = (w, h) => `<div style="width:${w}px;height:${h}px;border-radius:6px;background:#0A1226;display:flex;align-items:center;justify-content:center;color:var(--muted)">▶</div>`;
  const thumb = (r) => {
    if (r.mux_playback_id) {
      const land = r.feed === 'clips';
      const w = land ? 80 : 45, h = land ? 45 : 80;
      // L'aperçu vient de Mux (image.mux.com). Si l'ID n'est pas un asset Mux
      // PUBLIC valide (ID de test, playback "signed", vidéo pas encore traitée),
      // l'image renvoie 404/403 -> onerror affiche un placeholder ▶ propre au
      // lieu de l'icône "image cassée".
      return `<div style="position:relative;width:${w}px;height:${h}px">${phBox(w, h)}<img src="https://image.mux.com/${r.mux_playback_id}/thumbnail.jpg?width=${w * 2}&height=${h * 2}&fit_mode=smartcrop" onerror="this.style.display='none'" style="position:absolute;inset:0;width:${w}px;height:${h}px;object-fit:cover;border-radius:6px" loading="lazy"></div>`;
    }
    return phBox(45, 80);
  };
  const columns = [
    { label: '✓', render: (r) => r.active ? '' : `<input type="checkbox" class="chk-clip" data-id="${r.id}" style="width:18px;height:18px;cursor:pointer">` },
    { label: '#', render: (r) => r.id },
    { label: 'Aperçu', render: (r) => thumb(r) },
    { label: 'Feed', render: (r) => feedBadge(r.feed) },
    { label: 'Titre', render: (r) => esc(r.title || '—') },
    { label: 'Soumis par', render: (r) => r.user_id ? esc(r.submitted_by || ('user #' + r.user_id)) : '<span style="color:var(--muted)">Admin (officiel)</span>' },
    { label: 'Source', render: (r) => `${r.mux_playback_id ? '🎬 Mux' : (r.video_url ? '📁 Fichier' : '—')}${muxBadge(r.upload_status)}${r.expires_at ? `<div class="em">expire le ${fmtDate(r.expires_at)}</div>` : ''}` },
    { label: 'Ordre', render: (r) => r.position ?? 0 },
    { label: 'Statut', render: (r) => badge(r.active ? 'active' : 'pending') },
    { label: 'Action', render: (r) => `${!r.active ? `<button class="btn status" data-approveclip="${r.id}">Approuver</button>` : ''}<button class="btn edit" data-edit="feedclip:${r.id}">Modifier</button><button class="btn dup" data-dup="feedclip:${r.id}">Dupliquer</button><button class="btn grant" data-muxupload="clip:${r.id}">🎬 Upload</button><button class="btn del" data-del="/feed-clips/${r.id}">Supprimer</button>` },
  ];
  (async () => {
    view().innerHTML = '<div class="empty">Chargement…</div>';
    const { data } = await api('GET', '/feed-clips');
    currentRows = data || [];
    // Compte des concerts : chargé EN ARRIÈRE-PLAN (l'appel /events est lourd).
    // On n'attend plus dessus -> la page s'affiche tout de suite ('—' puis MAJ).
    const concertCount = '<span id="concert-count">…</span>';
    const isClips = (r) => r.feed === 'clips';
    const counts = { all: currentRows.length, for_you: currentRows.filter((r) => !isClips(r)).length, clips: currentRows.filter(isClips).length };
    // Les 3 surfaces de contenu de l'app, expliquées côte à côte. Cliquer sur
    // « Pour toi » / « Clips » filtre le tableau ; « Concerts » ouvre la page dédiée.
    const card = (accent, emoji, title, desc, count, action) => `
      <div class="surface-card" ${action} style="flex:1;min-width:190px;cursor:pointer;border:1px solid var(--line);border-left:4px solid ${accent};border-radius:12px;padding:14px 16px;background:var(--card2,rgba(255,255,255,.02))">
        <div style="display:flex;align-items:center;justify-content:space-between">
          <span style="font-weight:700;font-size:15px">${emoji} ${title}</span>
          <span style="font-weight:800;font-size:20px;color:${accent}">${count == null ? '—' : count}</span>
        </div>
        <div class="em" style="margin-top:4px;line-height:1.35">${desc}</div>
      </div>`;
    view().innerHTML = `<div class="head-row"><h1 class="page-title">Les 3 feeds de l'app</h1><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" id="dedupebtn">🧹 Supprimer les doublons</button><button class="add-btn" id="bulkupbtn" style="background:#7ab8ff">⬆︎ Upload multiple</button><button class="add-btn" id="addbtn">+ Ajouter un clip</button></div></div>
      <p class="em" style="margin:-6px 0 14px">Cette page gère les <b>shorts</b> (Pour toi & Clips). Les <b>Concerts</b> ont leur propre écran — cliquez sur la carte pour y aller.</p>
      <div style="display:flex;gap:12px;flex-wrap:wrap;margin:0 0 18px">
        ${card('#7ab8ff', '🟦', 'Shorts (Pour toi)', 'Contenu court vertical/portrait : actu, promo, teasers.', counts.for_you, 'data-ft-card="for_you"')}
        ${card('#e6c76a', '🟨', 'Clips', 'Clips musicaux des artistes — format paysage 16:9.', counts.clips, 'data-ft-card="clips"')}
        ${card('#ff6b6b', '🎬', 'Concerts', 'Lives & replays payants. Section séparée →', concertCount, 'data-goto="events"')}
      </div>
      <div style="display:flex;gap:8px;margin:0 0 12px;align-items:center">
        <span class="em" style="margin-right:2px">Filtrer les shorts :</span>
        ${[['all', 'Tous', counts.all], ['for_you', '🟦 Pour toi', counts.for_you], ['clips', '🟨 Clips', counts.clips]].map(([v, l, c]) => `<button class="btn" data-ft="${v}" style="padding:8px 14px">${l} <span class="em">(${c})</span></button>`).join('')}
      </div>
      <div id="bulkbar" style="display:flex;gap:10px;align-items:center;margin:0 0 12px;flex-wrap:wrap">
        <button class="btn" id="selectAllPending" style="padding:8px 14px">☑︎ Tout sélectionner (en attente)</button>
        <button class="btn gold" id="bulkApprove" disabled style="padding:8px 14px;opacity:.5">✅ Valider la sélection (<span id="bulkCount">0</span>)</button>
        <span class="em">Coche les vidéos à publier, puis valide-les toutes d'un coup.</span>
      </div>
      ${tableShellInner(columns)}`;
    const rowsFor = (t) => t === 'all' ? currentRows : (t === 'clips' ? currentRows.filter(isClips) : currentRows.filter((r) => !isClips(r)));
    // Barre de validation groupée : met à jour le compteur + l'état du bouton.
    const refreshBulk = () => {
      const sel = [...view().querySelectorAll('.chk-clip')].filter((c) => c.checked);
      const cnt = view().querySelector('#bulkCount');
      const btn = view().querySelector('#bulkApprove');
      if (cnt) cnt.textContent = sel.length;
      if (btn) { btn.disabled = sel.length === 0; btn.style.opacity = sel.length ? '1' : '.5'; }
    };
    const applyTab = (t) => {
      mountTable(view().querySelector('.tcard'), { columns, rows: rowsFor(t) });
      view().querySelectorAll('.chk-clip').forEach((c) => c.onchange = refreshBulk);
      refreshBulk();
      view().querySelectorAll('[data-ft]').forEach((b) => {
        const on = b.dataset.ft === t;
        b.style.background = on ? 'var(--gold)' : '';
        b.style.color = on ? '#1a1206' : '';
        b.style.fontWeight = on ? '700' : '';
      });
    };
    view().querySelectorAll('[data-ft]').forEach((b) => b.onclick = () => applyTab(b.dataset.ft));
    view().querySelectorAll('[data-ft-card]').forEach((c) => c.onclick = () => applyTab(c.dataset.ftCard));
    view().querySelectorAll('[data-goto]').forEach((c) => c.onclick = () => { location.hash = c.dataset.goto; });
    view().querySelector('#addbtn').onclick = () => feedClipForm(null);
    view().querySelector('#bulkupbtn').onclick = () => bulkUploadDialog();
    view().querySelector('#dedupebtn').onclick = async () => {
      if (!confirm('Supprimer les clips en double (même vidéo Mux) ? On garde le plus ancien de chaque.')) return;
      try {
        const { data } = await api('POST', '/feed-clips/dedupe', {});
        toast(`${data?.removed ?? 0} doublon(s) supprimé(s)`);
        pageFeedClips();
      } catch (e) { toast(e.message); }
    };
    // Tout cocher / tout décocher les clips EN ATTENTE de la vue courante.
    view().querySelector('#selectAllPending').onclick = () => {
      const checks = [...view().querySelectorAll('.chk-clip')];
      const allOn = checks.length && checks.every((c) => c.checked);
      checks.forEach((c) => { c.checked = !allOn; });
      refreshBulk();
    };
    // Valider la sélection en une seule requête.
    view().querySelector('#bulkApprove').onclick = async () => {
      const ids = [...view().querySelectorAll('.chk-clip')].filter((c) => c.checked).map((c) => Number(c.dataset.id));
      if (!ids.length) return;
      try {
        await api('POST', '/feed-clips/approve-batch', { ids });
        toast(`${ids.length} vidéo(s) validée(s)`);
        pageFeedClips();
      } catch (e) { toast(e.message); }
    };
    applyTab('all');
    // Compteur concerts en arrière-plan : ne bloque plus l'affichage de la page.
    api('GET', '/events').then((ev) => {
      const el = document.getElementById('concert-count');
      if (el) el.textContent = (ev.data || []).length;
    }).catch(() => {
      const el = document.getElementById('concert-count');
      if (el) el.textContent = '—';
    });
  })();
}

function pagePackages() {
  EDIT.pkg = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier le package', fields: [{ name: 'name', label: 'Nom', value: r.name }, { name: 'points', label: 'Points', value: r.points }, { name: 'price', label: 'Prix ($)', value: r.price }, { name: 'revenuecat_product_id', label: 'ID produit RevenueCat (IAP)', value: r.revenuecat_product_id, placeholder: 'ex: vybzz_points_500' }, { name: 'active', label: 'Actif ?', type: 'checkbox', value: r ? !!r.active : true, hint: 'Visible dans l\'app' }], onSave: async (d) => { await api('PUT', '/packages/' + id, d); toast('Modifié'); route(); } });
  };
  listPage({
    title: 'Packages', endpoint: '/packages', addLabel: '+ Ajouter', columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Points', render: (r) => esc(r.points) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'IAP', render: (r) => r.revenuecat_product_id ? esc(r.revenuecat_product_id) : '<span class="em" style="color:#c9a24b">non mappé</span>' },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="pkg:${r.id}">Modifier</button><button class="btn del" data-del="/packages/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un package', fields: [{ name: 'name', label: 'Nom' }, { name: 'points', label: 'Points' }, { name: 'price', label: 'Prix ($)' }, { name: 'revenuecat_product_id', label: 'ID produit RevenueCat (IAP)', placeholder: 'ex: vybzz_points_500' }, { name: 'active', label: 'Actif ?', type: 'checkbox', value: true, hint: 'Visible dans l\'app' }], onSave: async (d) => { await api('POST', '/packages', d); toast('Ajouté'); reload(); } }),
  });
}

function subForm(row, { duplicate = false } = {}) {
  modal({
    title: duplicate ? "Dupliquer l'abonnement" : (row ? "Modifier l'abonnement" : 'Ajouter un abonnement'), fields: [
      { name: 'name', label: 'Nom', value: row?.name },
      { name: 'tier', label: 'Palier', value: row?.tier },
      { name: 'price', label: 'Prix mensuel ($)', type: 'number', value: row?.price || '0' },
      { name: 'price_annual', label: 'Prix annuel ($)', type: 'number', value: row?.price_annual, placeholder: 'ex. 99.99 (laisser vide si aucun tarif annuel)' },
      { name: 'period', label: 'Période', type: 'select', value: row?.period || 'month', options: [{ value: 'month', label: 'Mois' }, { value: 'year', label: 'An' }] },
      { name: 'commission', label: 'Commission (%)', type: 'number', value: row?.commission, placeholder: '60' },
      { name: 'slot_from', label: 'Places : de (n°)', type: 'number', value: row?.slot_from, placeholder: '1' },
      { name: 'slot_to', label: 'Places : à (n°)', type: 'number', value: row?.slot_to, placeholder: '24' },
      { name: 'badge', label: 'Badge / ruban (ex. OFFRE LIMITÉE)', value: row?.badge, placeholder: 'OFFRE LIMITÉE' },
      { name: 'perks', label: 'Avantages annuels (un par ligne)', type: 'textarea', value: row?.perks, placeholder: 'Badge Founder permanent\nAccès bêta\nSupport prioritaire' },
      { name: 'stripe_price_id', label: 'Stripe Price ID — mensuel', value: row?.stripe_price_id, placeholder: 'price_... (Dashboard Stripe → Produit → Price ID)' },
      { name: 'stripe_price_id_annual', label: 'Stripe Price ID — annuel', value: row?.stripe_price_id_annual, placeholder: 'price_... (laisser vide si pas de tarif annuel)' },
      { name: 'revenuecat_product_id', label: 'RevenueCat Product ID (IAP App Store/Play Store)', value: row?.revenuecat_product_id, placeholder: 'ex. vybzz_99_1m (laisser vide si pas d\'IAP pour ce palier)' },
      { name: 'image', label: 'Image de l\'abonnement (fichier)', type: 'file', accept: 'image/*' },
      { name: 'active', label: 'Actif ?', type: 'checkbox', value: row ? !!row.active : true, hint: 'Visible dans l\'app' },
    ],
    onSave: async (d) => { if (row && !duplicate) { await api('PUT', '/subscriptions/' + row.id, d); toast('Modifié'); } else { await api('POST', '/subscriptions', d); toast(duplicate ? 'Dupliqué' : 'Ajouté'); } route(); },
  });
}
// Panneau "Gérer l'abonnement" : montre le palier actuel du user (s'il y en
// a un) avec un bouton "Retirer", et un select pour attribuer/rétrograder
// vers un autre palier — remplace l'abonnement actif existant (pas de doublon).
async function openGrantSubModal(userId) {
  const [{ data: subs }, { data: userSubs }] = await Promise.all([
    api('GET', '/subscriptions'),
    api('GET', '/user-subscriptions?user_id=' + userId),
  ]);
  const activeSubs = subs.filter((s) => s.active);
  if (!activeSubs.length) { toast('Aucun abonnement actif à attribuer.'); return; }
  const current = userSubs.filter((u) => u.status === 'active');

  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  const currentHtml = current.length
    ? current.map((u) => `<div class="kv" style="margin-bottom:8px"><span>${esc(u.subscription_name || ('Abonnement #' + u.subscriptions_id))}</span><span><button class="btn del" data-revoke="${u.id}" style="margin:0">Retirer</button></span></div>`).join('')
    : `<p style="color:var(--muted);font-size:13px;margin:6px 0 16px">Aucun abonnement actif pour l'instant.</p>`;
  bg.innerHTML = `<div class="modal">
    <h3>Gérer l'abonnement</h3>
    <label>Actuellement</label>
    ${currentHtml}
    <label>Attribuer / rétrograder vers</label>
    <select id="gs-sub">${activeSubs.map((s) => `<option value="${esc(s.id)}">${esc(s.name)} (${esc(s.tier)}) — $${esc(s.price)}</option>`).join('')}</select>
    <div class="modal-actions"><button class="cancel">Annuler</button><button class="btn gold save">${current.length ? 'Changer de palier' : 'Attribuer'}</button></div>
  </div>`;
  document.body.appendChild(bg);
  bg.querySelector('.cancel').onclick = () => bg.remove();
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  bg.querySelectorAll('[data-revoke]').forEach((btn) => btn.onclick = async () => {
    if (!confirm('Retirer cet abonnement ?')) return;
    try { await api('DELETE', '/user-subscriptions/' + btn.dataset.revoke); toast('Abonnement retiré'); bg.remove(); route(); }
    catch (e) { toast(e.message); }
  });
  bg.querySelector('.save').onclick = async () => {
    const subId = bg.querySelector('#gs-sub').value;
    try {
      for (const u of current) { await api('DELETE', '/user-subscriptions/' + u.id); }
      await api('POST', '/user-subscriptions', { user_id: userId, subscriptions_id: subId, status: 'active' });
      toast('Abonnement mis à jour');
      bg.remove();
      route();
    } catch (e) { toast(e.message); }
  };
}
function pageSubscriptions() {
  EDIT.sub = (id) => { const r = currentRows.find((x) => x.id == id); if (r) subForm(r); };
  DUP.sub = (id) => { const r = currentRows.find((x) => x.id == id); if (r) subForm(r, { duplicate: true }); };
  listPage({
    title: 'Abonnements', endpoint: '/subscriptions', addLabel: '+ Ajouter', onAdd: () => subForm(null), columns: [
      { label: '#', render: (r) => r.id },
      { label: 'Nom', render: (r) => esc(r.name) },
      { label: 'Palier', render: (r) => esc(r.tier) },
      { label: 'Prix', render: (r) => '$' + esc(r.price) },
      { label: 'Période', render: (r) => esc(r.period === 'year' ? 'an' : 'mois') },
      { label: 'Stripe', render: (r) => r.stripe_price_id ? '<span class="badge active">💳 lié</span>' : '<span class="badge pending">non lié</span>' },
      { label: 'IAP', render: (r) => r.revenuecat_product_id ? '<span class="badge active">📱 lié</span>' : '<span class="badge pending">non lié</span>' },
      { label: 'Actif', render: (r) => badge(r.active ? 'active' : 'pending') },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="sub:${r.id}">Modifier</button><button class="btn dup" data-dup="sub:${r.id}">Dupliquer</button><button class="btn del" data-del="/subscriptions/${r.id}">Supprimer</button>` },
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

// Support — les tickets écrits depuis l'application. Avant, ces messages
// étaient acceptés par l'API puis jetés : personne ne les voyait.
async function pageSupport() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/support');
  if (!data.length) {
    view().innerHTML = '<div class="tcard"><h3 style="color:var(--gold);margin-bottom:10px">🎧 Support</h3><div class="empty">Aucun ticket pour le moment.</div></div>';
    return;
  }
  const bubble = (m) => `<div style="margin:8px 0;padding:10px 12px;border-radius:10px;max-width:80%;${m.role === 'admin'
      ? 'background:var(--gold);color:var(--navy);margin-left:auto'
      : 'background:var(--navy-2);border:1px solid var(--line)'}">
      <div style="font-size:11px;opacity:.7;margin-bottom:4px">${m.role === 'admin' ? 'VybzzZ' : 'Utilisateur'} · ${fmtDate(m.created_at)}</div>
      ${esc(m.value || '')}</div>`;

  view().innerHTML = `<div class="tcard">
    <h3 style="color:var(--gold);margin-bottom:4px">🎧 Support — tickets envoyés depuis l'application</h3>
    <div class="empty" style="text-align:left;padding:0 0 14px">${data.filter((t) => t.status === 'open').length} ticket(s) ouvert(s) sur ${data.length}.</div>
    ${data.map((t) => `<details style="border:1px solid var(--line);border-radius:10px;margin-bottom:10px;padding:12px" ${t.status === 'open' ? 'open' : ''}>
      <summary style="cursor:pointer;font-weight:600">
        #${t.id} · ${esc(t.subject || 'Sans objet')} — ${esc(t.user_name || 'Utilisateur')} <span style="opacity:.6">${esc(t.user_email || '')}</span>
        ${t.status === 'open' ? '<span style="color:var(--gold)"> · ouvert</span>' : ' · résolu'}
      </summary>
      <div style="margin-top:10px">${(t.messages || []).map(bubble).join('') || '<div class="empty">Aucun message.</div>'}</div>
      <div style="display:flex;gap:8px;margin-top:10px;flex-wrap:wrap">
        <input class="sup-txt" data-id="${t.id}" placeholder="Répondre à ${esc(t.user_name || 'cet utilisateur')}…"
               style="flex:1;min-width:220px;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:9px 11px">
        <button class="btn sup-send" data-id="${t.id}">Envoyer</button>
        <button class="btn sup-st" data-id="${t.id}" data-st="${t.status === 'open' ? 'resolved' : 'open'}">${t.status === 'open' ? 'Marquer résolu' : 'Rouvrir'}</button>
      </div>
    </details>`).join('')}
  </div>`;

  view().addEventListener('click', async (e) => {
    const send = e.target.closest('.sup-send');
    if (send) {
      const box = view().querySelector(`.sup-txt[data-id="${send.dataset.id}"]`);
      const value = (box?.value || '').trim();
      if (!value) return toast('Écris une réponse.');
      await api('POST', `/support/${send.dataset.id}/reply`, { value });
      toast('Réponse envoyée'); pageSupport();
      return;
    }
    const st = e.target.closest('.sup-st');
    if (st) {
      await api('POST', `/support/${st.dataset.id}/status`, { status: st.dataset.st });
      toast('Statut mis à jour'); pageSupport();
    }
  });
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

// Candidatures artiste ("Devenir artiste" sur le site) : un seul écran pour
// tout faire — voir le statut, choisir l'abonnement à attribuer et
// approuver. Si le candidat a déjà un compte, l'abonnement s'active tout de
// suite ; sinon il s'activera tout seul dès qu'il s'inscrit avec ce même
// email (voir POST /admin/contact-leads/:id/approve côté backend).
async function pageLeads() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const [{ data }, { data: subs }] = await Promise.all([api('GET', '/contact-leads'), api('GET', '/subscriptions')]);
  currentRows = data;
  const activeSubs = subs.filter((s) => s.active);
  const subName = (id) => activeSubs.find((s) => s.id == id)?.name || subs.find((s) => s.id == id)?.name;
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Nom', render: (r) => esc(r.name) },
    { label: 'Email', render: (r) => esc(r.email) },
    { label: 'Téléphone', render: (r) => esc(r.phone || '—') },
    { label: 'Message', render: (r) => esc(r.message || '') },
    { label: 'Statut', render: (r) => badge(r.status) + (r.approved_subscription_id ? `<div class="em">${esc(subName(r.approved_subscription_id) || '—')}</div>` : '') },
    { label: 'Signature', render: (r) => r.signature_data
      ? `<img src="${r.signature_data}" alt="signature" title="Contrat signé${r.signed_at ? ' le ' + new Date(r.signed_at).toLocaleDateString('fr-FR') : ''}" onclick="window.open(this.src,'_blank')" style="height:34px;max-width:130px;background:#fff;border:1px solid var(--line);border-radius:6px;cursor:zoom-in;object-fit:contain">`
      : '<span class="em">—</span>' },
    { label: 'Date', render: (r) => fmtDate(r.created_at) },
    {
      label: 'Action', render: (r) => {
        if (r.status === 'pending' || !r.status) {
          return activeSubs.length
            ? `<select class="lead-sub" data-subfor="${r.id}" style="background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:7px;padding:6px;margin-right:6px">${activeSubs.map((s) => `<option value="${esc(s.id)}">${esc(s.name)} (${esc(s.tier)})</option>`).join('')}</select><button class="btn status" data-approvelead="${r.id}">✓ Approuver</button><button class="btn del" data-rejectlead="${r.id}">Refuser</button>`
            : `<span class="em">Crée d'abord un abonnement</span>`;
        }
        return `<button class="btn del" data-del="/contact-leads/${r.id}">Supprimer</button>`;
      },
    },
  ];
  view().innerHTML = tableShell('Candidatures artiste', cols);
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data });
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


// ─── Audience du site : mesure maison, sans cookie ni donnée personnelle ───
async function pageAudience() {
  const days = +(location.hash.split('?days=')[1] || 7);
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/analytics?days=' + days);
  const LABELS = {
    pageview: 'Vues de page', cta_apply: 'Clic « Postuler »', cta_challenge: 'Clic « Challenge »',
    challenge_signup: 'Inscription au Challenge', fan_join: 'Fan pré-inscrit via un lien',
    store_click: 'Clic App Store / Google Play', whatsapp_click: 'Clic WhatsApp',
    contact_lead: 'Formulaire « Réserve ton moment »', artist_apply: 'Candidature artiste envoyée',
    share_link: 'Lien de Challenge partagé', app_page: 'Page de téléchargement', feed_view: 'Feed consulté',
  };
  const maxDay = Math.max(1, ...data.byDay.map((d) => d.visiteurs));
  const bars = data.byDay.map((d) => `<div style="flex:1;max-width:60px;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:6px">
      <div title="${d.visiteurs} visiteurs · ${d.vues} vues" style="width:70%;min-height:2px;height:${Math.round(d.visiteurs / maxDay * 110)}px;background:linear-gradient(180deg,var(--gold),#7A1F33);border-radius:4px 4px 0 0"></div>
      <span class="em" style="font-size:10px">${esc(d.day.slice(8))}/${esc(d.day.slice(5, 7))}</span>
    </div>`).join('');
  const kpi = (l, v, s) => `<div class="tcard" style="padding:14px"><div class="em">${l}</div>
      <div style="font-size:26px;color:var(--gold);font-weight:700;line-height:1.2">${v}</div>${s ? `<div class="em">${s}</div>` : ''}</div>`;
  const list = (rows, key, val, extra) => rows.length
    ? `<table class="tbl">${rows.map((r) => `<tr><td>${extra ? extra(r) : ''}${esc(String(r[key] ?? '—'))}</td><td style="text-align:right;color:var(--gold)">${r[val]}</td></tr>`).join('')}</table>`
    : '<div class="empty">Aucune donnée</div>';
  const maxF = Math.max(1, ...data.funnel.map((f) => f.n));
  let mail = null;
  try { mail = (await api('GET', '/email-health')).data; } catch (e) { /* non bloquant */ }
  const alerte = mail && (mail.bacASable || (mail.dernieres24h && mail.dernieres24h.echecs > 0) || !mail.configure)
    ? `<div class="tcard" style="border-color:#7A1F33;background:rgba(122,31,51,.18);margin-bottom:16px">
        <h3 style="margin:0 0 6px;color:#ffb3b3">⚠️ Les codes de vérification n'arrivent pas</h3>
        <div class="em" style="line-height:1.6">
          ${!mail.configure ? "Aucune clé d'envoi d'e-mail n'est configurée : les comptes reçoivent le code de démonstration 1234.<br>" : ''}
          ${mail.bacASable ? `Expéditeur actuel : <b>${esc(mail.expediteur)}</b>. C'est l'adresse bac à sable de Resend :
             elle n'autorise l'envoi qu'à l'adresse du propriétaire du compte Resend. <b>Tous les autres inscrits ne reçoivent rien.</b>
             Corriger : vérifier le domaine vybzzz.online dans Resend, puis définir
             <code>EMAIL_FROM="VybzzZ &lt;no-reply@vybzzz.online&gt;"</code> dans /opt/vybzzz/.vybzzz.env et relancer le conteneur.<br>` : ''}
          ${mail.dernieres24h ? `Dernières 24 h : ${mail.dernieres24h.total || 0} tentative(s), <b>${mail.dernieres24h.echecs || 0} échec(s)</b>.` : ''}
        </div>
        ${(mail.journal || []).filter((l) => !l.ok).length ? `<table class="tbl" style="margin-top:12px;font-size:12px"><thead><tr><th>Destinataire</th><th>Erreur</th><th>Quand</th></tr></thead><tbody>
          ${(mail.journal || []).filter((l) => !l.ok).slice(0, 6).map((l) => `<tr><td>${esc(l.recipient)}</td><td style="color:#ffb3b3">${esc(l.error)}</td><td class="em">${esc(l.created_at)}</td></tr>`).join('')}
        </tbody></table>` : ''}
      </div>` : '';
  view().innerHTML = `<h1 class="page-title">Audience du site</h1>${alerte}
    <div class="em" style="margin-bottom:12px">Sans cookie, sans donnée personnelle : aucun bandeau de consentement n'est nécessaire.
      ${[[1, "Aujourd'hui"], [7, '7 jours'], [30, '30 jours'], [90, '90 jours']].map(([d, l]) => `<a href="#audience?days=${d}" style="margin-left:10px;${d === days ? 'color:var(--gold);font-weight:700' : ''}">${l}</a>`).join('')}</div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px;margin-bottom:16px">
      ${kpi('Visiteurs uniques', data.totals.visiteurs, `sur ${data.jours} jours`)}
      ${kpi('Vues de page', data.totals.vues, data.totals.visiteurs ? (data.totals.vues / data.totals.visiteurs).toFixed(1) + ' pages par visiteur' : '')}
      ${kpi('Inscriptions Challenge', (data.actions.find((a) => a.name === 'challenge_signup') || {}).visiteurs || 0, 'artistes')}
      ${kpi('Fans pré-inscrits', (data.actions.find((a) => a.name === 'fan_join') || {}).visiteurs || 0, 'via un lien d\'artiste')}
    </div>
    <div class="tcard" style="margin-bottom:16px"><h3 style="margin:0 0 12px">Visiteurs par jour</h3>
      <div style="display:flex;align-items:flex-end;gap:4px;height:140px">${bars || '<div class="empty">Aucune donnée</div>'}</div></div>
    ${data.byHour && data.byHour.length ? `<div class="tcard" style="margin-bottom:16px">
      <h3 style="margin:0 0 4px">Aujourd'hui, heure par heure</h3>
      <div class="em" style="margin-bottom:12px">Heure locale. Utile pour lire l'effet d'une publicité lancée dans la journée.</div>
      <div style="display:flex;align-items:flex-end;gap:3px;height:110px">
        ${(() => { const mx = Math.max(1, ...data.byHour.map((h) => h.visiteurs));
          return Array.from({ length: 24 }, (_, i) => { const k = String(i).padStart(2, '0');
            const r = data.byHour.find((x) => x.h === k) || { visiteurs: 0, vues: 0 };
            return `<div style="flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:5px">
              <div title="${k}h : ${r.visiteurs} visiteurs, ${r.vues} vues" style="width:76%;min-height:2px;height:${Math.round(r.visiteurs / mx * 84)}px;background:${r.visiteurs ? 'linear-gradient(180deg,var(--gold),#7A1F33)' : 'var(--navy-2)'};border-radius:3px 3px 0 0"></div>
              <span class="em" style="font-size:9px">${i % 3 === 0 ? k : ''}</span></div>`; }).join(''); })()}
      </div></div>` : ''}
    <div class="tcard" style="margin-bottom:16px">
      <h3 style="margin:0 0 4px">Conversions par source</h3>
      <div class="em" style="margin-bottom:12px">Chaque visiteur est rattaché à la source par laquelle il est arrivé, même s'il s'inscrit plusieurs pages plus loin.
        Conversion = inscription au Challenge, candidature artiste, fan pré-inscrit, formulaire de contact ou clic vers un store.</div>
      ${data.bySource && data.bySource.length ? `<table class="tbl"><thead><tr><th>Source</th><th style="text-align:right">Visiteurs</th><th style="text-align:right">Conversions</th><th style="text-align:right">Taux</th></tr></thead><tbody>
        ${data.bySource.map((r) => `<tr><td>${esc(r.source)}</td><td style="text-align:right">${r.visiteurs}</td>
          <td style="text-align:right;color:var(--gold)">${r.conversions}</td>
          <td style="text-align:right;${r.taux >= 2 ? 'color:var(--gold);font-weight:700' : 'color:var(--muted)'}">${r.taux} %</td></tr>`).join('')}
      </tbody></table>` : '<div class="empty">Aucune donnée</div>'}
    </div>
    <div class="tcard" style="margin-bottom:16px"><h3 style="margin:0 0 4px">Tunnel du Live Challenge</h3>
      <div class="em" style="margin-bottom:12px">En visiteurs distincts, sur la période.</div>
      ${data.funnel.map((f) => `<div style="margin-bottom:10px"><div style="display:flex;justify-content:space-between;font-size:13px"><span>${esc(f.etape)}</span><b style="color:var(--gold)">${f.n}</b></div>
        <div style="height:8px;border-radius:99px;background:var(--navy-2);overflow:hidden;margin-top:4px"><i style="display:block;height:100%;width:${Math.round(f.n / maxF * 100)}%;background:linear-gradient(90deg,#7A1F33,var(--gold))"></i></div></div>`).join('')}</div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px">
      <div class="tcard"><h3 style="margin:0 0 10px">D'où viennent les visiteurs</h3>${list(data.refs, 'source', 'visiteurs')}</div>
      <div class="tcard"><h3 style="margin:0 0 10px">Pages les plus vues</h3>${list(data.pages, 'path', 'vues')}</div>
      <div class="tcard"><h3 style="margin:0 0 10px">Pays</h3>${list(data.countries, 'nom', 'visiteurs', (r) => r.drapeau + ' ')}</div>
      <div class="tcard"><h3 style="margin:0 0 10px">Appareils</h3>${list(data.devices, 'device', 'visiteurs')}</div>
      <div class="tcard" style="grid-column:1/-1"><h3 style="margin:0 0 10px">Actions</h3>
        ${data.actions.length ? `<table class="tbl"><thead><tr><th>Action</th><th style="text-align:right">Visiteurs</th><th style="text-align:right">Total</th></tr></thead><tbody>
          ${data.actions.map((a) => `<tr><td>${esc(LABELS[a.name] || a.name)}</td><td style="text-align:right;color:var(--gold)">${a.visiteurs}</td><td style="text-align:right">${a.total}</td></tr>`).join('')}
        </tbody></table>` : '<div class="empty">Aucune action enregistrée pour le moment</div>'}</div>
    </div>`;
}

// ─── Boutique merch (print à la demande) : produits affichés sur vybzzz.online/store.html ───
function pageMerch() {
  const CATS = [{ value: 'textile', label: 'Textile' }, { value: 'accessoire', label: 'Accessoire' }, { value: 'print', label: 'Affiche / print' }, { value: 'autre', label: 'Autre' }];
  const fields = (r = {}) => [
    { name: 'name', label: 'Nom du produit', value: r.name },
    { name: 'description', label: 'Description', type: 'textarea', value: r.description },
    { name: 'price_eur', label: 'Prix (€)', type: 'number', value: r.price_eur },
    { name: 'category', label: 'Catégorie', type: 'select', value: r.category || 'textile', options: CATS },
    { name: 'buy_url', label: "Lien d'achat (page produit chez le fournisseur print à la demande)", value: r.buy_url, placeholder: 'https://…' },
    { name: 'image', label: 'Visuel (JPG/PNG, carré conseillé)', type: 'file' },
    { name: 'sort', label: 'Ordre', type: 'number', value: r.sort ?? 0 },
    { name: 'active', label: 'Visible sur le site', type: 'checkbox', value: !!r.active },
  ];
  EDIT.merch = (id) => {
    const r = currentRows.find((x) => x.id == id); if (!r) return;
    modal({ title: 'Modifier le produit', wide: true, fields: fields(r), onSave: async (d) => { await api('PUT', '/merch/' + id, d); toast('Produit modifié'); pageMerch(); } });
  };
  listPage({
    title: 'Boutique merch', endpoint: '/merch', addLabel: '+ Ajouter un produit',
    columns: [
      { label: '', render: (r) => r.image_url ? `<img src="${esc(r.image_url)}" style="width:52px;height:52px;object-fit:cover;border-radius:8px">` : '' },
      { label: 'Produit', render: (r) => `<b>${esc(r.name)}</b><div class="em">${esc(r.category)} · ordre ${r.sort}</div>` },
      { label: 'Prix', render: (r) => `${Number(r.price_eur).toFixed(2)} €` },
      { label: "Lien d'achat", render: (r) => r.buy_url ? `<a href="${esc(r.buy_url)}" target="_blank">ouvrir</a>` : '<span style="color:#ffb3b3">manquant</span>' },
      { label: 'Statut', render: (r) => r.active ? '<span class="badge active">Visible</span>' : '<span class="badge pending">Masqué</span>' },
      { label: 'Action', render: (r) => `<button class="btn edit" data-edit="merch:${r.id}">Modifier</button><button class="btn del" data-del="/merch/${r.id}">Supprimer</button>` },
    ],
    onAdd: (reload) => modal({ title: 'Ajouter un produit', wide: true, fields: fields(), onSave: async (d) => { await api('POST', '/merch', d); toast('Produit ajouté'); reload(); } }),
  });
  const note = document.createElement('div'); note.className = 'em'; note.style.marginTop = '10px';
  note.textContent = "Un produit n'apparaît sur le site que s'il est « Visible ». Le bouton « Commander » du site ouvre le lien d'achat : sans lien, le produit affiche « Bientôt ».";
  view().appendChild(note);
}

// ─── VybzzZ Live Challenge : inscrits, score, fans amenés, disqualification ───
async function pageChallenge() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/challenge');
  const { config, totals, list } = data;
  const fmt = (d) => d ? String(d).slice(0, 10) : '—';
  const badge = (st) => st === 'disqualified' ? '<span class="badge pending">Disqualifié</span>'
    : st === 'winner' ? '<span class="badge live">Gagnant</span>' : '<span class="badge active">Actif</span>';
  view().innerHTML = `<h1 class="page-title">Live Challenge</h1>
    <div class="em" style="margin-bottom:12px">${esc(config.name)} · du ${fmt(config.start)} au ${fmt(config.end)} · ${esc(config.organizer)} ·
      <a href="https://vybzzz.online/challenge.html" target="_blank">page publique</a></div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:16px">
      ${[['Artistes inscrits', totals.artists], ['Fans qualifiés', totals.referrals_qualified], ['Pré-inscrits (en attente)', totals.referrals_pre], ['Clics sur les liens', totals.clicks]]
        .map(([l, v]) => `<div class="tcard" style="padding:12px"><div class="em">${l}</div><div style="font-size:22px;color:var(--gold);font-weight:700">${v}</div></div>`).join('')}
    </div>
    <div class="tcard" style="overflow:auto">
      <table class="tbl"><thead><tr><th>#</th><th>Artiste</th><th>E-mail</th><th>Lien</th><th>Compte</th><th>Score</th><th>Lives</th><th>Contenus</th><th>Fans</th><th>Clics</th><th>Statut</th><th></th></tr></thead>
      <tbody>${list.map((a) => { const s = a.stats || {}; return `<tr>
        <td>${s.rank ?? '—'}</td><td><b>${esc(a.stage_name)}</b><div class="em">${esc(a.genre || '')} ${esc(a.socials || '')}</div></td>
        <td>${esc(a.email)}<div class="em">${esc(a.phone || '')}</div></td>
        <td><code style="font-size:11px">${esc(a.code)}</code> <button class="btn edit" data-copy="${esc(a.link)}">copier</button></td>
        <td>${a.user_id ? '✅ relié' : '<span style="color:#ffb3b3">non relié</span>'}</td>
        <td><b>${s.score ?? 0}</b>${s.eligible === false ? '<div class="em">pas de live</div>' : ''}</td>
        <td>${s.lives ?? 0}</td><td>${s.clips ?? 0}</td>
        <td>${s.referrals ?? 0}<div class="em">${s.pre ?? 0} en attente</div></td><td>${s.clicks ?? 0}</td>
        <td>${badge(a.status)}</td>
        <td style="white-space:nowrap">
          <button class="btn edit" data-refs="${a.id}">fans</button>
          ${a.status === 'disqualified' ? `<button class="btn status" data-st="active" data-id="${a.id}">réactiver</button>` : `<button class="btn del" data-st="disqualified" data-id="${a.id}">disqualifier</button>`}
          ${a.status === 'winner' ? '' : `<button class="btn gold" data-st="winner" data-id="${a.id}">gagnant</button>`}
        </td></tr><tr id="refs-${a.id}" hidden><td colspan="12" class="em">…</td></tr>`; }).join('') || '<tr><td colspan="12" class="empty">Aucun inscrit pour le moment.</td></tr>'}</tbody></table>
    </div>`;
  view().querySelectorAll('[data-copy]').forEach((b) => b.onclick = () => { navigator.clipboard?.writeText(b.dataset.copy); toast('Lien copié'); });
  view().querySelectorAll('[data-st]').forEach((b) => b.onclick = async () => {
    if (b.dataset.st === 'disqualified' && !confirm('Disqualifier cet artiste ? Il disparaît du classement.')) return;
    try { await api('POST', `/challenge/${b.dataset.id}/status`, { status: b.dataset.st }); toast('Statut mis à jour'); pageChallenge(); } catch (e) { toast(e.message); }
  });
  view().querySelectorAll('[data-refs]').forEach((b) => b.onclick = async () => {
    const row = view().querySelector(`#refs-${b.dataset.refs}`); row.hidden = !row.hidden; if (row.hidden) return;
    const { data: refs } = await api('GET', `/challenge/${b.dataset.refs}/referrals`);
    row.firstElementChild.innerHTML = refs.length ? `<table class="tbl" style="font-size:12px"><thead><tr><th>E-mail</th><th>Prénom</th><th>Statut</th><th>Pré-inscrit le</th><th>Qualifié le</th><th>IP</th></tr></thead><tbody>${refs.map((r) => `<tr><td>${esc(r.email)}</td><td>${esc(r.name || '')}</td><td>${r.status === 'qualified' ? '✅ qualifié' : r.status === 'existing' ? 'déjà membre (ne compte pas)' : 'en attente du compte'}</td><td>${esc(r.created_at)}</td><td>${esc(r.qualified_at || '—')}</td><td class="em">${esc(r.ip || '')}</td></tr>`).join('')}</tbody></table>` : 'Aucun fan pré-inscrit via ce lien.';
  });
}

// ─── Textes légaux (CGU, confidentialité, à propos) affichés dans l'app ───
async function pageLegal() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/legal-settings');
  const f = 'width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:11px;margin:6px 0 16px;font:inherit';
  const ta = (id, label, v, rows) => `<label style="color:var(--muted);font-size:13px">${label}</label><textarea id="${id}" rows="${rows}" style="${f}">${esc(v || '')}</textarea>`;
  view().innerHTML = `<h1 class="page-title">Textes légaux</h1>
    <div class="tcard" style="max-width:760px">
      <div class="em" style="margin-bottom:14px">Affichés dans l'app (Profil → À propos, Réglages, inscription). Texte brut, sauts de ligne conservés.
      Les versions complètes sont sur le site : <a href="https://vybzzz.online/confidentialite.html" target="_blank">confidentialité</a> · <a href="https://vybzzz.online/cgu.html" target="_blank">CGU</a>.</div>
      ${ta('lg-privacy', 'Politique de confidentialité', data.privacy_policy, 16)}
      ${ta('lg-terms', "Conditions générales d'utilisation", data.terms_and_conditions, 16)}
      ${ta('lg-about', 'À propos', data.about_us, 6)}
      <label style="color:var(--muted);font-size:13px">E-mail de support</label>
      <input id="lg-email" type="email" value="${esc(data.support_email || '')}" style="${f}">
      <button class="btn gold" id="lg-save">Enregistrer</button>
      <div class="em" style="margin-top:10px">Pris en compte immédiatement dans l'app, sans nouvelle version store.</div>
    </div>`;
  view().querySelector('#lg-save').onclick = async () => {
    try {
      await api('PUT', '/legal-settings', {
        privacy_policy: view().querySelector('#lg-privacy').value,
        terms_and_conditions: view().querySelector('#lg-terms').value,
        about_us: view().querySelector('#lg-about').value,
        support_email: view().querySelector('#lg-email').value,
      });
      toast('Textes légaux enregistrés');
    } catch (e) { toast(e.message); }
  };
}

// ─── Page de lancement (splash) : fond d'écran + animation, lus par l'app au
// démarrage (GET /api/splash-settings, public) sans nouvelle version store.
async function pageSplash() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/splash-settings');
  const styles = [
    { value: 'auto', label: '✨ Auto (change avec la saison — Halloween, fêtes, rotation)' },
    { value: 'sparkles', label: 'Paillettes dorées (par défaut)' },
    { value: 'equalizer', label: 'Égaliseur audio (barres qui dansent)' },
    { value: 'spotlights', label: 'Projecteurs de scène (faisceaux)' },
    { value: 'liquid', label: 'Dégradé liquide (façon Apple)' },
    { value: 'bokeh', label: 'Lumières de foule (bokeh flou)' },
    { value: 'halloween', label: '🎃 Halloween (braises + chauves-souris)' },
    { value: 'fade', label: 'Halo simple (sans paillettes)' },
    { value: 'none', label: 'Aucune animation' },
  ];
  const fieldStyle = 'width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:11px;margin:6px 0 6px';
  view().innerHTML = `<h1 class="page-title">Page de lancement</h1>
    <div class="tcard" style="max-width:560px">
      <label style="color:var(--muted);font-size:13px">Fond d'écran (image)</label>
      ${data.background_image ? `<div style="margin:8px 0"><img src="${esc(data.background_image)}" style="max-width:100%;border-radius:8px;max-height:200px;object-fit:cover"></div>` : ''}
      <input type="file" id="sp-image" accept="image/*" style="${fieldStyle}">
      ${data.background_image ? `<label style="display:flex;gap:8px;align-items:center;font-size:13px;color:var(--muted);margin:0 0 14px"><input type="checkbox" id="sp-image-remove" style="width:auto"> Supprimer l'image actuelle (repli sur l'asset par défaut de l'app)</label>` : '<div style="margin-bottom:14px"></div>'}

      <label style="color:var(--muted);font-size:13px">Logo emblème (image — PNG transparent conseillé)</label>
      ${data.logo_image ? `<div style="margin:8px 0;background:#0A1226;border-radius:8px;padding:10px;display:inline-block"><img src="${esc(data.logo_image)}" style="max-width:160px;max-height:160px"></div>` : ''}
      <input type="file" id="sp-logo" accept="image/*" style="${fieldStyle}">
      ${data.logo_image ? `<label style="display:flex;gap:8px;align-items:center;font-size:13px;color:var(--muted);margin:0 0 14px"><input type="checkbox" id="sp-logo-remove" style="width:auto"> Supprimer le logo actuel (repli sur le logo par défaut de l'app)</label>` : '<div style="margin-bottom:14px"></div>'}

      <label style="color:var(--muted);font-size:13px">Fond d'écran (vidéo — prioritaire sur l'image si les deux sont présentes)</label>
      ${data.background_video ? `<div style="margin:8px 0"><video src="${esc(data.background_video)}" muted loop autoplay playsinline style="max-width:100%;border-radius:8px;max-height:200px"></video></div>` : ''}
      <input type="file" id="sp-video" accept="video/*" style="${fieldStyle}">
      ${data.background_video ? `<label style="display:flex;gap:8px;align-items:center;font-size:13px;color:var(--muted);margin:0 0 14px"><input type="checkbox" id="sp-video-remove" style="width:auto"> Supprimer la vidéo actuelle</label>` : '<div style="margin-bottom:14px"></div>'}

      <label style="color:var(--muted);font-size:13px">Style d'animation</label>
      <select id="sp-style" style="${fieldStyle}margin-bottom:18px">
        ${styles.map((s) => `<option value="${s.value}" ${s.value === data.animation_style ? 'selected' : ''}>${esc(s.label)}</option>`).join('')}
      </select>

      <label style="color:var(--muted);font-size:13px">Couleur des écritures (logo texte + « LIVE CONCERTS »)</label>
      <div style="display:flex;align-items:center;gap:10px;margin:6px 0 16px">
        <input type="color" id="sp-color" value="${esc(data.text_color || '#E6C76A')}" style="width:54px;height:38px;background:transparent;border:1px solid var(--line);border-radius:8px;cursor:pointer">
        <span class="em">Choisis une couleur lisible sur ton fond (ex. blanc sur un fond clair).</span>
      </div>

      <label style="color:var(--muted);font-size:13px">Voile de contraste sur le fond : <b id="sp-ov-val" style="color:var(--gold)">${data.overlay || 0}%</b></label>
      <input type="range" id="sp-overlay" min="0" max="85" value="${data.overlay || 0}" style="width:100%;margin:8px 0 18px" oninput="document.getElementById('sp-ov-val').textContent=this.value+'%'">
      <div class="em" style="margin:-8px 0 18px">Assombrit le fond derrière le texte → lisible sur n'importe quelle image.</div>

      <button class="btn gold" id="sp-save">Enregistrer</button>
      <div class="em" style="margin-top:10px">Pris en compte au prochain lancement de l'app — pas besoin de nouvelle version App Store/Play Store.</div>
    </div>`;

  view().querySelector('#sp-save').onclick = async () => {
    const fd = new FormData();
    const imageFile = view().querySelector('#sp-image').files[0];
    const videoFile = view().querySelector('#sp-video').files[0];
    const logoFile = view().querySelector('#sp-logo').files[0];
    if (imageFile) fd.append('background_image', imageFile);
    if (videoFile) fd.append('background_video', videoFile);
    if (logoFile) fd.append('logo_image', logoFile);
    if (view().querySelector('#sp-image-remove')?.checked) fd.append('remove_background_image', '1');
    if (view().querySelector('#sp-video-remove')?.checked) fd.append('remove_background_video', '1');
    if (view().querySelector('#sp-logo-remove')?.checked) fd.append('remove_logo_image', '1');
    fd.append('animation_style', view().querySelector('#sp-style').value);
    fd.append('text_color', view().querySelector('#sp-color').value);
    fd.append('overlay', view().querySelector('#sp-overlay').value);
    try {
      await api('PUT', '/splash-settings', fd);
      toast('Page de lancement mise à jour');
      pageSplash();
    } catch (e) { toast(e.message); }
  };
}

// Délégation globale Supprimer / Modifier / Statut
document.addEventListener('click', (e) => {
  const del = e.target.closest('[data-del]');
  if (del) { confirmDelete(async () => { await api('DELETE', del.dataset.del); toast('Supprimé'); route(); }); return; }
  const ed = e.target.closest('[data-edit]');
  if (ed) { const [type, id] = ed.dataset.edit.split(':'); EDIT[type]?.(id); return; }
  const dup = e.target.closest('[data-dup]');
  if (dup) { const [type, id] = dup.dataset.dup.split(':'); DUP[type]?.(id); return; }
  const gs = e.target.closest('[data-grantsub]');
  if (gs) { openGrantSubModal(gs.dataset.grantsub); return; }
  const ac = e.target.closest('[data-approveclip]');
  if (ac) { api('POST', `/feed-clips/${ac.dataset.approveclip}/approve`).then(() => { toast('Clip approuvé'); route(); }).catch((err) => toast(err.message)); return; }
  const al = e.target.closest('[data-approvelead]');
  if (al) {
    const sel = document.querySelector(`.lead-sub[data-subfor="${al.dataset.approvelead}"]`);
    const subscriptions_id = sel?.value;
    api('POST', `/contact-leads/${al.dataset.approvelead}/approve`, { subscriptions_id })
      .then((r) => { toast(r.message || 'Candidature approuvée'); route(); }).catch((err) => toast(err.message));
    return;
  }
  const rl = e.target.closest('[data-rejectlead]');
  if (rl) {
    api('POST', `/contact-leads/${rl.dataset.rejectlead}/reject`)
      .then(() => { toast('Candidature refusée'); route(); }).catch((err) => toast(err.message));
    return;
  }
  const mu = e.target.closest('[data-muxupload]');
  if (mu) { const [kind, id] = mu.dataset.muxupload.split(':'); openMuxUploadDialog(kind, id); return; }
  const ml = e.target.closest('[data-muxlive]');
  if (ml) { const [, id, hasLive] = ml.dataset.muxlive.split(':'); toggleMuxLiveStream(id, hasLive === '1'); return; }
  const st = e.target.closest('[data-status]');
  if (st) {
    const r = currentRows.find((x) => x.id == st.dataset.status);
    const next = r?.status === 'active' ? 'pending' : 'active';
    api('POST', `/users/${st.dataset.status}/status`, { status: next })
      .then(() => { toast('Statut → ' + (STATUS_FR[next] || next)); route(); }).catch((err) => toast(err.message));
  }
});

// ─── Supervision des lives en direct (modération) ───
let livesTimer = null;
async function renderLives() {
  let rows = [];
  try { const r = await api('GET', '/live-events'); rows = r.data || []; }
  catch (e) { view().innerHTML = `<div style="padding:16px;color:#c88">Erreur : ${esc(e.message)}</div>`; return; }
  const head = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
      <h2 style="margin:0">🔴 Lives en direct</h2>
      <span class="em">Supervision — actualisé toutes les 15 s</span></div>`;
  if (!rows.length) {
    view().innerHTML = head + `<div style="padding:28px;text-align:center;color:#888;border:1px dashed #334;border-radius:12px">Aucun concert en direct actuellement.</div>`;
    return;
  }
  const cards = rows.map((r) => {
    const canWatch = !!r.mux_live_playback_id;
    const watch = canWatch
      ? `<button class="btn edit" data-watchlive="${r.id}">▶ Regarder</button>`
      : `<span class="em" style="color:#c9a24b">⚠️ Flux vidéo indisponible (relais Zego→Mux à activer)</span>`;
    return `<div style="padding:14px;margin-bottom:10px;border:1px solid #22314a;border-radius:12px;background:#0d1626">
      <div class="nm" style="font-size:16px">🔴 ${esc(r.name || '—')}</div>
      <div class="em">🎤 ${esc(r.artist || r.artist_email || '—')} · 👥 ${r.buyers || 0} billets · ❤️ ${r.likes_count || 0}</div>
      <div class="em">En direct depuis ${fmtDate(r.start_date_time)}</div>
      <div style="margin-top:8px">${watch}</div>
    </div>`;
  }).join('');
  view().innerHTML = head + cards;
  view().querySelectorAll('[data-watchlive]').forEach((b) => {
    b.onclick = () => { const r = rows.find((x) => x.id == b.dataset.watchlive); if (r) openLivePlayer(r); };
  });
}
async function pageLives() {
  if (livesTimer) { clearInterval(livesTimer); livesTimer = null; }
  await renderLives();
  livesTimer = setInterval(() => {
    if (location.hash.replace('#', '') !== 'lives') { clearInterval(livesTimer); livesTimer = null; return; }
    renderLives();
  }, 15000);
}
function openLivePlayer(row) {
  const url = `https://stream.mux.com/${row.mux_live_playback_id}.m3u8`;
  const bg = document.createElement('div');
  bg.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.85);display:flex;align-items:center;justify-content:center;z-index:1000';
  bg.innerHTML = `<div style="background:#0b1220;padding:16px;border-radius:12px;max-width:900px;width:92%">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
        <div style="color:#fff;font-weight:700">🔴 ${esc(row.name || '')} — ${esc(row.artist || '')}</div>
        <button class="btn del" data-close>Fermer</button></div>
      <video controls autoplay playsinline style="width:100%;border-radius:8px;background:#000;max-height:70vh"></video>
    </div>`;
  document.body.appendChild(bg);
  const video = bg.querySelector('video');
  playHls(video, url);
  const close = () => { try { video.pause(); video.removeAttribute('src'); video.load(); } catch (_) {} bg.remove(); };
  bg.querySelector('[data-close]').onclick = close;
  bg.onclick = (e) => { if (e.target === bg) close(); };
}
// Lit un flux HLS : natif (Safari) sinon hls.js chargé à la volée (Chrome…).
function playHls(video, url) {
  if (video.canPlayType('application/vnd.apple.mpegurl')) { video.src = url; return; }
  if (window.Hls) { const h = new Hls(); h.loadSource(url); h.attachMedia(video); return; }
  const s = document.createElement('script');
  s.src = 'https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js';
  s.onload = () => { if (window.Hls) { const h = new Hls(); h.loadSource(url); h.attachMedia(video); } };
  document.head.appendChild(s);
}

// ─── Apporteurs / Agences (imprésarios, managers) — voir backend/APPORTEURS.md ───
function dealLabel(a) {
  const p = a.deal_params || {};
  if (a.deal_type === 'paliers') return `jauge ${p.floor ?? 5}→${p.cap ?? 15}%`;
  return `${p.rate ?? '?'}% fixe${a.deal_type === 'fixe_primes' ? ' + primes' : ''}`;
}

async function pageApporteurs() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { list } = await api('GET', '/apporteurs');
  const columns = [
    { label: '#', render: (r) => r.id },
    { label: 'Agence / Apporteur', render: (r) => `<div class="uinfo"><div><div class="nm">${esc(r.structure || r.name)}</div><div class="em">${r.structure ? esc(r.name) + ' · ' : ''}${esc(r.email || '')}</div></div></div>` },
    { label: 'Deal', render: (r) => esc(dealLabel(r)) },
    { label: 'Artistes', render: (r) => r.artists_count },
    { label: 'Dû', render: (r) => `${(+r.due_total || 0).toFixed(2)} €` },
    { label: 'Statut', render: (r) => badge(r.status) },
    { label: 'Action', render: (r) => `<button class="btn edit" data-apview="${r.id}">Voir l'agence</button>` },
  ];
  view().innerHTML = tableShell('Apporteurs / Agences', columns, '<button class="add-btn" id="addap">+ Créer un apporteur</button>');
  mountTable(view().querySelector('.tcard'), { columns, rows: list });
  view().querySelector('#addap').onclick = () => openApporteurModal(null);
  view().querySelectorAll('[data-apview]').forEach((b) => b.onclick = () => renderApporteurDetail(+b.dataset.apview));
}

async function renderApporteurDetail(id) {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const { data } = await api('GET', '/apporteurs/' + id);
  const a = data.apporteur, c = data.commissions;
  const bt = data.bonuses_totals || { due: 0, exigible: 0, payee: 0 };
  const stat = (label, val, color) => `<div style="flex:1;min-width:140px;background:var(--card-2);border:1px solid var(--line);border-radius:12px;padding:16px"><div style="color:var(--muted);font-size:11px;letter-spacing:1px;text-transform:uppercase">${label}</div><div style="color:${color};font-size:24px;font-weight:700;margin-top:6px">${(+val || 0).toFixed(2)} €</div></div>`;
  const cols = [
    { label: '#', render: (r) => r.id },
    { label: 'Artiste', render: (r) => esc(r.artist_name || r.full_name || ('#' + r.id)) },
    { label: 'Régime', render: (r) => `<select data-regime="${r.id}" style="background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:7px;padding:5px">${['normal', 'pionnier', 'fondateur', 'parrain'].map((x) => `<option ${r.artist_regime === x ? 'selected' : ''}>${x}</option>`).join('')}</select>` },
    { label: 'Abo offert jusqu\'au', render: (r) => fmtDate(r.sub_free_until) },
    { label: 'Fin commission', render: (r) => fmtDate(r.commission_end) },
    { label: 'Action', render: (r) => `<button class="btn edit" data-stmt="${r.id}">🧾 Relevé</button> <button class="btn status" data-fondateur="${r.id}" title="Prime Fondateur (3e mensualité encaissée)">💶 Fondateur</button> <button class="btn del" data-detach="${r.id}">Détacher</button>` },
  ];
  view().innerHTML = `
    <div class="head-row"><h1 class="page-title">🏢 ${esc(a.structure || a.name)}</h1>
      <div><button class="add-btn" id="apstmt" style="margin-right:8px">🧾 Relevé du mois</button><button class="add-btn" id="apedit" style="margin-right:8px">Modifier le deal</button><button class="add-btn" id="apback">← Retour</button></div></div>
    <p style="color:var(--muted);margin:0 0 16px">${esc(a.name)}${a.email ? ' · ' + esc(a.email) : ''} — Deal : <b style="color:var(--ivory)">${esc(dealLabel(a))}</b> &nbsp;${badge(a.status)}</p>
    <div style="background:var(--card-2);border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin-bottom:18px;display:flex;flex-wrap:wrap;gap:14px;align-items:center">
      <div><div style="color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:1px">Code de parrainage</div>
        <div style="font-size:22px;font-weight:800;color:var(--gold);letter-spacing:1px">${esc(a.code || '—')}</div></div>
      <div style="flex:1;min-width:220px"><div style="color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:1px">Lien à partager (l'artiste valide → rattaché + 3 mois offerts)</div>
        <input readonly value="${esc(location.origin + '/rejoindre?code=' + (a.code || ''))}" onclick="this.select()" style="width:100%;background:var(--navy-2);border:1px solid var(--line);color:var(--ivory);border-radius:8px;padding:8px;margin-top:4px"></div>
      <button class="btn status" id="apcopy">📋 Copier le lien</button>
      <button class="btn edit" id="apregen">Régénérer</button>
    </div>
    <div style="color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px">Commission récurrente (5% part nette)</div>
    <div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px">${stat('Dû (calculé)', c.due, 'var(--gold)')}${stat('Exigible (facturé)', c.exigible, 'var(--amber)')}${stat('Payé', c.payee, 'var(--green)')}</div>
    <div style="color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px">Primes de signature (Pionnier 150€ / Fondateur 300€)</div>
    <div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:20px">${stat('Dû', bt.due, 'var(--gold)')}${stat('Exigible', bt.exigible, 'var(--amber)')}${stat('Payé', bt.payee, 'var(--green)')}</div>
    <div class="head-row" style="margin-bottom:10px"><h2 style="font-size:17px;margin:0">Artistes rattachés (${data.artists.length})</h2><button class="add-btn" id="apattach">+ Rattacher un artiste</button></div>
    ${tableShellInner(cols)}`;
  mountTable(view().querySelector('.tcard'), { columns: cols, rows: data.artists });
  view().querySelector('#apback').onclick = () => pageApporteurs();
  view().querySelector('#apedit').onclick = () => openApporteurModal(a);
  view().querySelector('#apattach').onclick = () => openAttachArtist(a.id);
  view().querySelectorAll('[data-detach]').forEach((b) => b.onclick = async () => {
    if (!confirm('Détacher cet artiste ? Il reste sur la plateforme, seule la commission s\'arrête.')) return;
    try { await api('POST', '/apporteurs/detach-artist', { artist_id: +b.dataset.detach }); toast('Artiste détaché'); renderApporteurDetail(id); } catch (e) { toast(e.message); }
  });
  view().querySelector('#apstmt').onclick = () => showApporteurStatement(id);
  view().querySelectorAll('[data-stmt]').forEach((b) => b.onclick = () => showArtistStatement(b.dataset.stmt));
  view().querySelector('#apcopy').onclick = () => { navigator.clipboard.writeText(location.origin + '/rejoindre?code=' + (a.code || '')); toast('Lien copié'); };
  view().querySelector('#apregen').onclick = async () => {
    if (!confirm('Régénérer le code ? L\'ancien lien ne fonctionnera plus.')) return;
    try { await api('POST', '/apporteurs/' + id + '/regenerate-code'); toast('Code régénéré'); renderApporteurDetail(id); } catch (e) { toast(e.message); }
  };
  view().querySelectorAll('[data-regime]').forEach((s) => s.onchange = async () => {
    try { await api('POST', '/artist/' + s.dataset.regime + '/regime', { regime: s.value }); toast('Régime mis à jour'); } catch (e) { toast(e.message); }
  });
  view().querySelectorAll('[data-fondateur]').forEach((b) => b.onclick = async () => {
    if (!confirm('Enregistrer la prime Fondateur (300€) pour cet artiste ? (3e mensualité encaissée)')) return;
    try { await api('POST', '/apporteurs/artist/' + b.dataset.fondateur + '/prime-fondateur'); toast('Prime Fondateur enregistrée'); renderApporteurDetail(id); } catch (e) { toast(e.message); }
  });
}

function openApporteurModal(a) {
  const p = (a && a.deal_params) || {};
  modal({
    title: a ? 'Modifier l\'apporteur' : 'Créer un apporteur', wide: true,
    fields: [
      { name: 'name', label: 'Nom (personne)', value: a?.name || '', placeholder: 'Ruddy Séverin' },
      { name: 'structure', label: 'Structure / agence', value: a?.structure || '', placeholder: 'Alizés Records' },
      { name: 'email', label: 'Email', value: a?.email || '' },
      { name: 'deal_type', label: 'Type de deal', type: 'select', value: a?.deal_type || 'simple', options: [
        { value: 'simple', label: 'Taux fixe' },
        { value: 'paliers', label: 'Jauge (paliers selon nb d\'artistes)' },
        { value: 'fixe_primes', label: 'Taux fixe + primes' },
      ] },
      { name: 'rate', label: 'Taux fixe (%) — si « taux fixe » (Amandine : 5)', type: 'number', value: p.rate ?? 15 },
      { name: 'floor', label: 'Jauge : plancher (%)', type: 'number', value: p.floor ?? 5 },
      { name: 'cap', label: 'Jauge : plafond (%)', type: 'number', value: p.cap ?? 15 },
      { name: 'commission_months', label: 'Durée commission (mois) — Amandine : 24', type: 'number', value: p.commission_months ?? 12 },
      { name: 'commission_from', label: 'Commission à compter de…', type: 'select', value: p.commission_from || 'attach', options: [
        { value: 'attach', label: 'Rattachement' },
        { value: 'first_live', label: 'Premier live (contrat Amandine)' },
      ] },
      { name: 'prime_pionnier', label: 'Prime Pionnier (€, au 1er live) — Amandine : 150', type: 'number', value: p.primes?.pionnier?.amount ?? '' },
      { name: 'prime_fondateur', label: 'Prime Fondateur (€, 3e mensualité) — Amandine : 300', type: 'number', value: p.primes?.fondateur?.amount ?? '' },
      { name: 'exclusivity_months', label: 'Exclusivité par contact (mois) — Amandine : 6', type: 'number', value: p.exclusivity_months ?? '' },
      { name: 'prospection_indemnity', label: 'Indemnité prospection (€ forfait) — Amandine : 300', type: 'number', value: p.prospection_indemnity ?? '' },
      { name: 'status', label: 'Statut', type: 'select', value: a?.status || 'active', options: [
        { value: 'active', label: 'Actif' }, { value: 'suspended', label: 'Suspendu' },
      ] },
    ],
    onSave: async (d) => {
      const rate = +d.rate || 0, floor = +d.floor || 0, cap = +d.cap || 0;
      const deal_params = d.deal_type === 'paliers'
        ? { metric: 'artists_count', floor, cap, tiers: [{ min: 1, rate: floor }, { min: 5, rate: Math.round((floor + cap) / 2) }, { min: 10, rate: cap }] }
        : { rate };
      if (+d.commission_months > 0) deal_params.commission_months = +d.commission_months;
      if (d.commission_from) deal_params.commission_from = d.commission_from;
      const pio = +d.prime_pionnier, fon = +d.prime_fondateur;
      if (pio > 0 || fon > 0) {
        deal_params.primes = {};
        if (pio > 0) deal_params.primes.pionnier = { amount: pio, trigger: 'first_live' };
        if (fon > 0) deal_params.primes.fondateur = { amount: fon, trigger: 'third_payment' };
      }
      if (+d.exclusivity_months > 0) deal_params.exclusivity_months = +d.exclusivity_months;
      if (+d.prospection_indemnity > 0) deal_params.prospection_indemnity = +d.prospection_indemnity;
      const body = { name: d.name, structure: d.structure, email: d.email, deal_type: d.deal_type, deal_params, status: d.status };
      if (a) { await api('POST', '/apporteurs/' + a.id + '/update', body); toast('Apporteur modifié'); renderApporteurDetail(a.id); }
      else { await api('POST', '/apporteurs', body); toast('Apporteur créé'); pageApporteurs(); }
    },
  });
}

async function openAttachArtist(apId) {
  let artists = [];
  try { const { data } = await api('GET', '/users?type='); artists = (data || []).filter((u) => u.is_artist || u.artist_name); } catch (_) { artists = []; }
  modal({
    title: 'Rattacher un artiste', wide: true,
    fields: [
      artists.length
        ? { name: 'artist_id', label: 'Artiste', type: 'select', options: artists.map((u) => ({ value: u.id, label: (u.artist_name || u.full_name || ('#' + u.id)) + ' · #' + u.id })) }
        : { name: 'artist_id', label: 'ID de l\'artiste (voir Utilisateurs)', type: 'number', value: '' },
      { name: 'free_months', label: 'Mois d\'abonnement offert', type: 'number', value: 3 },
      { name: 'commission_months', label: 'Durée de commission (mois)', type: 'number', value: 12 },
    ],
    onSave: async (d) => { await api('POST', '/apporteurs/' + apId + '/attach-artist', d); toast('Artiste rattaché'); renderApporteurDetail(apId); },
  });
}

// ─── Relevés mensuels (transparence redistribution) — fenêtre imprimable ───
function openStatementWindow(title, period, rows) {
  const w = window.open('', '_blank', 'width=540,height=680');
  const body = rows.map((rw) => `<div class="r"><span>${esc(String(rw[0]))}</span><b>${esc(String(rw[1]))}</b></div>`).join('');
  w.document.write('<html><head><meta charset="utf-8"><title>' + esc(title) + '</title><style>'
    + 'body{font-family:-apple-system,Arial,sans-serif;padding:34px;color:#111}'
    + '.brand{color:#A9832B;font-weight:800;letter-spacing:2px}'
    + 'h1{margin:2px 0 2px;font-size:22px}.sub{color:#666;margin:0 0 20px}'
    + '.r{display:flex;justify-content:space-between;padding:11px 0;border-top:1px solid #eee}'
    + '.r:last-child{border-top:2px solid #E6C76A;font-size:18px;font-weight:700}'
    + 'button{margin-top:24px;padding:10px 18px;border:0;border-radius:8px;background:#111;color:#fff;cursor:pointer}'
    + '@media print{button{display:none}}'
    + '</style></head><body><div class="brand">VYBZZZ</div><h1>' + esc(title) + '</h1>'
    + '<p class="sub">Période : ' + esc(period) + '</p>' + body
    + '<button onclick="window.print()">Imprimer / PDF</button></body></html>');
  w.document.close();
}
async function showArtistStatement(artistId) {
  const { data: d } = await api('GET', '/artist/' + artistId + '/statement');
  const e = (n) => (Math.round(n * 100) / 100).toFixed(2) + ' €';
  openStatementWindow('Relevé artiste — ' + d.artist, d.period, [
    ['🎟️ Billets vendus', d.tickets.count],
    ['Montant net billets', e(d.tickets.net_eur)],
    ['🎁 Tips reçus', d.tips.count + ' (' + d.tips.points + ' pts)'],
    ['Montant net tips', e(d.tips.net_eur)],
    ['TOTAL NET À PERCEVOIR', e(d.total_net_eur)],
  ]);
}
async function showApporteurStatement(apId) {
  const { data: d } = await api('GET', '/apporteurs/' + apId + '/statement');
  const e = (n) => (Math.round(n * 100) / 100).toFixed(2) + ' €';
  openStatementWindow('Relevé apporteur — ' + d.apporteur, d.period, [
    ['Commissions (nb ventes)', d.commission.count],
    ['Assiette (part plateforme)', e(d.commission.base_eur)],
    ['Commission', e(d.commission.eur)],
    ['Primes (nb)', d.primes.count],
    ['Primes', e(d.primes.eur)],
    ['TOTAL DÛ', e(d.total_eur)],
  ]);
}

// ═══════════════════════════════════════════════════════════════════════
// VIBE — Réunions & CRM (section admin interne). Visio Jitsi intégrée.
// ═══════════════════════════════════════════════════════════════════════
let vibeTab = 'objectifs';
let vibePeopleCache = [];
const VIBE_STAGES = [
  ['a_qualifier', 'À qualifier'], ['contacte', 'Contacté'], ['en_discussion', 'En discussion'],
  ['negociation', 'Négociation'], ['contrat_envoye', 'Contrat envoyé'], ['signe', 'Signé'],
  ['en_pause', 'En pause'], ['perdu', 'Perdu'],
];
const stageLabel = (s) => (VIBE_STAGES.find((x) => x[0] === s) || [s, s])[1];
const peopleSelectOpts = () => [{ value: '', label: '—' }].concat(vibePeopleCache.map((p) => ({ value: p.id, label: p.name })));

async function pageVibe() {
  view().innerHTML = `<h1 class="page-title">🎯 Réunions & CRM</h1>
    <p class="em" style="margin:-6px 0 14px">Pilotage interne : objectifs (jauges), réunions en visio, et pipeline de recrutement des artistes.</p>
    <div style="display:flex;gap:8px;margin:0 0 16px;flex-wrap:wrap">
      ${[['objectifs', '🎯 Objectifs'], ['reunions', '🎥 Réunions'], ['crm', '📇 CRM artistes'], ['actions', '✅ Actions'], ['people', '👤 Équipe']]
        .map(([v, l]) => `<button class="btn" data-vt="${v}" style="padding:8px 14px">${l}</button>`).join('')}
    </div>
    <div id="vibe-body"><div class="empty">Chargement…</div></div>`;
  view().querySelectorAll('[data-vt]').forEach((b) => b.onclick = () => { vibeTab = b.dataset.vt; renderVibeTab(); });
  try { vibePeopleCache = (await api('GET', '/vibe/people')).data || []; } catch (e) { vibePeopleCache = []; }
  renderVibeTab();
}
function renderVibeTab() {
  view().querySelectorAll('[data-vt]').forEach((b) => {
    const on = b.dataset.vt === vibeTab;
    b.style.background = on ? 'var(--gold)' : '';
    b.style.color = on ? '#1a1206' : '';
    b.style.fontWeight = on ? '700' : '';
  });
  const body = document.getElementById('vibe-body');
  ({ objectifs: vibeObjectives, reunions: vibeMeetings, crm: vibeCrm, actions: vibeActions, people: vibePeopleTab }[vibeTab] || vibeObjectives)(body);
}

// ── Objectifs (jauges) ──
async function vibeObjectives(body) {
  body.innerHTML = '<div class="empty">Chargement…</div>';
  const objs = (await api('GET', '/vibe/objectives')).data || [];
  const card = (o) => {
    const t = Number(o.target_value) || 0, c = Number(o.current_value) || 0;
    const pct = t > 0 ? Math.min(100, Math.round((c / t) * 100)) : 0;
    const col = o.person_color || '#E6C76A';
    return `<div class="tcard" style="margin-bottom:10px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div><b style="color:${esc(col)}">${esc(o.person_name || '—')}</b> <span class="em">· ${esc(o.scope)}</span></div>
        <span class="badge ${o.status === 'atteint' ? 'active' : 'pending'}">${pct}%</span>
      </div>
      <div style="margin:6px 0 4px;font-weight:600">${esc(o.title)}</div>
      <div style="background:#0A1226;border-radius:6px;height:12px;overflow:hidden"><div style="height:12px;width:${pct}%;background:${esc(col)};transition:width .3s"></div></div>
      <div class="em" style="margin-top:4px">${c} / ${t} ${esc(o.unit || '')}</div>
      <div style="display:flex;gap:6px;margin-top:8px;flex-wrap:wrap">
        <input type="number" id="ck-${o.id}" placeholder="nouvelle valeur" style="width:130px;padding:6px">
        <button class="btn status" data-ck="${o.id}">↑ Mettre à jour</button>
        <button class="btn edit" data-oe="${o.id}">Modifier</button>
        <button class="btn del" data-od="${o.id}">Suppr</button>
      </div>
    </div>`;
  };
  body.innerHTML = `<div class="head-row" style="margin-bottom:12px"><span class="em">Jauges de progression par personne.</span><button class="add-btn" id="obj-add">+ Objectif</button></div>${objs.length ? objs.map(card).join('') : '<div class="empty">Aucun objectif. Ajoute-en un.</div>'}`;
  document.getElementById('obj-add').onclick = () => objForm(null);
  body.querySelectorAll('[data-ck]').forEach((b) => b.onclick = async () => {
    const v = document.getElementById('ck-' + b.dataset.ck).value;
    if (v === '') { toast('Entre une valeur'); return; }
    try { await api('POST', `/vibe/objectives/${b.dataset.ck}/checkin`, { value: Number(v) }); toast('Mis à jour'); vibeObjectives(body); } catch (e) { toast(e.message); }
  });
  body.querySelectorAll('[data-oe]').forEach((b) => b.onclick = () => objForm(objs.find((x) => x.id == b.dataset.oe)));
  body.querySelectorAll('[data-od]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/vibe/objectives/' + b.dataset.od); toast('Supprimé'); vibeObjectives(body); }));
}
function objForm(o) {
  modal({
    title: o ? 'Modifier l\'objectif' : 'Nouvel objectif',
    fields: [
      { name: 'person_id', label: 'Personne', type: 'select', value: o?.person_id || '', options: peopleSelectOpts() },
      { name: 'title', label: 'Objectif', value: o?.title },
      { name: 'scope', label: 'Période', type: 'select', value: o?.scope || 'mensuel', options: [{ value: 'hebdo', label: 'Hebdo' }, { value: 'mensuel', label: 'Mensuel' }, { value: 'trimestriel', label: 'Trimestriel' }] },
      { name: 'target_value', label: 'Cible', type: 'number', value: o?.target_value ?? 0 },
      { name: 'current_value', label: 'Valeur actuelle', type: 'number', value: o?.current_value ?? 0 },
      { name: 'unit', label: 'Unité (ex: artistes, €)', value: o?.unit },
    ],
    onSave: async (d) => {
      if (o) { await api('PUT', '/vibe/objectives/' + o.id, d); toast('Modifié'); }
      else { await api('POST', '/vibe/objectives', d); toast('Ajouté'); }
      renderVibeTab();
    },
  });
}

// ── Réunions (visio Jitsi intégrée) ──
async function vibeMeetings(body) {
  body.innerHTML = '<div class="empty">Chargement…</div>';
  const ms = (await api('GET', '/vibe/meetings')).data || [];
  const row = (m) => `<div class="tcard" style="margin-bottom:8px;display:flex;justify-content:space-between;align-items:center;gap:10px">
    <div><b>${esc(m.title)}</b> <span class="badge ${m.status === 'terminee' ? 'completed' : m.status === 'en_cours' ? 'live' : 'pending'}">${esc(m.status)}</span>
      <div class="em">${esc(m.type)} · ${m.scheduled_at ? fmtDate(m.scheduled_at) : 'sans date'}${m.jitsi_room ? ' · 🎥 Jitsi' : (m.visio_url ? ' · 🔗 lien externe' : '')}</div></div>
    <div style="display:flex;gap:6px"><button class="btn status" data-mopen="${m.id}">Ouvrir</button><button class="btn del" data-mdel="${m.id}">Suppr</button></div>
  </div>`;
  body.innerHTML = `<div class="head-row" style="margin-bottom:12px"><span class="em">Réunions avec visio intégrée (Jitsi, gratuit).</span><button class="add-btn" id="m-add">+ Nouvelle réunion</button></div>${ms.length ? ms.map(row).join('') : '<div class="empty">Aucune réunion.</div>'}`;
  document.getElementById('m-add').onclick = () => meetingForm();
  body.querySelectorAll('[data-mopen]').forEach((b) => b.onclick = () => openMeeting(b.dataset.mopen));
  body.querySelectorAll('[data-mdel]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/vibe/meetings/' + b.dataset.mdel); toast('Supprimée'); vibeMeetings(body); }));
}
function meetingForm() {
  modal({
    title: 'Nouvelle réunion',
    fields: [
      { name: 'title', label: 'Titre' },
      { name: 'type', label: 'Type', type: 'select', value: 'hebdo', options: [{ value: 'hebdo', label: 'Hebdo' }, { value: 'mensuelle', label: 'Mensuelle' }, { value: 'comite', label: 'Comité' }, { value: 'ponctuelle', label: 'Ponctuelle' }] },
      { name: 'scheduled_at', label: 'Date / heure', type: 'datetime' },
      { name: 'visio_url', label: 'Lien visio externe (optionnel)', placeholder: 'Vide = salle Jitsi auto-générée' },
    ],
    onSave: async (d) => { await api('POST', '/vibe/meetings', d); toast('Réunion créée'); renderVibeTab(); },
  });
}
async function openMeeting(id) {
  const body = document.getElementById('vibe-body');
  body.innerHTML = '<div class="empty">Chargement…</div>';
  const m = (await api('GET', '/vibe/meetings/' + id)).data;
  const isJitsi = !m.visio_url && m.jitsi_room;
  const visioUrl = m.visio_url || (m.jitsi_room ? `https://meet.jit.si/${encodeURIComponent(m.jitsi_room)}` : null);
  const actions = m.actions || [];
  body.innerHTML = `
    <button class="btn" id="m-back" style="margin-bottom:10px">← Retour</button>
    <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">
      <h2 style="margin:0">${esc(m.title)}</h2>
      <select id="m-status">${['planifiee', 'en_cours', 'terminee', 'annulee'].map((s) => `<option value="${s}" ${m.status === s ? 'selected' : ''}>${s}</option>`).join('')}</select>
    </div>
    <div class="em" style="margin:4px 0 12px">${esc(m.type)} · ${m.scheduled_at ? fmtDate(m.scheduled_at) : 'sans date'}</div>
    ${visioUrl ? `<div style="margin-bottom:8px;display:flex;gap:8px;flex-wrap:wrap">
      <button class="btn gold" id="m-join">🎥 ${isJitsi ? 'Rejoindre la visio (Jitsi)' : 'Ouvrir la visio'}</button>
      <button class="btn" id="m-copy">📋 Copier le lien invités</button>
    </div><div id="m-visio"></div>` : ''}
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px">
      <div>
        <b>Compte rendu / notes</b>
        <textarea id="m-notes" style="width:100%;min-height:220px;margin-top:6px" placeholder="Notes de réunion (sauvegarde auto)">${esc(m.summary_md || '')}</textarea>
        <div class="em" id="m-notes-status" style="margin-top:4px"></div>
      </div>
      <div>
        <div style="display:flex;justify-content:space-between;align-items:center"><b>Actions décidées</b><button class="btn" id="a-add">+ Action</button></div>
        <div id="m-actions" style="margin-top:8px">${actions.length ? actions.map(actionRow).join('') : '<div class="em">Aucune action.</div>'}</div>
      </div>
    </div>
    <div style="margin-top:18px;padding:16px 18px;border:1px solid var(--line);border-radius:12px;background:var(--card)">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">
        <b>🤖 Assistant IA</b>
        <div style="display:flex;gap:8px;flex-wrap:wrap">
          <button class="btn gold" id="ai-points">🎯 Arguments clés</button>
          <button class="btn" id="ai-reply">💬 Rédiger une réponse</button>
          <button class="btn" id="ai-ask">❓ Demander</button>
        </div>
      </div>
      <textarea id="ai-input" style="width:100%;min-height:70px;margin-top:10px" placeholder="Colle ce qu'on vient de te dire (pour « Rédiger une réponse ») ou pose ta question (pour « Demander »)…"></textarea>
      <div id="ai-out" style="margin-top:10px;white-space:pre-wrap;line-height:1.55"></div>
    </div>`;
  document.getElementById('m-back').onclick = () => { vibeTab = 'reunions'; renderVibeTab(); };
  document.getElementById('m-status').onchange = async (e) => { await api('PUT', '/vibe/meetings/' + id, { status: e.target.value }); toast('Statut mis à jour'); };
  const notes = document.getElementById('m-notes');
  let noteT;
  notes.oninput = () => {
    clearTimeout(noteT);
    document.getElementById('m-notes-status').textContent = '…';
    noteT = setTimeout(async () => { await api('PUT', '/vibe/meetings/' + id, { summary_md: notes.value }); document.getElementById('m-notes-status').textContent = 'Enregistré ✓'; }, 800);
  };
  if (visioUrl) {
    document.getElementById('m-join').onclick = () => {
      // La visio s'ouvre dans un nouvel onglet : Jitsi (et la CSP de l'admin)
      // interdisent l'intégration en iframe, et un onglet dédié gère bien mieux
      // la caméra / le micro / le plein écran.
      window.open(visioUrl, '_blank', 'noopener');
      if (isJitsi && m.status === 'planifiee') {
        api('PUT', '/vibe/meetings/' + id, { status: 'en_cours' });
        const sel = document.getElementById('m-status'); if (sel) sel.value = 'en_cours';
      }
      const host = document.getElementById('m-visio');
      if (host) host.innerHTML = `<div style="margin-top:10px;padding:16px 18px;border:1px solid var(--line);border-radius:12px;background:var(--card);color:var(--muted)">🎥 La visio s'est ouverte dans un nouvel onglet. Garde cet onglet-ci ouvert pour prendre tes notes (sauvegarde auto).</div>`;
    };
    document.getElementById('m-copy').onclick = () => { navigator.clipboard?.writeText(visioUrl); toast('Lien visio copié'); };
  }
  document.getElementById('a-add').onclick = () => actionForm({ meeting_id: id }, () => openMeeting(id));

  // ── Assistant IA : arguments / réponse / question ──
  (function () {
    const out = document.getElementById('ai-out');
    const input = document.getElementById('ai-input');
    async function ask(mode) {
      if ((mode === 'reply' || mode === 'ask') && !input.value.trim()) { toast('Écris d’abord dans le champ ci-dessus.'); input.focus(); return; }
      out.innerHTML = '<span class="em">L’assistant réfléchit…</span>';
      try {
        const r = await api('POST', '/vibe/meetings/' + id + '/assist', { mode, input: input.value.trim() });
        const text = (r.data && r.data.text) || '(réponse vide)';
        out.innerHTML = '';
        const box = document.createElement('div');
        box.textContent = text;
        const copy = document.createElement('button');
        copy.className = 'btn'; copy.style.marginTop = '10px'; copy.textContent = '📋 Copier';
        copy.onclick = () => { navigator.clipboard?.writeText(text); toast('Copié'); };
        const addNote = document.createElement('button');
        addNote.className = 'btn'; addNote.style.cssText = 'margin-top:10px;margin-left:8px'; addNote.textContent = '➕ Ajouter aux notes';
        addNote.onclick = () => { const n = document.getElementById('m-notes'); n.value = (n.value ? n.value + '\n\n' : '') + text; n.dispatchEvent(new Event('input')); toast('Ajouté aux notes'); };
        out.appendChild(box); out.appendChild(copy); out.appendChild(addNote);
      } catch (e) { out.innerHTML = '<span style="color:#f88">' + esc(e.message) + '</span>'; }
    }
    document.getElementById('ai-points').onclick = () => ask('points');
    document.getElementById('ai-reply').onclick = () => ask('reply');
    document.getElementById('ai-ask').onclick = () => ask('ask');
  })();
  bindActionRows(body, () => openMeeting(id));
}
function actionRow(a) {
  const done = a.status === 'fait';
  return `<div class="tcard" style="margin-bottom:6px;display:flex;justify-content:space-between;align-items:center;gap:8px">
    <div><span style="${done ? 'text-decoration:line-through;opacity:.6' : ''}">${esc(a.title)}</span>
      <div class="em">${a.assignee_name ? esc(a.assignee_name) : '—'}${a.due_date ? ' · ' + fmtDate(a.due_date) : ''}${a.crm_name ? ' · 🎤 ' + esc(a.crm_name) : ''}${a.meeting_title ? ' · ' + esc(a.meeting_title) : ''}</div></div>
    <div style="display:flex;gap:4px">
      <select data-astatus="${a.id}">${['a_faire', 'en_cours', 'fait', 'bloque'].map((s) => `<option value="${s}" ${a.status === s ? 'selected' : ''}>${s}</option>`).join('')}</select>
      <button class="btn del" data-adel="${a.id}">✕</button>
    </div>
  </div>`;
}
function bindActionRows(scope, reload) {
  scope.querySelectorAll('[data-astatus]').forEach((s) => s.onchange = async () => { await api('PATCH', '/vibe/actions/' + s.dataset.astatus, { status: s.value }); toast('Action mise à jour'); });
  scope.querySelectorAll('[data-adel]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/vibe/actions/' + b.dataset.adel); toast('Supprimée'); reload && reload(); }));
}
function actionForm(preset, reload) {
  modal({
    title: 'Nouvelle action',
    fields: [
      { name: 'title', label: 'Action' },
      { name: 'assignee_id', label: 'Assignée à', type: 'select', value: preset?.assignee_id || '', options: peopleSelectOpts() },
      { name: 'due_date', label: 'Échéance (AAAA-MM-JJ)', placeholder: '2026-09-01' },
      { name: 'priority', label: 'Priorité', type: 'select', value: 'normale', options: [{ value: 'basse', label: 'Basse' }, { value: 'normale', label: 'Normale' }, { value: 'haute', label: 'Haute' }, { value: 'critique', label: 'Critique' }] },
    ],
    onSave: async (d) => { await api('POST', '/vibe/actions', { ...preset, ...d }); toast('Action ajoutée'); reload && reload(); },
  });
}

// ── Actions (vue globale) ──
async function vibeActions(body) {
  body.innerHTML = '<div class="empty">Chargement…</div>';
  const acts = (await api('GET', '/vibe/actions')).data || [];
  body.innerHTML = `<div class="head-row" style="margin-bottom:12px"><span class="em">Toutes les actions, tout suivi confondu.</span><button class="add-btn" id="ga-add">+ Action</button></div>${acts.length ? acts.map(actionRow).join('') : '<div class="empty">Aucune action.</div>'}`;
  document.getElementById('ga-add').onclick = () => actionForm({}, () => vibeActions(body));
  bindActionRows(body, () => vibeActions(body));
}

// ── CRM artistes (pipeline) ──
async function vibeCrm(body) {
  body.innerHTML = '<div class="empty">Chargement…</div>';
  const rows = (await api('GET', '/vibe/crm')).data || [];
  const counts = {};
  VIBE_STAGES.forEach(([v]) => counts[v] = rows.filter((r) => r.pipeline_stage === v).length);
  const card = (r) => `<div class="tcard" style="margin-bottom:8px">
    <div style="display:flex;justify-content:space-between;align-items:start;gap:8px">
      <div><b>${esc(r.stage_name || r.legal_name || '—')}</b>${r.genre ? ` <span class="em">· ${esc(r.genre)}</span>` : ''}
        <div class="em">${r.followers_count ? Number(r.followers_count).toLocaleString('fr-FR') + ' abonnés · ' : ''}${r.referrer_name ? 'apporteur : ' + esc(r.referrer_name) : 'direct'}${r.next_action_date ? ' · ⏰ ' + fmtDate(r.next_action_date) : ''}</div></div>
      <div style="display:flex;gap:4px"><button class="btn edit" data-ce="${r.id}">Modifier</button><button class="btn del" data-cd="${r.id}">Suppr</button></div>
    </div>
    <div style="margin-top:6px"><select data-cstage="${r.id}">${VIBE_STAGES.map(([v, l]) => `<option value="${v}" ${r.pipeline_stage === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
  </div>`;
  body.innerHTML = `<div class="head-row" style="margin-bottom:10px"><span class="em">Pipeline de recrutement — ${rows.length} contact(s).</span><button class="add-btn" id="crm-add">+ Artiste</button></div>
    <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px">${VIBE_STAGES.map(([v, l]) => `<span class="badge pending" style="opacity:${counts[v] ? 1 : 0.4}">${l} : ${counts[v]}</span>`).join('')}</div>
    ${rows.length ? rows.map(card).join('') : '<div class="empty">Aucun artiste dans le pipeline.</div>'}`;
  document.getElementById('crm-add').onclick = () => crmForm(null);
  body.querySelectorAll('[data-cstage]').forEach((s) => s.onchange = async () => { await api('PATCH', '/vibe/crm/' + s.dataset.cstage, { pipeline_stage: s.value }); toast('Étape mise à jour'); });
  body.querySelectorAll('[data-ce]').forEach((b) => b.onclick = () => crmForm(rows.find((x) => x.id == b.dataset.ce)));
  body.querySelectorAll('[data-cd]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/vibe/crm/' + b.dataset.cd); toast('Supprimé'); vibeCrm(body); }));
}
function crmForm(r) {
  modal({
    title: r ? 'Modifier le contact' : 'Nouvel artiste (CRM)',
    fields: [
      { name: 'stage_name', label: 'Nom de scène', value: r?.stage_name },
      { name: 'legal_name', label: 'Nom civil (optionnel)', value: r?.legal_name },
      { name: 'genre', label: 'Genre', value: r?.genre },
      { name: 'followers_count', label: 'Abonnés (nombre)', type: 'number', value: r?.followers_count },
      { name: 'instagram', label: 'Instagram', value: r?.instagram },
      { name: 'country', label: 'Pays', value: r?.country },
      { name: 'referrer_id', label: 'Apporteur d\'affaires', type: 'select', value: r?.referrer_id || '', options: peopleSelectOpts() },
      { name: 'pipeline_stage', label: 'Étape', type: 'select', value: r?.pipeline_stage || 'a_qualifier', options: VIBE_STAGES.map(([v, l]) => ({ value: v, label: l })) },
      { name: 'next_action_date', label: 'Prochaine action (AAAA-MM-JJ)', value: r?.next_action_date },
      { name: 'notes_md', label: 'Notes', type: 'textarea', value: r?.notes_md },
    ],
    onSave: async (d) => {
      if (r) { await api('PATCH', '/vibe/crm/' + r.id, d); toast('Modifié'); }
      else { await api('POST', '/vibe/crm', d); toast('Ajouté'); }
      renderVibeTab();
    },
  });
}

// ── Équipe (personnes) ──
async function vibePeopleTab(body) {
  body.innerHTML = '<div class="empty">Chargement…</div>';
  vibePeopleCache = (await api('GET', '/vibe/people')).data || [];
  const roleLabel = { admin: 'Admin', associe: 'Associé', equipe: 'Équipe', apporteur: 'Apporteur' };
  const row = (p) => `<div class="tcard" style="margin-bottom:8px;display:flex;justify-content:space-between;align-items:center;gap:8px">
    <div><b style="color:${esc(p.color || '#E6C76A')}">${esc(p.name)}</b> <span class="em">· ${esc(roleLabel[p.role] || p.role)}</span>${p.email ? `<div class="em">${esc(p.email)}</div>` : ''}</div>
    <div style="display:flex;gap:6px"><button class="btn edit" data-pe="${p.id}">Modifier</button><button class="btn del" data-pd="${p.id}">Suppr</button></div>
  </div>`;
  body.innerHTML = `<div class="head-row" style="margin-bottom:12px"><span class="em">Personnes suivies (équipe, associés, apporteurs).</span><button class="add-btn" id="p-add">+ Personne</button></div>${vibePeopleCache.map(row).join('') || '<div class="empty">Personne.</div>'}`;
  document.getElementById('p-add').onclick = () => peopleForm(null);
  body.querySelectorAll('[data-pe]').forEach((b) => b.onclick = () => peopleForm(vibePeopleCache.find((x) => x.id == b.dataset.pe)));
  body.querySelectorAll('[data-pd]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/vibe/people/' + b.dataset.pd); toast('Supprimé'); vibePeopleTab(body); }));
}
function peopleForm(p) {
  modal({
    title: p ? 'Modifier la personne' : 'Nouvelle personne',
    fields: [
      { name: 'name', label: 'Nom', value: p?.name },
      { name: 'role', label: 'Rôle', type: 'select', value: p?.role || 'associe', options: [{ value: 'associe', label: 'Associé' }, { value: 'equipe', label: 'Équipe' }, { value: 'apporteur', label: 'Apporteur' }, { value: 'admin', label: 'Admin' }] },
      { name: 'email', label: 'Email (optionnel)', value: p?.email },
      { name: 'color', label: 'Couleur (hex, ex #E6C76A)', value: p?.color || '#E6C76A' },
      ...(p ? [{ name: 'active', label: 'Actif ?', type: 'checkbox', value: !!p.active, hint: 'Actif' }] : []),
    ],
    onSave: async (d) => {
      if (p) { await api('PUT', '/vibe/people/' + p.id, d); toast('Modifié'); }
      else { await api('POST', '/vibe/people', d); toast('Ajouté'); }
      vibePeopleCache = (await api('GET', '/vibe/people')).data || [];
      renderVibeTab();
    },
  });
}

// ── Accès & rôles : comptes staff à visibilité restreinte (super-admin) ──
async function pageAccess() {
  view().innerHTML = '<div class="empty">Chargement…</div>';
  const staff = (await api('GET', '/staff')).data || [];
  const modLabel = (id) => (DELEGATABLE_MODULES.find((m) => m.id === id) || { label: id }).label;
  const row = (u) => `<div class="tcard" style="margin-bottom:8px;display:flex;justify-content:space-between;align-items:center;gap:10px">
    <div><b>${esc(u.full_name || u.email)}</b> ${u.role === 'admin' ? '<span class="badge active">Super-admin</span>' : '<span class="badge pending">Staff</span>'}
      <div class="em">${esc(u.email)}${u.role === 'staff'
        ? ' · accès : ' + (Array.isArray(u.scopes) && u.scopes.length ? u.scopes.map(modLabel).join(', ') : 'aucun')
        : ' · accès total'}</div></div>
    ${u.role === 'staff' ? `<div style="display:flex;gap:6px"><button class="btn edit" data-se="${u.id}">Modifier</button><button class="btn del" data-sd="${u.id}">Suppr</button></div>` : '<span class="em">(toi)</span>'}
  </div>`;
  view().innerHTML = `<div class="head-row"><h1 class="page-title">🔐 Accès & rôles</h1><button class="add-btn" id="staff-add">+ Membre (staff)</button></div>
    <p class="em" style="margin:-6px 0 14px">Crée des comptes <b>à visibilité restreinte</b> : un membre ne voit QUE les modules cochés, et le serveur bloque tout le reste. Les données sensibles (utilisateurs, finances, transactions…) restent réservées à toi (super-admin).</p>
    ${staff.map(row).join('')}`;
  document.getElementById('staff-add').onclick = () => staffForm(null);
  view().querySelectorAll('[data-se]').forEach((b) => b.onclick = () => staffForm(staff.find((x) => x.id == b.dataset.se)));
  view().querySelectorAll('[data-sd]').forEach((b) => b.onclick = () => confirmDelete(async () => { await api('DELETE', '/staff/' + b.dataset.sd); toast('Supprimé'); pageAccess(); }));
}
function staffForm(u) {
  const scopes = new Set(Array.isArray(u?.scopes) ? u.scopes : []);
  const modChecks = DELEGATABLE_MODULES.map((m) => ({ name: 'scope_' + m.id, label: 'Accès : ' + m.label, type: 'checkbox', value: scopes.has(m.id), hint: m.label }));
  modal({
    title: u ? 'Modifier le membre' : 'Nouveau membre (staff)',
    fields: [
      { name: 'full_name', label: 'Nom', value: u?.full_name },
      { name: 'email', label: 'Email', value: u?.email },
      { name: 'password', label: u ? 'Nouveau mot de passe (vide = inchangé)' : 'Mot de passe', type: 'password' },
      ...modChecks,
    ],
    onSave: async (d) => {
      const scopesArr = DELEGATABLE_MODULES.filter((m) => d['scope_' + m.id]).map((m) => m.id);
      const payload = { full_name: d.full_name, email: d.email, scopes: scopesArr };
      if (d.password) payload.password = d.password;
      if (u) { await api('PUT', '/staff/' + u.id, payload); toast('Membre modifié'); }
      else { if (!d.password) throw new Error('Mot de passe requis'); await api('POST', '/staff', payload); toast('Membre créé'); }
      pageAccess();
    },
  });
}

const ROUTES = {
  dashboard: pageDashboard, lives: pageLives, users: pageUsers, geo: pageGeo, genres: pageGenres, 'user-genres': pageUserGenres,
  events: pageEvents, 'feed-clips': pageFeedClips, packages: pagePackages, subscriptions: pageSubscriptions, referrals: pageReferrals,
  abusive: pageAbusive, reviews: pageReviews, withdrawals: pageWithdrawals, transactions: pageTransactions,
  reports: pageReports, support: pageSupport, ideas: pageIdeas, leads: pageLeads, faqs: pageFaqs, cms: pageCms, profile: pageProfile,
  splash: pageSplash, legal: pageLegal, challenge: pageChallenge, merch: pageMerch, audience: pageAudience, apporteurs: pageApporteurs, vibe: pageVibe, access: pageAccess, apikeys: pageApiKeys,
};

window.addEventListener('hashchange', route);
$('login-btn').onclick = login;
$('login-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') login(); });
$('logout-btn').onclick = logout;
if (token && admin) boot(); else { $('login').classList.remove('hidden'); }

/* VybzzZ web — l'application dans le navigateur (fan).
 * Même compte et même API que l'application mobile (https://api.vybzzz.online/api,
 * jeton JWT « Bearer »). Écrans : accueil, feed de clips, fiche concert, billets,
 * artiste, compte, connexion / inscription. Le live se regarde sur ../live.html
 * (flux signé, filigrane), qui reconnaît le compte connecté ici.
 */
(function () {
  'use strict';

  var ORIGIN = 'https://api.vybzzz.online';
  var API = ORIGIN + '/api';
  var $view = document.getElementById('view');

  // ── Session ───────────────────────────────────────────────────────────────
  var S = {
    get token() { try { return localStorage.getItem('vy_jwt'); } catch (e) { return null; } },
    get user() { try { return JSON.parse(localStorage.getItem('vy_user') || 'null'); } catch (e) { return null; } },
    set: function (token, user) {
      try {
        if (token) localStorage.setItem('vy_jwt', token);
        if (user) localStorage.setItem('vy_user', JSON.stringify(user));
      } catch (e) {}
    },
    clear: function () { try { localStorage.removeItem('vy_jwt'); localStorage.removeItem('vy_user'); } catch (e) {} },
  };

  function api(path, opts) {
    opts = opts || {};
    var headers = { Accept: 'application/json' };
    if (opts.body) headers['Content-Type'] = 'application/json';
    if (S.token) headers.Authorization = 'Bearer ' + S.token;
    return fetch(API + path, {
      method: opts.method || (opts.body ? 'POST' : 'GET'),
      headers: headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
      credentials: 'omit',
      cache: 'no-store',
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        d = d || {}; d._code = r.status;
        // Jeton expiré ou compte suspendu : on repart déconnecté.
        if (r.status === 401 && S.token && opts.auth !== false) { S.clear(); renderTop(); }
        return d;
      });
    });
  }

  // ── Outils ────────────────────────────────────────────────────────────────
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function cover(u) {
    if (!u) return ORIGIN + '/defaults/live-cover.jpg';
    return /^https?:\/\//.test(u) ? u : ORIGIN + '/events/covers/' + encodeURIComponent(u);
  }
  function price(p) {
    var n = parseFloat(p);
    if (!isFinite(n) || n <= 0) return 'Gratuit';
    return n.toFixed(2).replace('.', ',') + ' €';
  }
  function when(iso) {
    var d = new Date(String(iso || '').replace(' ', 'T'));
    if (isNaN(d)) return '';
    try { return d.toLocaleString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }); } catch (e) { return d.toString(); }
  }
  function artistName(a) { return a ? (a.artist_name || a.full_name || a.name || 'Artiste') : 'Artiste'; }
  function initials(n) { return String(n || '?').trim().charAt(0).toUpperCase(); }
  function avatar(url, name, cls) {
    return url ? '<img class="' + (cls || '') + '" src="' + esc(url) + '" alt="" loading="lazy">' : '<div class="ph ' + (cls || '') + '">' + esc(initials(name)) + '</div>';
  }
  var toastTimer;
  function toast(t) {
    var el = document.getElementById('toast'); el.textContent = t; el.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { el.hidden = true; }, 3200);
  }
  function track(n) { if (window.vyTrack) window.vyTrack(n); }
  function liveUrl(id) { return '../live.html?e=' + encodeURIComponent(id); }
  function isLive(ev) { return ev && ev.status === 'live'; }
  function isOver(ev) { return ev && (ev.status === 'completed' || ev.status === 'ended'); }

  function eventCard(ev) {
    var live = isLive(ev);
    var badge = live ? '<span class="card__badge card__badge--live"><span class="dot-live" style="background:#fff"></span>EN DIRECT</span>'
      : isOver(ev) ? '<span class="card__badge">REPLAY</span>' : '<span class="card__badge">' + esc(when(ev.start_date_time)) + '</span>';
    return '<a class="card" href="#/event/' + ev.id + '">' +
      '<div class="card__img" style="background-image:url(\'' + esc(cover(ev.cover_image)) + '\')">' + badge + '</div>' +
      '<div class="card__body"><div class="card__title">' + esc(ev.name) + '</div>' +
      '<div class="card__meta">' + esc(artistName(ev.artist)) + '</div>' +
      '<div class="card__price">' + esc(ev.has_ticket ? 'Ta place est réservée' : price(ev.ticket_price)) + '</div></div></a>';
  }
  function skeletonRow(n) { var h = ''; for (var i = 0; i < (n || 4); i++) h += '<div class="skel" style="height:330px"></div>'; return '<div class="row">' + h + '</div>'; }

  // Passerelle pour les écrans chargés à la demande (studio.js).
  window.VyWeb = { API: API, api: api, S: S, esc: esc, toast: toast, avatar: avatar, artistName: artistName, price: price, view: $view, needLogin: needLogin, setTab: setTab, renderTop: renderTop };

  // ── Barre du haut / onglets ───────────────────────────────────────────────
  function renderTop() {
    var u = S.user, el = document.getElementById('topRight');
    if (u && S.token) {
      el.innerHTML = (u.is_artist ? '<a class="pill pill--live" href="#/studio">\uD83C\uDF99 Live</a>' : '') + '<a class="pill" href="#/account" aria-label="Mon compte">' +
        (u.profile_image ? '<img class="avatar" src="' + esc(u.profile_image) + '" alt="">' : '<span class="avatar">' + esc(initials(artistName(u))) + '</span>') +
        '<span class="hide-sm">' + esc((u.full_name || u.artist_name || 'Mon compte').split(' ')[0]) + '</span></a>';
    } else {
      el.innerHTML = '<a class="pill" href="#/login">Connexion</a><a class="pill pill--gold" href="#/signup">Créer un compte</a>';
    }
  }
  function setTab(tab) {
    document.querySelectorAll('[data-tab]').forEach(function (a) {
      if (a.getAttribute('data-tab') === tab) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
    document.body.classList.toggle('view-feed', tab === 'feed');
  }

  // ── Accueil ───────────────────────────────────────────────────────────────
  function viewHome() {
    setTab('home'); document.title = 'VybzzZ · Concerts en direct';
    $view.innerHTML =
      '<section class="sec" id="hFeatured"></section>' +
      '<section class="sec" id="hLive"></section>' +
      '<section class="sec"><h2>À venir</h2><div id="hUpcoming">' + skeletonRow() + '</div></section>' +
      '<section class="sec" id="hArtists"></section>' +
      '<section class="sec" id="hReplays"></section>';

    api('/featured-event').then(function (d) {
      var f = d && d.data, ev = f && f.event; if (!ev) return;
      var el = document.getElementById('hFeatured'); if (!el) return;
      el.innerHTML = '<div class="hero"><div class="hero__img" style="background-image:url(\'' + esc(cover(ev.cover_image)) + '\');background-size:contain;background-color:var(--navy)"></div>' +
        '<div class="hero__txt"><span class="eyebrow">' + esc(f.headline || 'À la une') + '</span><h1>' + esc(ev.name) + '</h1>' +
        '<p class="muted">' + esc(artistName(ev.artist)) + ' · ' + esc(when(ev.start_date_time)) + '</p>' +
        '<div style="display:flex;gap:10px;flex-wrap:wrap"><a class="btn btn-gold" href="#/event/' + ev.id + '">' + (isLive(ev) ? 'Regarder en direct' : ev.has_ticket ? 'Ma place' : 'Réserver · ' + esc(price(ev.ticket_price))) + '</a></div></div></div>';
    });

    api('/events?status=live').then(function (d) {
      var list = (d && d.data) || [], el = document.getElementById('hLive'); if (!el || !list.length) return;
      el.innerHTML = '<h2><span class="dot-live"></span>En direct maintenant</h2><div class="row">' + list.map(eventCard).join('') + '</div>';
    });

    Promise.all([api('/events?status=published&day=today'), api('/events?status=published&day=future')]).then(function (r) {
      var seen = {}, list = [].concat((r[0] && r[0].data) || [], (r[1] && r[1].data) || []).filter(function (e) { if (seen[e.id]) return false; seen[e.id] = 1; return true; });
      var el = document.getElementById('hUpcoming'); if (!el) return;
      el.innerHTML = list.length ? '<div class="row">' + list.map(eventCard).join('') + '</div>' : '<div class="empty">Les prochains concerts arrivent. Reviens vite !</div>';
    });

    api('/featured-artists').then(function (d) {
      var list = (d && d.data) || [], el = document.getElementById('hArtists'); if (!el || !list.length) return;
      el.innerHTML = '<h2>Artistes</h2><div class="artists">' + list.map(function (a) {
        return '<a class="artist" href="#/artist/' + a.id + '">' + avatar(a.profile_image, artistName(a)) + '<span>' + esc(artistName(a)) + '</span></a>';
      }).join('') + '</div>';
    });

    api('/events?status=completed').then(function (d) {
      var list = ((d && d.data) || []).filter(function (e) { return e.has_replay && !e.replay_expired; }).slice(-12).reverse();
      var el = document.getElementById('hReplays'); if (!el || !list.length) return;
      el.innerHTML = '<h2>Replays</h2><div class="row">' + list.map(eventCard).join('') + '</div>';
    });
  }

  // ── Feed de clips ─────────────────────────────────────────────────────────
  var feedState = null;
  function stopFeed() {
    if (!feedState) return;
    feedState.io && feedState.io.disconnect();
    feedState.players.forEach(function (p) { try { p.hls && p.hls.destroy(); } catch (e) {} try { p.v.pause(); } catch (e) {} });
    feedState = null;
  }
  function viewFeed(kind) {
    setTab('feed'); document.title = 'Feed · VybzzZ';
    kind = kind === 'clips' ? 'clips' : 'for_you';
    $view.innerHTML = '<div class="feed" id="feed"><div class="feed__tabs"><button type="button" data-k="for_you" aria-pressed="' + (kind === 'for_you') + '">Pour toi</button><button type="button" data-k="clips" aria-pressed="' + (kind === 'clips') + '">Clips</button></div></div>';
    $view.querySelectorAll('.feed__tabs button').forEach(function (b) { b.onclick = function () { location.hash = '#/feed' + (b.dataset.k === 'clips' ? '/clips' : ''); }; });
    var box = document.getElementById('feed');
    feedState = { players: [], muted: true, loading: false, kind: kind, seen: {} };
    var st = feedState;

    function attach(p) {
      if (p.ready) return; p.ready = true;
      var url = p.url;
      if (window.Hls && window.Hls.isSupported() && /\.m3u8/.test(url)) { p.hls = new window.Hls({ maxBufferLength: 12 }); p.hls.loadSource(url); p.hls.attachMedia(p.v); }
      else p.v.src = url;
    }
    function detach(p) {
      if (!p.ready) return; p.ready = false;
      try { p.v.pause(); } catch (e) {}
      if (p.hls) { try { p.hls.destroy(); } catch (e) {} p.hls = null; }
      p.v.removeAttribute('src'); try { p.v.load(); } catch (e) {}
    }
    // Un seul clip lu à la fois ; le suivant est préchargé, les autres libérés.
    function focus(idx) {
      st.players.forEach(function (p, i) {
        if (i === idx || i === idx + 1) attach(p); else if (Math.abs(i - idx) > 2) detach(p);
        if (i === idx) { p.v.muted = st.muted; var pr = p.v.play(); if (pr && pr.catch) pr.catch(function () { p.v.muted = true; st.muted = true; p.v.play().catch(function () {}); syncMute(); }); }
        else { try { p.v.pause(); } catch (e) {} }
      });
      if (idx >= st.players.length - 3) more();
    }
    function syncMute() { box.querySelectorAll('[data-mute]').forEach(function (b) { b.innerHTML = st.muted ? ICON_MUTED : ICON_SOUND; b.setAttribute('aria-label', st.muted ? 'Activer le son' : 'Couper le son'); }); }
    st.io = new IntersectionObserver(function (es) {
      es.forEach(function (en) { if (en.isIntersecting && en.intersectionRatio > 0.6) focus(+en.target.dataset.i); });
    }, { root: box, threshold: [0.6] });

    function add(list) {
      list.forEach(function (c) {
        if (!c.video_url || st.seen[c.id]) return; st.seen[c.id] = 1;
        var i = st.players.length, a = c.artist || {};
        var el = document.createElement('section'); el.className = 'clip'; el.dataset.i = i;
        el.innerHTML = '<video playsinline loop preload="none" muted' + (c.mux_playback_id ? ' poster="https://image.mux.com/' + esc(c.mux_playback_id) + '/thumbnail.webp?width=720"' : '') + '></video>' +
          '<div class="clip__info">' + (a.id ? '<a class="clip__artist" href="#/artist/' + a.id + '">' + (a.image ? '<img src="' + esc(a.image) + '" alt="">' : '') + esc(a.name || 'Artiste') + '</a>' : '') +
          (c.title ? '<div>' + esc(c.title) + '</div>' : '') + '</div>' +
          '<div class="clip__side"><button class="round" type="button" data-mute></button>' +
          '<button class="round" type="button" data-share aria-label="Partager"><svg viewBox="0 0 24 24"><path d="M4 12v7a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7M16 6l-4-4-4 4M12 2v14"/></svg></button></div>';
        var v = el.querySelector('video');
        v.addEventListener('click', function () { if (v.paused) v.play().catch(function () {}); else v.pause(); });
        el.querySelector('[data-mute]').onclick = function () { st.muted = !st.muted; st.players.forEach(function (p) { p.v.muted = st.muted; }); syncMute(); };
        el.querySelector('[data-share]').onclick = function () {
          var t = 'Découvre ' + (a.name || 'cet artiste') + ' sur VybzzZ 🎤', u = 'https://vybzzz.online/web/' + (a.id ? '#/artist/' + a.id : '#/feed');
          if (navigator.share) navigator.share({ title: 'VybzzZ', text: t, url: u }).catch(function () {});
          else if (navigator.clipboard) navigator.clipboard.writeText(u).then(function () { toast('Lien copié'); });
        };
        box.appendChild(el);
        st.players.push({ v: v, url: c.video_url, el: el });
        st.io.observe(el);
      });
      syncMute();
      if (!st.players.length) box.insertAdjacentHTML('beforeend', '<div class="clip"><p class="muted">Les premiers clips arrivent.</p></div>');
    }
    function more() {
      if (st.loading || feedState !== st) return; st.loading = true;
      api('/feed-clips?feed=' + kind + '&limit=10').then(function (d) { st.loading = false; if (feedState === st) add((d && d.list) || []); })
        .catch(function () { st.loading = false; });
    }
    more();
  }
  var ICON_MUTED = '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9z"/><path d="M16 9l5 5m0-5l-5 5"/></svg>';
  var ICON_SOUND = '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9z"/><path d="M16 8.5a5 5 0 0 1 0 7M19 5.5a9 9 0 0 1 0 13"/></svg>';

  // ── Fiche concert ─────────────────────────────────────────────────────────
  function viewEvent(id) {
    setTab(''); $view.innerHTML = '<div class="ev"><div class="skel" style="aspect-ratio:4/5"></div><div class="skel" style="height:300px"></div></div>';
    api('/event/' + encodeURIComponent(id)).then(function (d) {
      var ev = d && d.data;
      if (!ev) { $view.innerHTML = '<div class="empty">Concert introuvable. <a class="link" href="#/">Retour à l\'accueil</a></div>'; return; }
      document.title = ev.name + ' · VybzzZ';
      var a = ev.artist || {}, free = !(parseFloat(ev.ticket_price) > 0), live = isLive(ev), over = isOver(ev);
      var canWatch = free || ev.has_ticket;
      var action;
      if (over && !ev.has_replay) action = '<p class="muted">Ce concert est terminé.</p>';
      else if (canWatch && (live || over)) action = '<a class="btn btn-gold btn-block" href="' + liveUrl(ev.id) + '">' + (live ? '▶ Regarder en direct' : '▶ Regarder le replay') + '</a>';
      else if (ev.has_ticket) action = '<p><b>Ta place est réservée.</b></p><a class="btn btn-ghost btn-block" href="' + liveUrl(ev.id) + '">Ouvrir la page du live</a><p class="small muted">Le concert se lance tout seul à l\'heure, sur cette page.</p>';
      else if (free) action = '<button class="btn btn-gold btn-block" id="evFree">Réserver ma place gratuite</button>';
      else action = '<form id="evBuy" novalidate>' + (S.user ? '' : '<label for="evEmail">Ton adresse e-mail</label><input id="evEmail" type="email" autocomplete="email" inputmode="email" required placeholder="toi@exemple.com">') +
        '<button class="btn btn-gold btn-block" type="submit">Prendre ma place · ' + esc(price(ev.ticket_price)) + '</button><div class="msg" id="evMsg" role="alert"></div>' +
        '<p class="small muted">Paiement sécurisé par carte (Stripe). Tu regardes le concert ici, sans application.</p></form>';
      var next = (!free && ev.next_price != null && ev.next_price_at && Date.parse(ev.next_price_at) > Date.now()) ? '<span class="small muted"> puis ' + esc(price(ev.next_price)) + '</span>' : '';
      var guests = (ev.guests || []).map(function (g) { return esc(g.artist_name); }).filter(Boolean);
      $view.innerHTML = '<div class="ev"><div class="ev__cover"><img src="' + esc(cover(ev.cover_image)) + '" alt="Affiche : ' + esc(ev.name) + '"></div>' +
        '<div class="ev__info">' + (live ? '<span class="eyebrow"><span class="dot-live"></span> En direct</span>' : over ? '<span class="eyebrow">Replay</span>' : '<span class="eyebrow">Concert en direct</span>') +
        '<h1>' + esc(ev.name) + '</h1>' +
        '<a class="ev__artist" href="#/artist/' + (a.id || ev.artist_id) + '">' + avatar(a.profile_image, artistName(a)) + '<span>' + esc(artistName(a)) + '</span></a>' +
        (guests.length ? '<p class="muted small">Avec ' + guests.join(', ') + '</p>' : '') +
        '<p><b>' + esc(when(ev.start_date_time)) + '</b> <span class="muted small">(heure de ton appareil)</span></p>' +
        '<div class="ev__box">' + (ev.has_ticket || over ? '' : '<div><span class="ev__price">' + esc(price(ev.ticket_price)) + '</span>' + next + '</div>') + action + '</div>' +
        (ev.description ? '<p class="ev__desc">' + esc(ev.description) + '</p>' : '') + '</div></div>';

      var fb = document.getElementById('evFree');
      if (fb) fb.onclick = function () {
        if (!S.token) { location.href = liveUrl(ev.id); return; } // réservation par e-mail sur la page live
        fb.disabled = true;
        api('/buy-ticket', { body: { event_id: ev.id } }).then(function (r) {
          if (r.status === 'success') { track('free_reserved_web'); toast('Ta place est réservée'); viewEvent(ev.id); }
          else { fb.disabled = false; toast(r.message || 'Réservation impossible, réessaie.'); }
        });
      };
      var bf = document.getElementById('evBuy');
      if (bf) bf.onsubmit = function (e) {
        e.preventDefault();
        var email = S.user && S.user.email ? S.user.email : (document.getElementById('evEmail') || {}).value, m = document.getElementById('evMsg'), btn = bf.querySelector('button');
        m.textContent = '';
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(email).trim())) { m.textContent = 'Entre une adresse e-mail valide.'; return; }
        btn.disabled = true;
        api('/tickets/web-checkout', { body: { event_id: ev.id, email: String(email).trim(), from: 'live' } }).then(function (r) {
          if (r.status === 'success' && r.data && r.data.url) { track('ticket_checkout'); location.href = r.data.url; return; }
          btn.disabled = false; m.textContent = r.message || 'Erreur, réessaie.';
        }).catch(function () { btn.disabled = false; m.textContent = 'Réseau indisponible, réessaie.'; });
      };
    });
  }

  // ── Billets ───────────────────────────────────────────────────────────────
  function viewTickets() {
    setTab('tickets'); document.title = 'Mes billets · VybzzZ';
    if (!S.token) { needLogin('Connecte-toi pour retrouver tes billets.', '#/tickets'); return; }
    $view.innerHTML = '<h1>Mes billets</h1><div class="list sec" id="tList"><div class="skel" style="height:100px"></div></div>';
    api('/user-event-history', { body: {} }).then(function (d) {
      var list = (d && (d.list || d.data)) || [], el = document.getElementById('tList'); if (!el) return;
      if (!list.length) { el.innerHTML = '<div class="empty">Pas encore de billet. <a class="link" href="#/">Voir les concerts</a></div>'; return; }
      list.sort(function (x, y) { return Date.parse(y.start_date_time) - Date.parse(x.start_date_time); });
      el.innerHTML = list.map(function (ev) {
        var live = isLive(ev), over = isOver(ev);
        return '<a class="item" href="' + (live || (over && ev.has_replay) ? liveUrl(ev.id) : '#/event/' + ev.id) + '"><div class="item__img" style="background-image:url(\'' + esc(cover(ev.cover_image)) + '\')"></div>' +
          '<div class="item__body"><div class="item__title">' + esc(ev.name) + '</div><div class="muted small">' + esc(artistName(ev.artist)) + ' · ' + esc(when(ev.start_date_time)) + '</div>' +
          '<div class="small" style="color:' + (live ? 'var(--live)' : 'var(--gold)') + ';font-weight:700">' + (live ? '● En direct : regarder' : over ? (ev.has_replay ? 'Replay disponible' : 'Terminé') : 'Place réservée') + '</div></div></a>';
      }).join('');
    });
  }

  // ── Artiste ───────────────────────────────────────────────────────────────
  function viewArtist(id) {
    setTab(''); $view.innerHTML = '<div class="skel" style="height:120px"></div>';
    Promise.all([api('/get-user', { body: { id: id } }), api('/artist/' + encodeURIComponent(id) + '/events'), api('/artist/' + encodeURIComponent(id) + '/clips'),
      S.token ? api('/following') : Promise.resolve(null)]).then(function (r) {
      var a = r[0] && r[0].data; if (!a) { $view.innerHTML = '<div class="empty">Artiste introuvable.</div>'; return; }
      var events = (r[1] && r[1].data) || [], clips = (r[2] && r[2].list) || [];
      var following = !!(r[3] && r[3].data && (r[3].data.following || []).some(function (u) { return String(u.id) === String(id); }));
      document.title = artistName(a) + ' · VybzzZ';
      var upcoming = events.filter(function (e) { return !isOver(e); }), past = events.filter(function (e) { return isOver(e) && e.has_replay && !e.replay_expired; });
      $view.innerHTML = '<div class="pro">' + avatar(a.profile_image, artistName(a)) + '<div style="display:grid;gap:6px;flex:1;min-width:200px"><h1>' + esc(artistName(a)) + '</h1>' +
        (a.bio ? '<p class="muted">' + esc(a.bio) + '</p>' : '') + '</div>' +
        '<button class="btn ' + (following ? 'btn-ghost' : 'btn-gold') + '" id="fBtn">' + (following ? 'Abonné ✓' : 'Suivre') + '</button></div>' +
        (upcoming.length ? '<section class="sec"><h2>Concerts</h2><div class="row">' + upcoming.map(eventCard).join('') + '</div></section>' : '') +
        (past.length ? '<section class="sec"><h2>Replays</h2><div class="row">' + past.map(eventCard).join('') + '</div></section>' : '') +
        (clips.length ? '<section class="sec"><h2>Clips</h2><div class="clipgrid">' + clips.map(function (c) {
          var th = c.thumbnail || (c.mux_playback_id ? 'https://image.mux.com/' + c.mux_playback_id + '/thumbnail.webp?width=360' : '');
          return '<a href="' + esc(c.video_url) + '" data-clip style="background-image:url(\'' + esc(th) + '\')" aria-label="' + esc(c.title || 'Clip') + '"></a>';
        }).join('') + '</div></section>' : '') +
        (!upcoming.length && !past.length && !clips.length ? '<div class="empty sec">Pas encore de concert ni de clip.</div>' : '');
      $view.querySelectorAll('[data-clip]').forEach(function (el) { el.onclick = function (e) { e.preventDefault(); playOverlay(el.getAttribute('href')); }; });
      var fb = document.getElementById('fBtn');
      fb.onclick = function () {
        if (!S.token) { location.hash = '#/login?next=' + encodeURIComponent('#/artist/' + id); return; }
        fb.disabled = true;
        api(following ? '/unfollow' : '/follow', { body: { artist_id: id } }).then(function (res) {
          fb.disabled = false;
          if (res.status === 'success') { following = !following; fb.className = 'btn ' + (following ? 'btn-ghost' : 'btn-gold'); fb.textContent = following ? 'Abonné ✓' : 'Suivre'; }
          else toast(res.message || 'Réessaie.');
        });
      };
    });
  }
  // Lecteur plein écran pour un clip de la fiche artiste.
  function playOverlay(url) {
    var o = document.createElement('div');
    o.style.cssText = 'position:fixed;inset:0;z-index:80;background:#000;display:grid;place-items:center';
    o.innerHTML = '<video playsinline controls autoplay style="max-width:100%;max-height:100%"></video><button class="round" style="position:absolute;top:16px;right:16px" aria-label="Fermer"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button>';
    document.body.appendChild(o);
    var v = o.querySelector('video'), h = null;
    if (window.Hls && window.Hls.isSupported() && /\.m3u8/.test(url)) { h = new window.Hls(); h.loadSource(url); h.attachMedia(v); } else v.src = url;
    function close() { try { h && h.destroy(); } catch (e) {} o.remove(); document.removeEventListener('keydown', onKey); }
    function onKey(e) { if (e.key === 'Escape') close(); }
    o.querySelector('button').onclick = close; document.addEventListener('keydown', onKey);
  }

  // ── Compte ────────────────────────────────────────────────────────────────
  function needLogin(text, next) {
    $view.innerHTML = '<div class="form-wrap center"><h2 style="justify-content:center">' + esc(text) + '</h2>' +
      '<a class="btn btn-gold btn-block" href="#/login?next=' + encodeURIComponent(next || '') + '">Me connecter</a>' +
      '<a class="btn btn-ghost btn-block" href="#/signup?next=' + encodeURIComponent(next || '') + '">Créer un compte</a></div>';
  }
  function viewAccount() {
    setTab('account'); document.title = 'Mon compte · VybzzZ';
    if (!S.token) { needLogin('Ton compte VybzzZ', '#/account'); return; }
    var u = S.user || {};
    function paint(u) {
      $view.innerHTML = '<div class="pro">' + avatar(u.profile_image, artistName(u)) + '<div style="display:grid;gap:4px"><h1>' + esc(u.full_name || u.artist_name || 'Mon compte') + '</h1>' +
        '<p class="muted">' + esc(u.email || '') + '</p>' + (u.is_verified ? '' : '<p class="small" style="color:var(--gold)">Adresse e-mail à confirmer : <a class="link" href="#/verify">entrer le code</a></p>') + '</div></div>' +
        '<div class="list sec">' +
        '<a class="item" href="#/tickets"><div class="item__body"><div class="item__title">Mes billets</div><div class="muted small">Tes concerts et replays</div></div>›</a>' +
        '<div class="item"><div class="item__body"><div class="item__title">Mes points</div><div class="muted small">' + esc(u.points != null ? u.points : '0') + ' points pour les cadeaux en live</div></div></div>' +
        (u.is_artist ? '<a class="item item--gold" href="#/studio"><div class="item__body"><div class="item__title">\uD83C\uDF99 Lancer un live</div><div class="small">Diffuse depuis ton navigateur : webcam, micro, un titre et c\'est parti.</div></div>›</a>' : '') +
        '<a class="item" href="../app.html"><div class="item__body"><div class="item__title">Télécharger l\'application</div><div class="muted small">Le même compte, sur iPhone et Android</div></div>›</a>' +
        '</div><div class="sec"><button class="btn btn-ghost" id="logout">Me déconnecter</button></div>';
      document.getElementById('logout').onclick = function () { S.clear(); renderTop(); toast('Tu es déconnecté'); location.hash = '#/'; };
    }
    paint(u);
    if (u.id) api('/get-user', { body: { id: u.id } }).then(function (d) { if (d && d.data) { S.set(null, d.data); renderTop(); if (location.hash.indexOf('#/account') === 0) paint(d.data); } });
  }

  // Studio artiste : l'écran vit dans studio.js, chargé seulement ici.
  var studioLoading;
  function viewStudio() {
    setTab('studio'); document.title = 'Studio · VybzzZ';
    if (window.VyStudio) return window.VyStudio.render();
    $view.innerHTML = '<div class="empty">Chargement du studio…</div>';
    if (!studioLoading) {
      studioLoading = new Promise(function (ok, ko) {
        var sc = document.createElement('script'); sc.src = 'studio.js?v=3'; sc.onload = ok; sc.onerror = ko; document.head.appendChild(sc);
      });
    }
    studioLoading.then(function () { if (location.hash.indexOf('#/studio') === 0 && window.VyStudio) window.VyStudio.render(); })
      .catch(function () { studioLoading = null; if (location.hash.indexOf('#/studio') === 0) $view.innerHTML = '<div class="empty">Impossible de charger le studio. Vérifie ta connexion puis <a class="link" href="#/studio" onclick="location.reload();return false">réessaie</a>.</div>'; });
  }

  // Retour après connexion : un écran de l'app web (#/…) ou la page du live
  // (/live.html?e=<id>). Rien d'autre (pas de redirection ouverte).
  function nextFrom(q) { var n = q.get('next') || ''; return (/^#\//.test(n) || /^\/live\.html\?e=\d+$/.test(n)) ? n : '#/'; }
  function go(next) { if (next.charAt(0) === '/') location.href = '..' + next; else location.hash = next; }
  function afterAuth(d, next) {
    S.set(d.token, d.data); renderTop();
    if (d.data && !d.data.is_verified) { location.hash = '#/verify?next=' + encodeURIComponent(next); return; }
    go(next);
  }
  function authForm(opts) {
    $view.innerHTML = '<div class="form-wrap"><h1 style="font-size:1.5rem">' + opts.title + '</h1>' + (opts.lead ? '<p class="muted">' + opts.lead + '</p>' : '') +
      '<form id="af" novalidate>' + opts.fields + '<button class="btn btn-gold btn-block" type="submit">' + opts.cta + '</button><div class="msg" id="afMsg" role="alert"></div></form>' +
      (opts.foot || '') + '</div>';
    var f = document.getElementById('af'), m = document.getElementById('afMsg');
    f.onsubmit = function (e) {
      e.preventDefault(); m.className = 'msg'; m.textContent = '';
      var btn = f.querySelector('button[type=submit]'); btn.disabled = true;
      opts.submit(function (id) { return (document.getElementById(id) || {}).value || ''; }, function (err, okText) {
        btn.disabled = false;
        if (okText) { m.className = 'msg ok'; m.textContent = okText; } else if (err) m.textContent = err;
      });
    };
    var first = f.querySelector('input'); if (first) first.focus();
  }
  function viewLogin(q) {
    setTab('account'); document.title = 'Connexion · VybzzZ';
    var next = nextFrom(q);
    authForm({
      title: 'Connexion', lead: 'Le même compte que dans l\'application VybzzZ.', cta: 'Me connecter',
      fields: '<label for="lEmail">E-mail</label><input id="lEmail" type="email" autocomplete="username" inputmode="email" required>' +
        '<label for="lPw">Mot de passe</label><input id="lPw" type="password" autocomplete="current-password" required>',
      foot: '<p class="center small"><a class="link" href="#/forgot">Mot de passe oublié ?</a></p><p class="center small muted">Pas encore de compte ? <a class="link" href="#/signup?next=' + encodeURIComponent(next) + '">Créer un compte</a></p>',
      submit: function (v, done) {
        api('/login', { body: { email: v('lEmail').trim(), password: v('lPw') }, auth: false }).then(function (d) {
          if (d.status === 'success' && d.token) { track('login_web'); afterAuth(d, next); return; }
          if (d.code === 'no_account') return done('Aucun compte avec cet e-mail. Crée ton compte en un instant.');
          done(d.message || 'Connexion impossible.');
        }).catch(function () { done('Réseau indisponible, réessaie.'); });
      },
    });
  }
  function viewSignup(q) {
    setTab('account'); document.title = 'Créer un compte · VybzzZ';
    var next = nextFrom(q);
    authForm({
      title: 'Créer un compte', lead: 'Gratuit. Tu pourras aussi l\'utiliser dans l\'application.', cta: 'Créer mon compte',
      fields: '<label for="sName">Prénom</label><input id="sName" autocomplete="given-name" maxlength="60">' +
        '<label for="sEmail">E-mail</label><input id="sEmail" type="email" autocomplete="email" inputmode="email" required>' +
        '<label for="sPw">Mot de passe (8 caractères minimum)</label><input id="sPw" type="password" autocomplete="new-password" minlength="8" required>',
      foot: '<p class="center small muted">Déjà un compte ? <a class="link" href="#/login?next=' + encodeURIComponent(next) + '">Me connecter</a></p>' +
        '<p class="center small muted">En créant un compte, tu acceptes les <a class="link" href="../cgu.html">conditions</a> et la <a class="link" href="../confidentialite.html">politique de confidentialité</a>.</p>',
      submit: function (v, done) {
        var email = v('sEmail').trim(), pw = v('sPw');
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return done('Entre une adresse e-mail valide.');
        if (pw.length < 8) return done('Le mot de passe doit faire 8 caractères au moins.');
        api('/sign-up', { body: { email: email, password: pw, full_name: v('sName').trim(), registration_type: 'email' }, auth: false }).then(function (d) {
          if (d.status === 'success' && d.token) { track('signup_web'); afterAuth(d, next); return; }
          var e = d.errors && d.errors.email && d.errors.email[0];
          done(e || d.message || 'Inscription impossible.');
        }).catch(function () { done('Réseau indisponible, réessaie.'); });
      },
    });
  }
  function viewVerify(q) {
    setTab('account'); document.title = 'Confirmer mon e-mail · VybzzZ';
    var next = nextFrom(q), u = S.user || {};
    if (!S.token) { location.hash = '#/login'; return; }
    if (u.is_verified) { go(next); return; } // compte déjà actif : rien à confirmer
    authForm({
      title: 'Confirme ton e-mail', lead: 'On a envoyé un code à <b>' + esc(u.email || 'ton adresse') + '</b>. Tu peux aussi cliquer sur le lien de l\'e-mail.', cta: 'Valider',
      fields: '<label for="vCode">Code reçu par e-mail</label><input id="vCode" inputmode="numeric" autocomplete="one-time-code" maxlength="8" required>',
      foot: '<p class="center small"><a class="link" href="' + esc(next.charAt(0) === '/' ? '..' + next : next) + '">Plus tard</a></p>',
      submit: function (v, done) {
        api('/verify', { body: { email: u.email, otp_code: v('vCode').trim() } }).then(function (d) {
          if (d.status === 'success') { S.set(d.token, d.data); renderTop(); toast('Adresse confirmée'); go(next); return; }
          done(d.message || 'Code incorrect.');
        }).catch(function () { done('Réseau indisponible, réessaie.'); });
      },
    });
  }
  function viewForgot() {
    setTab('account'); document.title = 'Mot de passe oublié · VybzzZ';
    var sentTo = null;
    authForm({
      title: 'Mot de passe oublié', lead: 'On t\'envoie un code par e-mail pour choisir un nouveau mot de passe.', cta: 'Recevoir le code',
      fields: '<label for="fEmail">E-mail</label><input id="fEmail" type="email" autocomplete="email" inputmode="email" required>' +
        '<div id="fStep2" hidden style="display:grid;gap:10px"><label for="fCode">Code reçu</label><input id="fCode" inputmode="numeric" autocomplete="one-time-code">' +
        '<label for="fPw">Nouveau mot de passe</label><input id="fPw" type="password" autocomplete="new-password" minlength="8"></div>',
      submit: function (v, done) {
        var email = v('fEmail').trim();
        if (!sentTo) {
          api('/forget', { body: { email: email }, auth: false }).then(function (d) {
            if (d.status === 'success') { sentTo = email; document.getElementById('fStep2').hidden = false; document.querySelector('#af button[type=submit]').textContent = 'Changer mon mot de passe'; done(null, 'Code envoyé. Pense aux indésirables.'); }
            else done(d.message || 'Envoi impossible.');
          }).catch(function () { done('Réseau indisponible, réessaie.'); });
          return;
        }
        if (v('fPw').length < 8) return done('Le mot de passe doit faire 8 caractères au moins.');
        api('/reset-password', { body: { email: sentTo, otp_code: v('fCode').trim(), password: v('fPw') }, auth: false }).then(function (d) {
          if (d.status === 'success') { toast('Mot de passe changé, connecte-toi'); location.hash = '#/login'; return; }
          done(d.message || 'Code incorrect.');
        }).catch(function () { done('Réseau indisponible, réessaie.'); });
      },
    });
  }

  // ── Routeur ───────────────────────────────────────────────────────────────
  function route() {
    var h = location.hash || '#/', qi = h.indexOf('?');
    var path = (qi >= 0 ? h.slice(0, qi) : h).replace(/^#/, '') || '/';
    var q = new URLSearchParams(qi >= 0 ? h.slice(qi + 1) : '');
    var parts = path.split('/').filter(Boolean);
    if (parts[0] !== 'feed') stopFeed();
    // Un live est en cours : on ne quitte le studio qu'avec l'accord de l'artiste.
    if (parts[0] !== 'studio' && window.VyStudio && !window.VyStudio.leave()) { history.replaceState(null, '', '#/studio'); return; }
    window.scrollTo(0, 0);
    switch (parts[0]) {
      case undefined: return viewHome();
      case 'feed': stopFeed(); return viewFeed(parts[1]);
      case 'event': return viewEvent(parts[1]);
      case 'artist': return viewArtist(parts[1]);
      case 'tickets': return viewTickets();
      case 'account': return viewAccount();
      case 'studio': return viewStudio();
      case 'login': return viewLogin(q);
      case 'signup': return viewSignup(q);
      case 'verify': return viewVerify(q);
      case 'forgot': return viewForgot();
      default: return viewHome();
    }
  }
  window.addEventListener('hashchange', route);
  renderTop();
  route();
})();

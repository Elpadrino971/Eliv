/* VybzzZ web — Studio : l'artiste lance un live depuis son navigateur.
 * Chargé à la demande par app.js (route #/studio). Caméra + micro → MediaRecorder
 * → WebSocket d'ingestion (le serveur transcode avec ffmpeg et diffuse).
 * Contrat API : GET /studio/status, GET /studio/events (concerts programmés de l'artiste),
 * GET /studio/live/current, POST /studio/live ({title,price,replay} ou {event_id}),
 * POST /studio/live/:id/stop ; chat via /event-logs (lecture) et /event-comment.
 */
(function () {
  'use strict';
  var W = window.VyWeb;
  if (!W) return;
  var api = W.api, esc = W.esc, toast = W.toast, S = W.S;

  var QUALITIES = {
    '480': { w: 854, h: 480, fps: 30, vbps: 1200000, label: '480p · léger' },
    '720': { w: 1280, h: 720, fps: 30, vbps: 2500000, label: '720p · recommandé' },
    '1080': { w: 1920, h: 1080, fps: 30, vbps: 5000000, label: '1080p · connexion rapide' },
  };
  var AUDIO_BPS = 128000;
  var PRICES = [0, 2.99, 4.99, 6.99, 9.99, 14.99, 19.99, 29.99, 49.99, 99.99];
  var MIMES = [
    'video/webm;codecs=h264,opus',
    'video/webm;codecs=avc1,opus',
    'video/mp4;codecs=avc1.42E01E,mp4a.40.2',
    'video/webm;codecs=vp8,opus',
    'video/webm',
  ];
  var MAX_BUFFER = 4 * 1024 * 1024;   // au-delà, on n'envoie plus (connexion trop lente)
  var GIVE_UP_MS = 60000;             // durée totale de reconnexion avant abandon
  var SLOW_RESYNC_MS = 15000;         // lenteur continue → on repart sur une connexion neuve
  var READY_TIMEOUT_MS = 15000;       // le serveur doit répondre {ready} après l'ouverture
  var CHAT_POLL_MS = 5000;

  var cur = null; // contexte de l'écran actif

  function pickMime() {
    if (typeof MediaRecorder === 'undefined' || !MediaRecorder.isTypeSupported) return '';
    for (var i = 0; i < MIMES.length; i++) { try { if (MediaRecorder.isTypeSupported(MIMES[i])) return MIMES[i]; } catch (e) {} }
    return '';
  }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function fmtDur(s) {
    s = Math.max(0, Math.floor(s)); var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return (h ? h + ':' + pad(m) : pad(m)) + ':' + pad(s % 60);
  }
  function fmtMo(b) { return (b / 1048576).toFixed(1).replace('.', ',') + ' Mo'; }
  function priceLabel(p) { return p > 0 ? p.toFixed(2).replace('.', ',') + ' €' : 'Gratuit'; }
  function $(id) { return document.getElementById(id); }
  function isCoarse() { try { return window.matchMedia('(pointer:coarse)').matches; } catch (e) { return false; } }
  function msgOf(d, fallback) { return (d && d.message) ? String(d.message) : fallback; }

  // ── Erreurs caméra expliquées ─────────────────────────────────────────────
  function mediaError(e) {
    var n = e && e.name;
    if (n === 'NotAllowedError' || n === 'SecurityError' || n === 'PermissionDeniedError') {
      return 'Accès à la caméra et au micro refusé. Clique sur l\'icône de cadenas (ou de caméra) à gauche de la barre d\'adresse, autorise la caméra et le micro pour ce site, puis appuie sur « Réessayer ». Sur iPhone : Réglages > Safari > Caméra et Micro.';
    }
    if (n === 'NotFoundError' || n === 'DevicesNotFoundError') return 'Aucune caméra ou aucun micro détecté. Branche-en un (ou active-le dans les réglages de ton appareil), puis appuie sur « Réessayer ».';
    if (n === 'NotReadableError' || n === 'TrackStartError' || n === 'AbortError') return 'La caméra ou le micro est déjà utilisé par une autre application ou un autre onglet. Ferme-les puis appuie sur « Réessayer ».';
    if (n === 'OverconstrainedError') return 'Cette caméra ne gère pas la qualité choisie. Choisis une qualité plus basse.';
    return 'Impossible d\'accéder à la caméra (' + (n || 'erreur inconnue') + '). Essaie avec une version récente de Chrome ou de Safari.';
  }

  // ── Écrans simples (sans diffusion) ───────────────────────────────────────
  function simple(html) {
    W.view.innerHTML = '<div class="form-wrap center">' + html + '</div>';
  }
  function closedScreen() { simple('<h2 style="justify-content:center">Le studio arrive bientôt</h2><p class="muted">La diffusion depuis le navigateur n\'est pas encore ouverte.</p><a class="btn btn-ghost btn-block" href="#/account">Retour</a>'); }
  function notArtistScreen() {
    simple('<h2 style="justify-content:center">Le studio est réservé aux artistes</h2>' +
      '<p class="muted">Pour diffuser, ton compte doit avoir le statut artiste. Tu peux le demander dans l\'application VybzzZ (section Profil), puis revenir ici : tu retrouveras le même compte.</p>' +
      '<a class="btn btn-gold btn-block" href="../app.html">Ouvrir l\'application</a><a class="btn btn-ghost btn-block" href="#/account">Retour</a>');
  }
  function unsupportedScreen(why) {
    simple('<h2 style="justify-content:center">Navigateur non compatible</h2><p class="muted">' + esc(why) + '</p><p class="muted small">Utilise une version récente de Chrome (ordinateur ou Android) ou de Safari (iPhone, iPad, Mac).</p><a class="btn btn-ghost btn-block" href="#/account">Retour</a>');
  }

  // ── Point d'entrée ────────────────────────────────────────────────────────
  function render() {
    if (cur) teardown(cur, false);
    var X = cur = {
      dead: false, state: 'loading', stream: null, rec: null, ws: null, mime: '',
      q: '720', facing: 'user', camId: '', micId: '', cams: [], mics: [],
      title: '', price: 0, replay: true, current: null,
      events: [], mode: 'new', evId: null, existing: false,
      micOff: false, camOff: false, ending: false, everLive: false, liveSince: 0,
      eventId: null, ingest: null, watchUrl: '', webUrl: '', createBody: null,
      attempt: 0, cycleStart: 0, retryTimer: 0, readyTimer: 0, tick: 0, chatTimer: 0,
      bytes: 0, lastBytes: 0, kbps: 0, srvKbps: 0, srvAt: 0, slowSince: 0, lastChatKey: '', chat: [],
      wake: null, formErr: '', permErr: '', busy: false, endMsg: '', endedBy: '',
    };
    if (!S.token) { W.needLogin('Connecte-toi pour lancer un live', '#/studio'); return; }
    W.view.innerHTML = '<div class="empty">Chargement du studio…</div>';
    var u = S.user || {};
    var userP = u.is_artist ? Promise.resolve(u) : (u.id ? api('/get-user', { body: { id: u.id } }).then(function (d) { if (d && d.data) { S.set(null, d.data); W.renderTop(); return d.data; } return u; }).catch(function () { return u; }) : Promise.resolve(u));
    userP.then(function (user) {
      if (X.dead) return;
      if (!user || !user.is_artist) { notArtistScreen(); return; }
      X.user = user;
      return api('/studio/status', { auth: false }).then(function (d) {
        if (X.dead) return;
        var st = d && d.data;
        if (!st || !st.enabled || !st.ffmpeg) { closedScreen(); return; }
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) { unsupportedScreen('Ce navigateur ne donne pas accès à la caméra (ou la page n\'est pas sécurisée).'); return; }
        X.mime = pickMime();
        if (!X.mime) { unsupportedScreen('Ce navigateur ne sait pas enregistrer la vidéo pour la diffuser.'); return; }
        X.title = ('Live de ' + W.artistName(user)).slice(0, 80);
        return api('/studio/live/current').then(function (c) { if (c && c.data && c.data.event_id) X.current = c.data; }, function () {}).then(function () {
          // Concerts programmés de l'artiste (plan de secours). Échec ou liste vide : écran habituel.
          if (X.dead || X.current) return;
          return api('/studio/events').then(function (d) { if (d && d.status === 'success' && Array.isArray(d.data)) setEvents(X, d.data); }, function () {});
        }).then(function () {
          if (X.dead) return;
          buildShell(X); setState(X, 'setup'); acquire(X);
        });
      });
    }).catch(function () { if (!X.dead) simple('<h2 style="justify-content:center">Réseau indisponible</h2><p class="muted">Impossible de joindre VybzzZ. Vérifie ta connexion puis réessaie.</p><a class="btn btn-gold btn-block" href="#/studio" onclick="location.reload();return false">Réessayer</a>'); });
  }

  // ── Squelette de l'écran (le <video> ne bouge plus ensuite) ───────────────
  function buildShell(X) {
    W.view.innerHTML =
      '<div class="studio" id="stRoot">' +
      '<div class="st-col">' +
      '<div class="st-stage"><video id="stVideo" muted playsinline autoplay aria-label="Aperçu de ta caméra"></video>' +
      '<div class="st-ov" id="stOv">Autorise la caméra pour voir l\'aperçu</div>' +
      '<div class="st-badges"><span class="st-live" id="stBadge" hidden><span class="dot-live" style="background:#fff"></span>EN DIRECT</span><span id="stTimer" hidden>00:00</span></div>' +
      '<div class="st-banner" id="stBanner" role="status" hidden></div></div>' +
      '<div id="stPanel"></div></div>' +
      '<aside class="st-chat" id="stChat" hidden aria-label="Chat du live"><h2>Chat du live</h2><ul class="st-log" id="stLog" role="log" aria-live="polite"></ul>' +
      '<form class="st-send" id="stSend"><input id="stMsg" maxlength="200" placeholder="Écris au public…" aria-label="Ton message" autocomplete="off"><button class="btn btn-gold" type="submit">Envoyer</button></form></aside>' +
      '</div>';
    $('stSend').onsubmit = function (e) { e.preventDefault(); sendChat(X); };
  }

  function setState(X, s) {
    X.state = s;
    var root = $('stRoot'); if (!root) return;
    root.classList.toggle('has-chat', s === 'live');
    $('stChat').hidden = s !== 'live';
    var live = s === 'live';
    $('stBadge').hidden = !live; $('stTimer').hidden = !live;
    paint(X);
  }

  function setBanner(X, text, isErr) {
    var b = $('stBanner'); if (!b) return;
    if (!text) { b.hidden = true; b.textContent = ''; return; }
    b.hidden = false; b.textContent = text; b.className = 'st-banner' + (isErr ? ' err' : '');
  }
  function setOverlay(text) { var o = $('stOv'); if (!o) return; o.hidden = !text; o.textContent = text || ''; }

  // ── Panneaux par état ─────────────────────────────────────────────────────
  function paint(X) {
    var p = $('stPanel'); if (!p) return;
    var focusId = document.activeElement && document.activeElement.id;
    if (X.state === 'setup') paintSetup(X, p);
    else if (X.state === 'connecting') {
      p.innerHTML = '<div class="st-card center" aria-live="polite"><div class="st-spin" role="img" aria-label="Chargement"></div><h2 style="justify-content:center;margin:0" id="stConnTxt">' + (X.everLive ? 'Reconnexion…' : 'Connexion au direct…') + '</h2><p class="muted small" id="stConnSub">Ne ferme pas cet onglet.</p><button class="btn btn-ghost btn-block" id="stCancel">Annuler</button></div>';
      $('stCancel').onclick = function () { endLive(X, true); };
    } else if (X.state === 'live') paintLive(X, p);
    else if (X.state === 'failed') {
      p.innerHTML = '<div class="st-card"><h2 style="margin:0">Connexion perdue</h2><p class="msg">' + esc(X.endMsg || 'Impossible de rétablir la connexion.') + '</p>' +
        '<button class="btn btn-gold btn-block" id="stRetry">Réessayer</button><button class="btn btn-live btn-block" id="stStop">Terminer le live</button></div>';
      $('stRetry').onclick = function () { startCycle(X); };
      $('stStop').onclick = function () { endLive(X, true); };
    } else if (X.state === 'ended') paintEnded(X);
    var f = focusId && $(focusId); if (f && f.focus) { try { f.focus(); } catch (e) {} }
  }

  function opt(v, label, sel) { return '<option value="' + esc(v) + '"' + (sel ? ' selected' : '') + '>' + esc(label) + '</option>'; }

  // ── Concert programmé (secours) ───────────────────────────────────────────
  function setEvents(X, list) {
    X.events = list.filter(function (e) { return e && e.id && e.name; });
    if (!X.events.length) return;
    X.evId = X.events[0].id;
    // Un concert qui démarre dans moins de 3 h (ou déjà commencé) : c'est sans doute celui qu'on veut lancer.
    var soon = X.events.some(function (e) { var t = Date.parse(e.start_date_time); return isFinite(t) && t - Date.now() < 3 * 3600 * 1000; });
    X.mode = soon ? 'event' : 'new';
    if (soon) {
      X.evId = X.events.slice().sort(function (a, b) { return Math.abs(Date.parse(a.start_date_time) - Date.now()) - Math.abs(Date.parse(b.start_date_time) - Date.now()); })[0].id;
    }
  }
  function evById(X, id) { for (var i = 0; i < X.events.length; i++) if (String(X.events[i].id) === String(id)) return X.events[i]; return null; }
  function fmtEvDate(iso) {
    var d = new Date(iso); if (isNaN(d)) return '';
    try { return d.toLocaleString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }); } catch (e) { return d.toString(); }
  }
  function soldLabel(n) { n = +n || 0; return n + (n > 1 ? ' billets vendus' : ' billet vendu'); }
  function evLabel(e) { return e.name + ' · ' + fmtEvDate(e.start_date_time) + ' · ' + soldLabel(e.tickets_sold); }

  function paintSetup(X, p) {
    var resume = !!X.current;
    var evMode = !resume && X.events.length > 0 && X.mode === 'event';
    var camPick = X.cams.length > 1 ? '<div class="st-f"><label for="stCamSel">Caméra</label><select id="stCamSel">' + X.cams.map(function (d, i) { return opt(d.deviceId, d.label || ('Caméra ' + (i + 1)), d.deviceId === X.camId); }).join('') + '</select></div>' : '';
    var micPick = X.mics.length > 1 ? '<div class="st-f"><label for="stMicSel">Micro</label><select id="stMicSel">' + X.mics.map(function (d, i) { return opt(d.deviceId, d.label || ('Micro ' + (i + 1)), d.deviceId === X.micId); }).join('') + '</select></div>' : '';
    var flip = isCoarse() && X.cams.length > 1 ? '<button type="button" class="btn btn-ghost" id="stFlip">Retourner la caméra</button>' : '';
    // L'aperçu est en miroir (comme toute webcam) : les fans, eux, voient
    // l'image réelle. Ce bouton coupe le miroir pour voir ce qu'ils voient.
    flip += '<button type="button" class="btn btn-ghost" id="stMirror" aria-pressed="' + (X.noMirror ? 'false' : 'true') + '" title="L\'aperçu seulement : les fans voient toujours l\'image réelle">' + (X.noMirror ? 'Aperçu réel' : 'Aperçu miroir') + '</button>';
    var qual = '<div class="st-f"><label for="stQ">Qualité</label><select id="stQ">' + Object.keys(QUALITIES).map(function (k) { return opt(k, QUALITIES[k].label, k === X.q); }).join('') + '</select></div>';
    var seg = !resume && X.events.length ? '<div class="st-seg" role="group" aria-label="Type de live">' +
      '<button type="button" id="stModeNew" aria-pressed="' + !evMode + '">Nouveau live instantané</button>' +
      '<button type="button" id="stModeEv" aria-pressed="' + evMode + '">Mon concert programmé</button></div>' : '';
    var evForm = evMode ? '<div class="st-f"><label for="stEvSel">Mon concert</label><select id="stEvSel">' +
      X.events.map(function (e) { return opt(e.id, evLabel(e), String(e.id) === String(X.evId)); }).join('') + '</select></div>' +
      '<p class="st-note">Les fans qui ont acheté leur place verront ton live sur le site et dans l\'app.</p>' +
      '<p class="muted small">Ne lance pas aussi la diffusion depuis l\'application : une seule source à la fois.</p>' : '';
    var title = resume || X.events.length && evMode ? '' : '<div class="st-f"><label for="stTitle">Titre du live</label><input id="stTitle" maxlength="80" required placeholder="Ex. : Session acoustique" value="' + esc(X.title) + '" autocomplete="off"></div>' +
      '<div class="st-grid"><div class="st-f"><label for="stPrice">Prix d\'entrée</label><select id="stPrice">' + PRICES.map(function (v) { return opt(v, priceLabel(v), v === X.price); }).join('') + '</select></div>' +
      '<div class="st-f" style="align-self:end"><label class="st-switch"><input type="checkbox" id="stReplay"' + (X.replay ? ' checked' : '') + '> Replay activé</label></div></div>';
    var banner = resume ? '<div class="st-banner" style="position:static;border-color:var(--gold)">' + (X.current.existing ? 'Ton concert programmé est déjà ouvert' : 'Un live est déjà ouvert') + ' sur ton compte (' + (X.current.state === 'live' ? 'en direct' : 'préparé') + '). Reprends-le ou termine-le.</div>' : '';
    var goLabel = resume ? 'Reprendre le live' : evMode ? 'Lancer mon concert' : 'Lancer le live';
    p.innerHTML = '<div class="st-card"><h1>' + (resume ? 'Reprendre ton live' : evMode ? 'Lancer mon concert' : 'Lancer un live') + '</h1>' + banner + seg +
      (X.permErr ? '<p class="msg" role="alert">' + esc(X.permErr) + '</p><button class="btn btn-ghost" id="stRetryCam" type="button">Réessayer</button>' : '') +
      '<div class="st-grid">' + camPick + micPick + qual + '</div>' + flip + evForm + title +
      '<p class="msg" id="stMsg2" role="alert">' + esc(X.formErr) + '</p>' +
      '<button class="btn btn-gold btn-block" id="stGo"' + (X.stream && !X.busy ? '' : ' disabled') + '>' + goLabel + '</button>' +
      (resume ? '<button class="btn btn-ghost btn-block" id="stEndOld" type="button">Terminer ce live</button>' : '') + '</div>';

    function on(id, ev, fn) { var el = $(id); if (el) el['on' + ev] = fn; }
    on('stRetryCam', 'click', function () { acquire(X); });
    on('stCamSel', 'change', function () { X.camId = this.value; acquire(X); });
    on('stMicSel', 'change', function () { X.micId = this.value; acquire(X); });
    on('stFlip', 'click', function () { X.facing = X.facing === 'user' ? 'environment' : 'user'; X.camId = ''; acquire(X); });
    on('stMirror', 'click', function () { X.noMirror = !X.noMirror; applyMirror(X); var b = $('stMirror'); if (b) { b.textContent = X.noMirror ? 'Aperçu réel' : 'Aperçu miroir'; b.setAttribute('aria-pressed', X.noMirror ? 'false' : 'true'); } });
    on('stQ', 'change', function () { X.q = this.value; acquire(X); });
    on('stModeNew', 'click', function () { X.mode = 'new'; X.formErr = ''; paint(X); });
    on('stModeEv', 'click', function () { X.mode = 'event'; X.formErr = ''; paint(X); });
    on('stEvSel', 'change', function () { X.evId = this.value; });
    on('stTitle', 'input', function () { X.title = this.value; });
    on('stPrice', 'change', function () { X.price = parseFloat(this.value) || 0; });
    on('stReplay', 'change', function () { X.replay = this.checked; });
    on('stGo', 'click', function () { start(X); });
    on('stEndOld', 'click', function () {
      X.busy = true; X.formErr = ''; paint(X);
      stopRequest(X.current.event_id).then(function (ok) { X.busy = false; if (ok) X.current = null; else X.formErr = 'Impossible de terminer ce live pour le moment. Réessaie.'; if (!X.dead) paint(X); });
    });
  }

  function paintLive(X, p) {
    p.innerHTML = '<div class="st-card">' +
      '<div class="st-stats" id="stStats"></div>' +
      '<div class="st-ctl"><button class="btn btn-ghost" id="stMic" aria-pressed="' + X.micOff + '">' + (X.micOff ? 'Réactiver le micro' : 'Couper le micro') + '</button>' +
      '<button class="btn btn-ghost" id="stCamBtn" aria-pressed="' + X.camOff + '">' + (X.camOff ? 'Réactiver la caméra' : 'Couper la caméra') + '</button></div>' +
      '<button class="btn btn-ghost btn-block" id="stShare">Partager le lien</button>' +
      '<p class="muted small">Garde cet onglet ouvert et au premier plan pendant le live.</p>' +
      '<div id="stEnd"><button class="btn btn-live btn-block" id="stStop">Terminer le live</button></div></div>';
    $('stMic').onclick = function () { toggleTrack(X, 'audio'); };
    $('stCamBtn').onclick = function () { toggleTrack(X, 'video'); };
    $('stShare').onclick = function () { share(X); };
    $('stStop').onclick = function () {
      $('stEnd').innerHTML = '<p style="margin-bottom:10px">Terminer le live pour tous tes spectateurs ?</p><div class="st-ctl"><button class="btn btn-live" id="stYes">Oui, terminer</button><button class="btn btn-ghost" id="stNo">Continuer</button></div>';
      $('stYes').onclick = function () { endLive(X, true); };
      $('stNo').onclick = function () { paintLive(X, $('stPanel')); $('stStop').focus(); };
      $('stNo').focus();
    };
    updateStats(X);
  }

  function paintEnded(X) {
    var dur = X.liveSince ? fmtDur((X.endedAt - X.liveSince) / 1000) : '00:00';
    $('stRoot').querySelector('.st-stage').hidden = true;
    $('stPanel').innerHTML = '<div class="st-card center"><h1>Live terminé</h1>' +
      '<p class="muted">' + esc(X.title || '') + '</p>' +
      '<p><strong>Durée : ' + esc(dur) + '</strong>' + (X.bytes ? ' · ' + esc(fmtMo(X.bytes)) + ' envoyés' : '') + '</p>' +
      (X.endMsg ? '<p class="msg">' + esc(X.endMsg) + '</p>' : '') +
      '<p class="muted small">' + (X.replay && X.eventId ? 'Le replay sera disponible sur la page du concert dans quelques minutes.' : 'Merci pour ce direct !') + '</p>' +
      (X.replay && X.eventId ? '<a class="btn btn-ghost btn-block" href="#/event/' + encodeURIComponent(X.eventId) + '">Voir la page du concert</a>' : '') +
      '<a class="btn btn-gold btn-block" href="#/account" id="stBack">Retour</a></div>';
  }

  // ── Caméra / micro ────────────────────────────────────────────────────────
  function stopTracks(X) {
    if (X.stream) { X.stream.getTracks().forEach(function (t) { t.onended = null; try { t.stop(); } catch (e) {} }); X.stream = null; }
  }
  // Miroir de l'aperçu uniquement (CSS) ; le flux envoyé n'est jamais inversé.
  function applyMirror(X) { var v = $('stVideo'); if (v) v.classList.toggle('mirror', !X.rearCam && !X.noMirror); }

  function acquire(X) {
    if (X.dead) return;
    stopTracks(X);
    X.permErr = ''; X.busy = true; setOverlay('Autorisation de la caméra…'); paint(X);
    var q = QUALITIES[X.q];
    var vid = { width: { ideal: q.w }, height: { ideal: q.h }, frameRate: { ideal: q.fps } };
    if (X.camId) vid.deviceId = { exact: X.camId }; else vid.facingMode = { ideal: X.facing };
    var aud = { echoCancellation: true, noiseSuppression: true, autoGainControl: true };
    if (X.micId) aud.deviceId = { exact: X.micId };
    var gum = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    gum({ video: vid, audio: aud }).catch(function (e) {
      if (e && (e.name === 'OverconstrainedError' || e.name === 'NotFoundError') && (X.camId || X.micId)) { X.camId = ''; X.micId = ''; return gum({ video: true, audio: true }); }
      throw e;
    }).then(function (s) {
      if (X.dead) { s.getTracks().forEach(function (t) { t.stop(); }); return; }
      X.stream = s;
      s.getAudioTracks().forEach(function (t) { t.enabled = !X.micOff; });
      s.getVideoTracks().forEach(function (t) { t.enabled = !X.camOff; t.onended = function () { if (X.stream === s && !X.ending) setBanner(X, 'La caméra s\'est arrêtée. Vérifie qu\'elle est branchée.', true); }; });
      var v = $('stVideo'); v.srcObject = s; var pr = v.play(); if (pr && pr.catch) pr.catch(function () {});
      var vt = s.getVideoTracks()[0], st = vt && vt.getSettings ? vt.getSettings() : {};
      if (st.deviceId) X.camId = st.deviceId;
      var at = s.getAudioTracks()[0]; if (at && at.getSettings && at.getSettings().deviceId) X.micId = at.getSettings().deviceId;
      X.rearCam = st.facingMode === 'environment'; applyMirror(X);
      setOverlay(''); X.busy = false;
      return navigator.mediaDevices.enumerateDevices().then(function (list) {
        X.cams = list.filter(function (d) { return d.kind === 'videoinput'; });
        X.mics = list.filter(function (d) { return d.kind === 'audioinput'; });
      }, function () {});
    }).then(function () { if (!X.dead && X.state === 'setup') paint(X); }, function (e) {
      if (X.dead) return;
      X.busy = false; X.permErr = mediaError(e); setOverlay('Caméra indisponible');
      if (X.state === 'setup') paint(X);
    });
  }

  function toggleTrack(X, kind) {
    if (!X.stream) return;
    var off = kind === 'audio' ? (X.micOff = !X.micOff) : (X.camOff = !X.camOff);
    (kind === 'audio' ? X.stream.getAudioTracks() : X.stream.getVideoTracks()).forEach(function (t) { t.enabled = !off; });
    if (kind === 'video') setOverlay(off ? 'Caméra coupée' : '');
    paintLive(X, $('stPanel'));
    var b = $(kind === 'audio' ? 'stMic' : 'stCamBtn'); if (b) b.focus();
  }

  // ── Démarrage ─────────────────────────────────────────────────────────────
  function start(X) {
    if (X.busy || !X.stream) return;
    X.formErr = '';
    if (X.current) {
      X.eventId = X.current.event_id; X.ingest = null;
      X.existing = !!X.current.existing;
      if (X.existing) { var ce = X.current.event || {}; if (ce.name) X.title = ce.name; if (ce.replay_enabled !== undefined) X.replay = !!ce.replay_enabled; }
      X.createBody = X.existing ? { event_id: X.current.event_id } : { title: (X.title || 'Live').slice(0, 80), price: 0, replay: X.replay };
      X.watchUrl = ''; X.webUrl = '';
      return beginConnect(X);
    }
    if (X.mode === 'event' && X.events.length) return startExisting(X);
    var title = (X.title || '').trim();
    if (!title) { X.formErr = 'Donne un titre à ton live pour continuer.'; paint(X); $('stTitle').focus(); return; }
    if (title.length > 80) title = title.slice(0, 80);
    X.title = title; X.busy = true; paint(X);
    var body = { title: title, price: X.price || 0 }; if (X.replay) body.replay = true;
    X.createBody = body;
    api('/studio/live', { body: body }).then(function (d) {
      if (X.dead) return;
      X.busy = false;
      var dd = d && d.data;
      if (d && d.status === 'success' && dd && dd.ingest) {
        X.eventId = dd.event_id; X.ingest = dd.ingest; X.watchUrl = dd.watch_url || ''; X.webUrl = dd.web_url || '';
        return beginConnect(X);
      }
      if (d && d._code === 409 && dd && dd.event_id) { X.current = { event_id: dd.event_id, state: 'live' }; X.formErr = 'Tu as déjà un live ouvert : reprends-le ou termine-le.'; }
      else if (d && d._code === 403) X.formErr = 'Ton compte n\'a pas le statut artiste : tu ne peux pas lancer de live.';
      else if (d && d._code === 429) X.formErr = 'Trop de tentatives. Patiente quelques minutes puis réessaie.';
      else if (d && d._code === 401) X.formErr = 'Ta session a expiré. Reconnecte-toi puis réessaie.';
      else X.formErr = msgOf(d, 'Le live n\'a pas pu démarrer. Réessaie dans un instant.');
      paint(X);
    }).catch(function () { if (X.dead) return; X.busy = false; X.formErr = 'Réseau indisponible. Vérifie ta connexion puis réessaie.'; paint(X); });
  }

  // Lancer le concert programmé choisi : titre, prix et replay viennent de l'évènement.
  function startExisting(X) {
    var ev = evById(X, X.evId) || X.events[0];
    X.title = ev.name; X.busy = true; X.formErr = ''; paint(X);
    var body = { event_id: ev.id };
    X.createBody = body;
    api('/studio/live', { body: body }).then(function (d) {
      if (X.dead) return;
      X.busy = false;
      var dd = d && d.data;
      if (d && d.status === 'success' && dd && dd.ingest) {
        X.eventId = dd.event_id; X.ingest = dd.ingest; X.watchUrl = dd.watch_url || ''; X.webUrl = dd.web_url || ''; X.existing = true;
        X.replay = !(dd.event && dd.event.replay_enabled === false);
        return beginConnect(X);
      }
      if (d && d._code === 409 && dd && dd.event_id) { X.current = { event_id: dd.event_id, state: dd.state || 'live', existing: !!dd.existing, event: dd.event }; X.formErr = 'Tu as déjà un live ouvert : reprends-le ou termine-le.'; }
      else if (d && d._code === 403) X.formErr = msgOf(d, 'Tu ne peux pas lancer ce concert avec ce compte.');
      else if (d && d._code === 429) X.formErr = 'Trop de tentatives. Patiente quelques minutes puis réessaie.';
      else if (d && d._code === 401) X.formErr = 'Ta session a expiré. Reconnecte-toi puis réessaie.';
      else X.formErr = msgOf(d, 'Le concert n\'a pas pu démarrer. Réessaie dans un instant.');
      paint(X);
    }).catch(function () { if (X.dead) return; X.busy = false; X.formErr = 'Réseau indisponible. Vérifie ta connexion puis réessaie.'; paint(X); });
  }

  function beginConnect(X) {
    X.beforeUnload = function (e) { e.preventDefault(); e.returnValue = ''; return ''; };
    window.addEventListener('beforeunload', X.beforeUnload);
    setState(X, 'connecting');
    startCycle(X);
  }

  // ── Connexion WebSocket + reconnexion ─────────────────────────────────────
  function startCycle(X) {
    X.cycleStart = Date.now(); X.attempt = 0;
    if (X.state === 'failed') setState(X, X.everLive ? 'live' : 'connecting');
    if (X.everLive) setBanner(X, 'Reconnexion…');
    tryConnect(X, !X.ingest);
  }

  function fetchIngest(X) {
    // 1) la session existe-t-elle encore ? 2) un jeton neuf via POST (409) ; 3) à défaut, l'ancien.
    return api('/studio/live/current').then(function (c) {
      if (c && c._code === 401) throw { fatal: 'Ta session a expiré. Reconnecte-toi, puis reprends le live depuis le studio.' };
      if (c && c.data === null && c._code < 400) throw { gone: true };
      if (!c || !c.data) throw new Error('current');
      var cd = c.data;
      if (cd.event_id) X.eventId = cd.event_id;
      if (cd.ingest) { X.ingest = cd.ingest; return; }
      return api('/studio/live', { body: X.createBody || { title: X.title || 'Live' } }).then(function (d) {
        var dd = d && d.data;
        if (dd && dd.ingest) { X.ingest = dd.ingest; if (dd.web_url) X.webUrl = dd.web_url; if (dd.watch_url) X.watchUrl = dd.watch_url; return; }
        if (X.lastIngest) { X.ingest = X.lastIngest; return; }
        throw new Error('no-ingest');
      });
    });
  }

  function tryConnect(X, needIngest) {
    if (X.dead || X.ending) return;
    if (X.state === 'connecting') { var t = $('stConnSub'); if (t && X.attempt) t.textContent = 'Nouvelle tentative (' + (X.attempt + 1) + ')…'; }
    var p = needIngest ? fetchIngest(X) : Promise.resolve();
    p.then(function () { if (!X.dead && !X.ending) openWs(X); }, function (e) {
      if (X.dead || X.ending) return;
      if (e && e.gone) { finish(X, 'Le live a été terminé côté serveur.'); return; }
      if (e && e.fatal) { giveUp(X, e.fatal); return; }
      scheduleRetry(X, true);
    });
  }

  function wsUrl(X) {
    var base = X.ingest.ws_url, sep = base.indexOf('?') >= 0 ? '&' : '?';
    return base + sep + 't=' + encodeURIComponent(X.ingest.token) + '&mime=' + encodeURIComponent(X.mime);
  }

  function openWs(X) {
    closeTransport(X);
    var ws;
    try { ws = new WebSocket(wsUrl(X)); } catch (e) { scheduleRetry(X, true); return; }
    X.ws = ws; X.lastIngest = X.ingest;
    X.readyTimer = setTimeout(function () { if (X.ws === ws) scheduleRetry(X, false); }, READY_TIMEOUT_MS);
    ws.onmessage = function (ev) {
      if (X.ws !== ws || typeof ev.data !== 'string') return;
      var m; try { m = JSON.parse(ev.data); } catch (e) { return; }
      if (m.type === 'ready') { clearTimeout(X.readyTimer); startRecorder(X); }
      else if (m.type === 'live') { clearTimeout(X.readyTimer); onLive(X); }
      else if (m.type === 'stats') { if (isFinite(+m.bitrate_kbps)) { X.srvKbps = +m.bitrate_kbps; X.srvAt = Date.now(); } updateStats(X); }
      else if (m.type === 'error') { setBanner(X, m.message ? 'Serveur : ' + m.message : 'Le serveur signale une erreur de diffusion.', true); }
      else if (m.type === 'ended') { finish(X, 'Le live a été terminé côté serveur.'); }
    };
    ws.onerror = function () { /* onclose suit toujours : on y gère la reprise */ };
    ws.onclose = function () { if (X.ws === ws && !X.ending && !X.dead) scheduleRetry(X, true); };
  }

  function onLive(X) {
    var again = X.everLive;
    X.everLive = true; if (!X.liveSince) X.liveSince = Date.now();
    X.attempt = 0; X.cycleStart = 0; X.slowSince = 0;
    if (X.state !== 'live') setState(X, 'live');
    setBanner(X, '');
    if (again) toast('Reconnecté : le direct continue');
    if (!X.tick) { X.tick = setInterval(function () { tick(X); }, 1000); }
    if (!X.chatTimer) { pollChat(X); X.chatTimer = setInterval(function () { pollChat(X); }, CHAT_POLL_MS); }
    getWake(X);
  }

  function closeTransport(X) {
    clearTimeout(X.readyTimer); clearTimeout(X.retryTimer);
    stopRecorder(X);
    var ws = X.ws; X.ws = null;
    if (ws) { ws.onmessage = ws.onclose = ws.onerror = ws.onopen = null; try { ws.close(1000); } catch (e) {} }
  }

  function scheduleRetry(X, needIngest) {
    if (X.dead || X.ending) return;
    closeTransport(X);
    if (!X.cycleStart) { X.cycleStart = Date.now(); X.attempt = 0; }
    var elapsed = Date.now() - X.cycleStart;
    if (elapsed >= GIVE_UP_MS) return giveUp(X);
    var delay = Math.min(1000 * Math.pow(2, X.attempt), 8000);
    if (elapsed + delay > GIVE_UP_MS) delay = Math.max(500, GIVE_UP_MS - elapsed);
    X.attempt++;
    setBanner(X, X.everLive ? 'Reconnexion… (tentative ' + X.attempt + ')' : '');
    var sub = $('stConnSub'); if (sub) sub.textContent = 'Connexion difficile, nouvelle tentative dans ' + Math.round(delay / 1000) + ' s…';
    X.retryTimer = setTimeout(function () { tryConnect(X, true); }, delay);
  }

  function giveUp(X, msg) {
    closeTransport(X);
    X.endMsg = msg || 'Impossible de rétablir la connexion après une minute. Vérifie ton réseau (Wi-Fi ou 4G/5G), puis réessaie ou termine le live.';
    setBanner(X, '');
    setState(X, 'failed');
  }

  // ── MediaRecorder ─────────────────────────────────────────────────────────
  function startRecorder(X) {
    stopRecorder(X);
    var q = QUALITIES[X.q], rec;
    try { rec = new MediaRecorder(X.stream, { mimeType: X.mime, videoBitsPerSecond: q.vbps, audioBitsPerSecond: AUDIO_BPS }); }
    catch (e) { try { rec = new MediaRecorder(X.stream, { mimeType: X.mime }); } catch (e2) { giveUp(X, 'Ce navigateur ne peut pas enregistrer ta caméra pour la diffusion. Essaie avec une version récente de Chrome ou de Safari.'); return; } }
    X.rec = rec;
    rec.ondataavailable = function (e) { if (X.rec === rec) sendChunk(X, e.data); };
    rec.onerror = function () { if (X.rec === rec && !X.ending) scheduleRetry(X, false); };
    try { rec.start(1000); } catch (e) { scheduleRetry(X, false); }
  }
  function stopRecorder(X) {
    var r = X.rec; X.rec = null;
    if (r) { r.ondataavailable = null; r.onerror = null; try { if (r.state !== 'inactive') r.stop(); } catch (e) {} }
  }
  function sendChunk(X, blob) {
    var ws = X.ws;
    if (!blob || !blob.size || !ws || ws.readyState !== 1) return;
    if (ws.bufferedAmount > MAX_BUFFER) {
      // Réseau trop lent : on laisse la file se vider plutôt que de l'allonger.
      var now = Date.now(); if (!X.slowSince) X.slowSince = now;
      setBanner(X, 'Connexion trop lente : la qualité du direct peut baisser. Baisse la qualité ou rapproche-toi du Wi-Fi.', true);
      if (now - X.slowSince > SLOW_RESYNC_MS) { X.slowSince = 0; scheduleRetry(X, false); }
      return;
    }
    if (X.slowSince) { X.slowSince = 0; setBanner(X, ''); }
    try { ws.send(blob); X.bytes += blob.size; } catch (e) { scheduleRetry(X, true); }
  }

  // ── Chrono, débit, veille ─────────────────────────────────────────────────
  function tick(X) {
    if (X.dead) return;
    var el = $('stTimer'); if (el) el.textContent = fmtDur((Date.now() - X.liveSince) / 1000);
    X.kbps = Math.round((X.bytes - X.lastBytes) * 8 / 1000); X.lastBytes = X.bytes;
    updateStats(X);
  }
  function updateStats(X) {
    var el = $('stStats'); if (!el) return;
    var k = (X.srvAt && Date.now() - X.srvAt < 6000) ? X.srvKbps : X.kbps;
    el.textContent = 'Débit : ' + (k ? Math.round(k).toLocaleString('fr-FR') + ' kb/s' : '—') + ' · Envoyé : ' + fmtMo(X.bytes);
  }
  function getWake(X) {
    if (!navigator.wakeLock || X.wake || X.dead) return;
    navigator.wakeLock.request('screen').then(function (l) { if (X.dead) { l.release(); return; } X.wake = l; l.addEventListener('release', function () { if (X.wake === l) X.wake = null; }); }, function () {});
    if (!X.visHandler) { X.visHandler = function () { if (document.visibilityState === 'visible' && !X.dead && X.state === 'live') getWake(X); }; document.addEventListener('visibilitychange', X.visHandler); }
  }

  // ── Partage ───────────────────────────────────────────────────────────────
  function shareUrl(X) {
    return X.webUrl || X.watchUrl || (location.href.split('#')[0] + '#/event/' + encodeURIComponent(X.eventId));
  }
  function share(X) {
    var u = shareUrl(X), t = 'Je suis en direct sur VybzzZ : ' + X.title;
    if (navigator.share) { navigator.share({ title: 'VybzzZ', text: t, url: u }).catch(function () {}); return; }
    var done = function () { toast('Lien copié'); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(u).then(done, function () { window.prompt('Copie ce lien :', u); });
    else window.prompt('Copie ce lien :', u);
  }

  // ── Chat (lecture + envoi) ────────────────────────────────────────────────
  function userName(u) { return u ? (u.artist_name || u.full_name || u.name || 'Spectateur') : 'Spectateur'; }
  function pollChat(X) {
    if (X.dead || !X.eventId) return;
    api('/event-logs', { body: { event_id: X.eventId } }).then(function (d) {
      if (X.dead) return;
      var list = (d && (d.activity || d.data || d.list)) || [];
      if (!Array.isArray(list)) return;
      list = list.filter(function (a) { return a && (a.type === 'comment' || a.type === 'gift'); }).sort(function (a, b) { return (a.id || 0) - (b.id || 0); }).slice(-100);
      var key = list.length + ':' + (list.length ? list[list.length - 1].id : 0);
      if (key === X.lastChatKey) return;
      X.lastChatKey = key; renderChat(list);
    }).catch(function () {});
  }
  function renderChat(list) {
    var log = $('stLog'); if (!log) return;
    var atEnd = log.scrollHeight - log.scrollTop - log.clientHeight < 40;
    log.innerHTML = list.length ? list.map(function (a) {
      var n = esc(userName(a.user_info)), t = esc(a.description || '');
      return a.type === 'gift' ? '<li class="gift">🎁 <b>' + n + '</b> a envoyé un cadeau' + (t ? ' · ' + t : '') + '</li>' : '<li><b>' + n + '</b> ' + t + '</li>';
    }).join('') : '<li class="muted small">Aucun message pour le moment. Dis bonjour !</li>';
    if (atEnd) log.scrollTop = log.scrollHeight;
  }
  function sendChat(X) {
    var inp = $('stMsg'), txt = (inp.value || '').trim();
    if (!txt || !X.eventId) return;
    inp.value = '';
    api('/event-comment', { body: { event_id: X.eventId, comment: txt.slice(0, 200) } }).then(function (d) {
      if (X.dead) return;
      if (d && d.status === 'success') { X.lastChatKey = ''; pollChat(X); var log = $('stLog'); if (log) setTimeout(function () { log.scrollTop = log.scrollHeight; }, 400); }
      else { inp.value = txt; toast(msgOf(d, 'Message non envoyé, réessaie.')); }
    }).catch(function () { inp.value = txt; toast('Message non envoyé : réseau indisponible.'); });
  }

  // ── Fin du live ───────────────────────────────────────────────────────────
  function stopRequest(id, tries) {
    tries = tries || 0;
    return api('/studio/live/' + encodeURIComponent(id) + '/stop', { method: 'POST', body: {} }).then(function (d) {
      if (d && d.status === 'success') return true;
      if (d && (d._code === 404 || d._code === 409)) return true; // déjà terminé
      throw new Error('stop');
    }).catch(function () { return tries < 2 ? new Promise(function (r) { setTimeout(r, 1000); }).then(function () { return stopRequest(id, tries + 1); }) : false; });
  }

  function endLive(X, callStop) {
    if (X.ending) return;
    X.ending = true;
    closeTransport(X);
    var wait = X.eventId && callStop ? stopRequest(X.eventId) : Promise.resolve(true);
    var btn = $('stYes') || $('stStop') || $('stCancel'); if (btn) { btn.disabled = true; }
    wait.then(function (ok) { finish(X, ok ? '' : 'Le serveur n\'a pas confirmé l\'arrêt : vérifie dans l\'application que le live est bien terminé.'); });
  }

  function finish(X, msg) {
    if (X.dead || X.state === 'ended') return;
    X.ending = true; closeTransport(X); cleanup(X);
    X.endMsg = msg || ''; X.endedAt = Date.now();
    if (!X.everLive) X.liveSince = 0;
    setBanner(X, ''); setState(X, 'ended');
  }

  function cleanup(X) {
    clearInterval(X.tick); clearInterval(X.chatTimer); X.tick = X.chatTimer = 0;
    clearTimeout(X.retryTimer); clearTimeout(X.readyTimer);
    if (X.beforeUnload) { window.removeEventListener('beforeunload', X.beforeUnload); X.beforeUnload = null; }
    if (X.visHandler) { document.removeEventListener('visibilitychange', X.visHandler); X.visHandler = null; }
    if (X.wake) { try { X.wake.release(); } catch (e) {} X.wake = null; }
    stopTracks(X);
    var v = $('stVideo'); if (v && v.srcObject) v.srcObject = null;
  }

  function teardown(X, callStop) {
    if (X.dead) return;
    var liveId = (X.state === 'live' || X.state === 'connecting' || X.state === 'failed') && !X.ending ? X.eventId : null;
    X.dead = true; X.ending = true;
    closeTransport(X); cleanup(X);
    if (liveId && callStop) stopRequest(liveId);
    if (cur === X) cur = null;
  }

  // ── API publique pour le routeur ──────────────────────────────────────────
  function inProgress() { return !!cur && !cur.dead && !cur.ending && (cur.state === 'live' || cur.state === 'connecting' || cur.state === 'failed'); }
  window.VyStudio = {
    render: render,
    active: function () { return !!cur && !cur.dead; },
    // Appelé quand on quitte #/studio : true = on peut partir.
    leave: function () {
      if (!cur) return true;
      if (inProgress()) {
        if (!window.confirm('Un live est en cours. Si tu quittes cet écran, il sera terminé. Quitter quand même ?')) return false;
        teardown(cur, true); return true;
      }
      teardown(cur, false); return true;
    },
  };
})();

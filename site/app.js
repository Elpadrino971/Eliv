/* ============================================================
   VYBZZZ — Moteur partagé (chrome, animations, rendu des pages)
   ============================================================ */
(function () {
  "use strict";
  const D = window.VYBZZZ;
  const H = D.helpers;
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const page = document.body.dataset.page || "home";

  /* ---------- i18n (12 langues) ---------- */
  const LANGS = [
    { code: "fr", name: "Français" }, { code: "en", name: "English" }, { code: "es", name: "Español" },
    { code: "it", name: "Italiano" }, { code: "de", name: "Deutsch" }, { code: "pt", name: "Português" },
    { code: "zh", name: "中文" }, { code: "ko", name: "한국어" }, { code: "ja", name: "日本語" },
    { code: "ar", name: "العربية" }, { code: "hi", name: "हिन्दी" }, { code: "ru", name: "Русский" },
  ];
  let LANG = localStorage.getItem("vyb_lang") || "fr";
  function dict() { return (window.I18N && (window.I18N[LANG] || window.I18N.fr)) || {}; }
  function t(k) { const d = dict(), f = (window.I18N && window.I18N.fr) || {}; return d[k] != null ? d[k] : (f[k] != null ? f[k] : k); }
  function applyI18n(root) {
    root = root || document;
    root.querySelectorAll("[data-i18n]").forEach(el => { el.textContent = t(el.getAttribute("data-i18n")); });
    root.querySelectorAll("[data-i18n-html]").forEach(el => { el.innerHTML = t(el.getAttribute("data-i18n-html")); });
    root.querySelectorAll("[data-i18n-ph]").forEach(el => { el.setAttribute("placeholder", t(el.getAttribute("data-i18n-ph"))); });
    document.documentElement.lang = LANG;
    document.documentElement.dir = LANG === "ar" ? "rtl" : "ltr";
  }
  function openLangSheet() {
    let s = document.getElementById("langSheet");
    if (!s) {
      s = document.createElement("div"); s.id = "langSheet"; s.className = "lang-sheet";
      s.innerHTML = '<div class="lang-sheet__box"><div class="lang-sheet__head"><b>' + t("lang_label") + '</b><button class="lang-sheet__x" aria-label="Fermer">✕</button></div>' +
        LANGS.map(l => '<button class="lang-opt ' + (l.code === LANG ? "on" : "") + '" data-code="' + l.code + '"><span class="code">' + l.code.toUpperCase() + '</span>' + l.name + (l.code === LANG ? '<span class="chk">✓</span>' : '') + '</button>').join("") + '</div>';
      document.body.appendChild(s);
      s.querySelector(".lang-sheet__x").addEventListener("click", () => s.classList.remove("open"));
      s.addEventListener("click", e => { if (e.target === s) s.classList.remove("open"); });
      s.querySelectorAll(".lang-opt").forEach(b => b.addEventListener("click", () => { localStorage.setItem("vyb_lang", b.dataset.code); location.reload(); }));
    }
    requestAnimationFrame(() => s.classList.add("open"));
  }
  window.__vybLang = openLangSheet;

  /* ---------- Chrome : header + footer injectés ---------- */
  const NAV = [
    { href: "index.html",            key: "nav_home",   id: "home" },
    { href: "feed.html",             key: "nav_feed",   id: "feed" },
    { href: "store.html",            key: "nav_store",  id: "store" },
    { href: "index.html#avantages",  key: "nav_deal",   id: "_deal" },
    { href: "dashboard.html",        key: "nav_studio", id: "dashboard" },
    { href: "faq.html",              key: "nav_faq",    id: "faq" },
  ];

  function renderHeader() {
    const links = NAV.map(n =>
      `<a href="${n.href}" class="${n.id === page ? "active" : ""}" data-cursor="hover">${t(n.key)}</a>`
    ).join("");
    return `
    <header class="nav" id="nav">
      <a href="index.html" class="nav__brand" data-cursor="hover">
        <img src="assets/logo.svg" alt="" class="brand-logo" />
        <span class="brand">Vybzzz</span>
      </a>
      <nav class="nav__links" style="margin-left:auto">${links}</nav>
      <div class="nav__cta">
        <button class="lang-btn" data-cursor="hover" onclick="window.__vybLang&&window.__vybLang()">🌐 ${LANG.toUpperCase()}</button>
        <a href="dashboard.html" class="btn btn--ghost" data-cursor="hover">${t("nav_login")}</a>
        <a href="artist.html" class="btn btn--gold magnetic" data-cursor="hover"><span>${t("nav_apply")}</span></a>
      </div>
      <button class="nav__burger" id="burger" aria-label="Menu"><i></i><i></i><i></i></button>
    </header>`;
  }

  function renderFooter() {
    return `
    <footer class="footer">
      <div class="footer__top">
        <div class="footer__brand">
          <a href="index.html" class="nav__brand"><img src="assets/logo.svg" alt="" class="brand-logo" /><span class="brand">Vybzzz</span></a>
          <p>${t("foot_tagline")}</p>
        </div>
        <div class="footer__cols">
          <div><h4>${t("foot_discover")}</h4><a href="index.html">${t("nav_home")}</a><a href="feed.html">Feed</a><a href="store.html">Boutique</a></div>
          <div><h4>${t("foot_artists")}</h4><a href="dashboard.html">${t("nav_studio")}</a><a href="artist.html">${t("nav_apply")}</a><a href="artist.html#contrat">Contrat</a></div>
          <div><h4>${t("foot_help")}</h4><a href="faq.html">${t("nav_faq")}</a><a href="checkout.html">Paiement</a><a href="#">Contact</a></div>
        </div>
      </div>
      <div class="footer__bottom">
        <span>${t("foot_rights")}</span>
        <span class="footer__made">${t("foot_secure")}</span>
      </div>
    </footer>`;
  }

  const headerSlot = document.getElementById("site-header");
  const footerSlot = document.getElementById("site-footer");
  if (headerSlot) headerSlot.innerHTML = renderHeader();
  if (footerSlot) footerSlot.innerHTML = renderFooter();

  /* ---------- Nav behaviour ---------- */
  const nav = document.getElementById("nav");
  if (nav) {
    const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 30);
    addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    const burger = document.getElementById("burger");
    burger && burger.addEventListener("click", () => nav.classList.toggle("open"));
  }

  /* ---------- Scroll progress ---------- */
  const prog = document.getElementById("scrollProgress");
  if (prog) addEventListener("scroll", () => {
    const h = document.documentElement.scrollHeight - innerHeight;
    prog.style.width = (scrollY / h) * 100 + "%";
  }, { passive: true });

  /* ---------- Custom cursor ---------- */
  const cursor = document.getElementById("cursor"), dot = document.getElementById("cursorDot");
  if (cursor && matchMedia("(hover:hover)").matches && !reduceMotion) {
    let cx = 0, cy = 0, tx = 0, ty = 0;
    addEventListener("mousemove", e => {
      tx = e.clientX; ty = e.clientY;
      dot.style.transform = `translate(${tx}px,${ty}px) translate(-50%,-50%)`;
    });
    (function loop() {
      cx += (tx - cx) * .18; cy += (ty - cy) * .18;
      cursor.style.transform = `translate(${cx}px,${cy}px) translate(-50%,-50%)`;
      requestAnimationFrame(loop);
    })();
    document.addEventListener("mouseover", e => {
      if (e.target.closest('[data-cursor="hover"]')) cursor.classList.add("is-hover");
    });
    document.addEventListener("mouseout", e => {
      if (e.target.closest('[data-cursor="hover"]')) cursor.classList.remove("is-hover");
    });
  }

  /* ---------- Reveal on scroll ---------- */
  const io = new IntersectionObserver((es) => es.forEach(e => {
    if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }), { threshold: .12, rootMargin: "0px 0px -6% 0px" });
  const observeReveals = (root = document) => root.querySelectorAll(".reveal:not(.in)").forEach(el => io.observe(el));

  /* ---------- Count-up ---------- */
  const countUp = (el) => {
    const target = parseFloat(el.dataset.count), dur = 1500, t0 = performance.now();
    const isF = target % 1 !== 0, pre = el.dataset.prefix || "", suf = el.dataset.suffix || "";
    (function tick(now) {
      const p = Math.min((now - t0) / dur, 1), e = 1 - Math.pow(1 - p, 3), v = target * e;
      el.textContent = pre + (isF ? v.toFixed(1) : Math.round(v).toLocaleString("fr-FR")) + suf;
      if (p < 1) requestAnimationFrame(tick);
    })(performance.now());
  };
  const countIO = new IntersectionObserver((es, o) => es.forEach(e => {
    if (e.isIntersecting) { countUp(e.target); o.unobserve(e.target); }
  }), { threshold: .6 });
  const observeCounts = (root = document) => root.querySelectorAll("[data-count]").forEach(el => countIO.observe(el));

  /* ---------- Magnetic + tilt ---------- */
  function bindMicro(root = document) {
    if (reduceMotion) return;
    root.querySelectorAll(".magnetic:not([data-mg])").forEach(el => {
      el.dataset.mg = 1;
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        el.style.transform = `translate(${(e.clientX - r.left - r.width / 2) * .3}px,${(e.clientY - r.top - r.height / 2) * .4}px)`;
      });
      el.addEventListener("mouseleave", () => el.style.transform = "");
    });
    if (matchMedia("(hover:hover)").matches) root.querySelectorAll(".tilt:not([data-tl])").forEach(el => {
      el.dataset.tl = 1;
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - .5, py = (e.clientY - r.top) / r.height - .5;
        el.style.transform = `perspective(900px) rotateY(${px * 8}deg) rotateX(${-py * 8}deg) translateY(-4px)`;
      });
      el.addEventListener("mouseleave", () => el.style.transform = "");
    });
  }

  function refresh(root) { observeReveals(root); observeCounts(root); bindMicro(root); }
  window.__vybRefresh = refresh;

  /* ---------- Toast ---------- */
  function toast(msg) {
    let t = document.querySelector(".toast");
    if (!t) { t = document.createElement("div"); t.className = "toast"; document.body.appendChild(t); }
    t.textContent = msg; t.classList.add("show");
    clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove("show"), 2600);
  }
  window.__vybToast = toast;

  /* ============================================================
     RENDUS DE PAGE
     ============================================================ */

  const liveBadge = `<span class="badge-live"><span class="pulse-dot"></span>LIVE</span>`;
  const verified = `<svg class="verif" viewBox="0 0 24 24" width="14" height="14"><path fill="#c6a75e" d="M12 1l2.6 1.9 3.2-.3 1 3 2.7 1.8-1 3 1 3-2.7 1.8-1 3-3.2-.3L12 23l-2.6-1.9-3.2.3-1-3L2.5 14.6l1-3-1-3 2.7-1.8 1-3 3.2.3L12 1z"/><path fill="#0b0e14" d="M10.6 14.6l-2-2-1.2 1.2 3.2 3.2 5.4-5.4-1.2-1.2z"/></svg>`;

  // ---- Plan créateur card ----
  function planCard(p) {
    const meta = { Starter: { ic: "🚀" }, Growth: { ic: "📈" }, Elite: { ic: "🏆" } }[p.name] || { ic: "★" };
    return `
    <article class="plan glass reveal tilt ${p.highlight ? "plan--feat" : ""}" data-cursor="hover">
      ${p.tag ? `<span class="plan__tag">${p.tag}</span>` : ""}
      <div class="plan__icon">${meta.ic}</div>
      <h3>${p.name}</h3>
      <div class="plan__price">$${p.price}<i>/mois</i></div>
      <div class="plan__comm">Tu gardes <b>${p.commission}%</b> de tes revenus</div>
      ${p.note ? `<p class="plan__note">${p.note}</p>` : ""}
      <ul>${p.features.map(f => `<li>${f}</li>`).join("")}</ul>
      <a href="${p.link || "artist.html"}" ${p.link ? 'target="_blank" rel="noopener"' : ""} class="btn ${p.highlight ? "btn--gold" : "btn--outline"}" data-cursor="hover"><span>${p.cta}</span></a>
    </article>`;
  }
  // ---- État de l'offre Founder (palier courant selon l'ordre d'inscription) ----
  function founderInfo() {
    const f = D.founder; let cum = 0;
    for (let i = 0; i < f.tiers.length; i++) {
      const prev = cum; cum += f.tiers[i].seats;
      if (f.taken < cum) {
        return {
          closed: false, tierIndex: i, price: f.tiers[i].price,
          takenInTier: f.taken - prev, tierSeats: f.tiers[i].seats,
          remaining: cum - f.taken,
          nextPrice: f.tiers[i + 1] ? f.tiers[i + 1].price : null,
          link: f.tiers[i].link,
        };
      }
    }
    return { closed: true, tierIndex: -1, price: null, remaining: 0 };
  }
  function tierCardHTML(t, i, fi) {
    const done = !fi.closed && i < fi.tierIndex;
    const cur = !fi.closed && i === fi.tierIndex;
    const tagTxt = cur ? "En cours" : done ? "Complet ✓" : "À venir";
    return `
    <article class="plan glass reveal tilt ${cur ? "plan--feat" : ""} ${done ? "plan--done" : ""}" data-cursor="hover">
      <span class="plan__tag">${tagTxt}</span>
      <div class="plan__icon">★</div>
      <h3>Founder · Vague ${i + 1}</h3>
      <div class="plan__price">$${t.price}<i>/mois à vie</i></div>
      <div class="plan__comm">Tu gardes <b>60%</b> de tes revenus</div>
      <p class="plan__note">${t.label}</p>
      <ul>
        <li>Prix bloqué à vie (abo actif)</li>
        <li>Studio Pro complet</li>
        <li>Mise en avant Fondateur</li>
        ${cur ? `<li><b>${fi.remaining}</b> places restantes à ce tarif</li>` : ""}
      </ul>
      <a href="${cur ? t.link : "artist.html"}" ${cur ? 'target="_blank" rel="noopener"' : ""} class="btn ${cur ? "btn--gold" : "btn--outline"}" data-cursor="hover"><span>${cur ? "Réserver à $" + t.price : done ? "Complet" : "Bientôt"}</span></a>
    </article>`;
  }
  function eliteCardHTML() {
    const e = D.elite;
    return `
    <article class="plan glass reveal tilt" data-cursor="hover">
      <span class="plan__tag">${e.tag}</span>
      <div class="plan__icon">🏆</div>
      <h3>${e.name}</h3>
      <div class="plan__price">$${e.price}<i>/mois</i></div>
      <div class="plan__comm">Tu gardes <b>${e.commission}%</b> de tes revenus</div>
      <ul>${e.features.map(f => `<li>${f}</li>`).join("")}</ul>
      <a href="${e.link}" target="_blank" rel="noopener" class="btn btn--outline" data-cursor="hover"><span>${e.cta}</span></a>
    </article>`;
  }
  function renderPlans() {
    const el = document.getElementById("planGrid");
    if (!el) return;
    const fi = founderInfo();
    el.innerHTML = fi.closed
      ? D.plansNormal.map(planCard).join("")
      : D.founder.tiers.map((t, i) => tierCardHTML(t, i, fi)).join("") + eliteCardHTML();
  }
  // ---- Hero : escalier de prix + jauge + urgence dynamiques ----
  function renderSeats() {
    const fi = founderInfo();
    const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
    // Jauge de démarrage (quorum)
    set("quorumTaken", D.founder.taken); set("quorumTotal", D.founder.quorum);
    const qf = document.getElementById("quorumFill");
    if (qf) setTimeout(() => qf.style.width = Math.min(100, D.founder.taken / D.founder.quorum * 100) + "%", 450);
    document.querySelectorAll(".tier-ladder .tier").forEach(el => {
      const idx = +el.dataset.tier;
      el.classList.toggle("current", !fi.closed && idx === fi.tierIndex);
      el.classList.toggle("done", !fi.closed && idx < fi.tierIndex);
    });
    if (fi.closed) {
      set("urgencyMsg", "Offre Founder clôturée — plans normaux disponibles.");
      set("spotsLeft", "offre terminée"); set("ctaLeft", 0);
      return;
    }
    const next = fi.nextPrice ? `ensuite le tarif passe à $${fi.nextPrice}/mois` : "dernière vague avant la fin de l'offre";
    set("urgencyMsg", `Plus que ${fi.remaining} places à $${fi.price}/mois — ${next}.`);
    set("spotsTaken", fi.takenInTier);
    set("spotsTotal", fi.tierSeats);
    set("spotsPrice", "$" + fi.price);
    set("spotsLeft", fi.remaining + " places à $" + fi.price);
    set("ctaLeft", fi.remaining);
    set("seatsLeftBig", fi.remaining);
    const fill = document.getElementById("spotsFill");
    if (fill) setTimeout(() => fill.style.width = (fi.takenInTier / fi.tierSeats * 100) + "%", 400);
  }

  // ---- YouTube-style video card ----
  function videoCard(ev) {
    const meta = ev.live
      ? `${H.nb(ev.viewers)} spectateurs · en direct`
      : `${H.nb(ev.likes)} j'aime · ${ev.scheduled}`;
    return `
    <article class="vcard reveal" data-cursor="hover" data-event="${ev.id}">
      <a href="checkout.html?event=${ev.id}" class="vcard__thumb">
        <img src="${ev.thumb}" alt="${ev.name}" loading="lazy" />
        ${ev.live ? liveBadge : `<span class="badge-soon">${ev.scheduled}</span>`}
        <span class="vcard__price">${ev.price === 0 ? "Gratuit" : "$" + ev.price.toFixed(2)}</span>
        <span class="vcard__play">▶</span>
      </a>
      <div class="vcard__body">
        <img class="vcard__avatar" src="${ev.artist.avatar}" alt="" />
        <div class="vcard__txt">
          <h3>${ev.name}</h3>
          <p>${ev.artist.name} ${ev.artist.verified ? verified : ""} · ${ev.genre}</p>
          <small>${meta}</small>
        </div>
      </div>
    </article>`;
  }

  function renderHome() {
    // categories
    const cats = document.getElementById("cats");
    if (cats) {
      cats.innerHTML = D.categories.map((c, i) =>
        `<button class="chip ${i === 0 ? "active" : ""}" data-cursor="hover">${c}</button>`).join("");
      cats.addEventListener("click", e => {
        const b = e.target.closest(".chip"); if (!b) return;
        cats.querySelectorAll(".chip").forEach(x => x.classList.remove("active"));
        b.classList.add("active");
        const label = b.textContent.trim();
        let list = D.events;
        if (label === "🔴 En direct") list = D.events.filter(e => e.live);
        else if (label !== "Tous") list = D.events.filter(e => e.genre === label);
        grid.innerHTML = (list.length ? list : D.events).map(videoCard).join("");
        refresh(grid);
      });
    }
    // featured artists row
    const ar = document.getElementById("artistsRow");
    if (ar) {
      ar.innerHTML = D.artists.map(a => `
        <a class="achip reveal" data-cursor="hover" href="feed.html">
          <span class="achip__ring"><img src="${a.avatar}" alt="${a.name}" /></span>
          <strong>${a.name} ${a.verified ? verified : ""}</strong>
          <small>${a.followers} abonnés</small>
        </a>`).join("");
    }
    // main grid (si présent)
    const grid = document.getElementById("videoGrid");
    if (grid) grid.innerHTML = D.events.map(videoCard).join("");
    // recrutement : plans + jauge de places fondateur + feed live (split-screen)
    renderPlans();
    renderSeats();
    renderHomeFeed();
    refresh();
  }

  // ---- Feed item (réutilisé par feed.html ET le split-screen de l'accueil) ----
  function feedItemHTML(ev) {
    const bg = ev.video ? `https://image.mux.com/${ev.video}/thumbnail.jpg?width=720` : ev.thumb;
    const videoTag = ev.video
      ? `<video class="feed__video" data-src="https://stream.mux.com/${ev.video}.m3u8" poster="${bg}" muted loop playsinline preload="none"></video>`
      : "";
    return `
      <section class="feed__item" style="--bg:url('${bg}')">
        ${videoTag}
        <div class="feed__overlay"></div>
        <div class="feed__content">
          <div class="feed__meta">${liveBadge}</div>
          ${ev.name ? `<h2 class="feed__title">${ev.name}</h2>` : ""}
        </div>
        <aside class="feed__actions">
          <button class="fa-btn" data-act="like" data-cursor="hover"><span>♥</span></button>
          <button class="fa-btn" data-act="gift" data-cursor="hover"><span>🎁</span><i>Cadeau</i></button>
          <button class="fa-btn" data-act="share" data-cursor="hover"><span>↗</span><i>Partager</i></button>
        </aside>
      </section>`;
  }
  function bindFeed(container) {
    container.addEventListener("click", e => {
      const b = e.target.closest(".fa-btn"); if (!b) return;
      const act = b.dataset.act;
      if (act === "like") { b.classList.toggle("liked"); }
      else if (act === "gift") { openGiftPanel(); }
      else if (act === "share") { toast("Lien copié dans le presse-papier ✓"); }
      else if (act === "chat") { toast("Le chat en direct est disponible dans l'app 📱"); }
    });
    container.querySelectorAll(".feed__follow").forEach(b => b.addEventListener("click", ev => {
      ev.preventDefault(); b.classList.toggle("on");
      b.textContent = b.classList.contains("on") ? "Suivi ✓" : "Suivre";
    }));
    initFeedVideos(container);
    bindMicro(container);
  }
  // ---- Lecture des vidéos Mux (autoplay muet quand visible, pause sinon) ----
  function attachHls(video, src) {
    if (video.canPlayType("application/vnd.apple.mpegurl")) { video.src = src; }      // Safari
    else if (window.Hls && window.Hls.isSupported()) { const h = new Hls({ capLevelToPlayerSize: true }); h.loadSource(src); h.attachMedia(video); }
    else { video.src = src; }
  }
  function initFeedVideos(container) {
    const vids = container.querySelectorAll(".feed__video");
    if (!vids.length) return;
    const vio = new IntersectionObserver(entries => {
      entries.forEach(e => {
        const v = e.target;
        if (e.isIntersecting) {
          if (!v.dataset.loaded) { attachHls(v, v.dataset.src); v.dataset.loaded = "1"; }
          const p = v.play(); if (p && p.catch) p.catch(() => {});
        } else { v.pause(); }
      });
    }, { threshold: 0.55 });
    vids.forEach(v => vio.observe(v));
  }
  // ---- Montage du feed : uniquement les vraies vidéos Mux + bouton son ----
  function setupFeed(feedEl, catsEl, soundEl) {
    if (!feedEl) return;
    if (catsEl) catsEl.style.display = "none";   // pas de catégories factices pour l'instant
    let soundOn = false;
    function applySound() { feedEl.querySelectorAll(".feed__video").forEach(v => { v.muted = !soundOn; }); }
    feedEl.innerHTML = D.events.map(feedItemHTML).join("");
    bindFeed(feedEl);
    applySound();
    if (soundEl) {
      soundEl.addEventListener("click", () => {
        soundOn = !soundOn;
        soundEl.textContent = soundOn ? "🔊" : "🔇";
        soundEl.classList.toggle("on", soundOn);
        applySound();
        feedEl.querySelectorAll(".feed__video").forEach(v => { if (!v.paused) { const p = v.play(); if (p && p.catch) p.catch(() => {}); } });
        toast(soundOn ? "🔊 Son activé" : "🔇 Son coupé");
      });
    }
  }
  function renderFeed() {
    setupFeed(document.getElementById("feed"), document.getElementById("feedCatsFull"), document.getElementById("feedSoundFull"));
  }
  function renderHomeFeed() {
    setupFeed(document.getElementById("homeFeed"), document.getElementById("feedCats"), document.getElementById("feedSound"));
  }

  // ---- Gift panel (used by feed + store demo) ----
  function openGiftPanel() {
    let p = document.getElementById("giftPanel");
    if (!p) {
      p = document.createElement("div");
      p.id = "giftPanel"; p.className = "gift-panel";
      p.innerHTML = `
        <div class="gift-panel__sheet">
          <div class="gift-panel__head"><b>Envoyer un cadeau</b><span class="gift-panel__bal">Solde : <em>2 850 PTS</em></span><button class="gift-panel__x" aria-label="Fermer">✕</button></div>
          <div class="gift-panel__grid">
            ${D.gifts.map(g => `<button class="giftc" data-coins="${g.coins}" data-anim="${g.anim || ""}"><span>${g.emoji}</span><strong>${g.name}</strong><small>★ ${g.coins}</small></button>`).join("")}
          </div>
          <a href="store.html" class="btn btn--gold gift-panel__topup"><span>Recharger des Arena Points</span></a>
        </div>`;
      document.body.appendChild(p);
      p.querySelector(".gift-panel__x").addEventListener("click", () => p.classList.remove("open"));
      p.addEventListener("click", e => { if (e.target === p) p.classList.remove("open"); });
      p.querySelectorAll(".giftc").forEach(g => g.addEventListener("click", () => {
        flyGift(g.dataset.anim, g.querySelector("span").textContent);
        toast(`Cadeau envoyé · −${g.dataset.coins} PTS 🎉`);
      }));
    }
    requestAnimationFrame(() => p.classList.add("open"));
  }
  function flyEmoji(emoji) {
    const s = document.createElement("div");
    s.className = "fly-gift"; s.textContent = emoji || "🎁";
    s.style.left = (20 + Math.random() * 60) + "vw";
    document.body.appendChild(s);
    setTimeout(() => s.remove(), 2600);
  }
  function flyGift(anim, emoji) {
    if (!anim) { flyEmoji(emoji); return; }
    const wrap = document.createElement("div");
    wrap.className = "gift-anim-wrap";
    const v = document.createElement("video");
    v.className = "gift-anim";
    v.src = "assets/gifts/" + anim;
    v.muted = true; v.autoplay = true; v.setAttribute("playsinline", "");
    v.onended = () => wrap.remove();
    v.onerror = () => { wrap.remove(); flyEmoji(emoji); };  // si le fichier manque → emoji
    wrap.appendChild(v);
    document.body.appendChild(wrap);
    const p = v.play(); if (p && p.catch) p.catch(() => {});
    setTimeout(() => { if (wrap.parentNode) wrap.remove(); }, 9000);
  }

  function renderStore() {
    // packages
    const pg = document.getElementById("packGrid");
    if (pg) pg.innerHTML = D.packages.map(p => {
      const total = p.points + Math.round(p.points * p.bonus / 100);
      return `
      <article class="pack glass reveal tilt ${p.featured ? "pack--feat" : ""}" data-cursor="hover">
        ${p.featured ? '<span class="pack__tag">Meilleure offre</span>' : ""}
        ${p.bonus ? `<span class="pack__bonus">+${p.bonus}%</span>` : ""}
        <div class="pack__coin">🪙</div>
        <strong class="pack__pts">${total.toLocaleString("fr-FR")}<small>PTS</small></strong>
        ${p.bonus ? `<small class="pack__base">${p.points.toLocaleString("fr-FR")} + ${(total - p.points).toLocaleString("fr-FR")} bonus</small>` : `<small class="pack__base">${p.title}</small>`}
        <a href="checkout.html?pack=${p.id}" class="btn ${p.featured ? "btn--gold" : "btn--outline"}" data-cursor="hover"><span>$${p.price.toFixed(2)}</span></a>
      </article>`;
    }).join("");
    // gifts catalogue
    const gg = document.getElementById("giftGrid");
    if (gg) gg.innerHTML = D.gifts.map(g =>
      `<div class="giftc giftc--lg reveal" data-cursor="hover"><span>${g.emoji}</span><strong>${g.name}</strong><small>★ ${g.coins} PTS</small></div>`).join("");
    // plans (créateur — Founder/Starter/Elite ou Growth après)
    renderPlans();
    // try gift demo button
    const demo = document.getElementById("giftDemo");
    demo && demo.addEventListener("click", openGiftPanel);
    refresh();
  }

  function renderFaq() {
    const wrap = document.getElementById("faqList");
    if (!wrap) return;
    let h = "";
    for (let i = 1; i <= 8; i++) h += `<div class="faq-item reveal ${i === 1 ? "open" : ""}" data-cursor="hover"><button class="faq-q">${t("faq_q" + i)}<i>+</i></button><div class="faq-a"><p>${t("faq_a" + i)}</p></div></div>`;
    wrap.innerHTML = h;
    wrap.addEventListener("click", e => {
      const item = e.target.closest(".faq-item"); if (!item) return;
      item.classList.toggle("open");
    });
    refresh();
  }

  /* ---------- Dispatch ---------- */
  const routes = { home: renderHome, feed: renderFeed, store: renderStore, faq: renderFaq };
  applyI18n();
  (routes[page] || function () {})();
  refresh();

  // expose for inline page scripts (checkout, dashboard, artist)
  window.VYBZZZ_UI = { toast, refresh, helpers: H };
})();

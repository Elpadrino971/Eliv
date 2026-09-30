/* ============================================================
   VYBZZZ — Moteur partagé (chrome, animations, rendu des pages)
   ============================================================ */
(function () {
  if (location.hostname === "www.vybzzz.online") { location.replace("https://vybzzz.online" + location.pathname + location.search + location.hash); return; }
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
  // Langue : choix mémorisé, sinon langue du navigateur si disponible, sinon français.
  let LANG = (function () {
    const codes = LANGS.map(l => l.code);
    // Page monolingue (data-lang="fr" sur <body>) : on ne traduit ni le
    // chrome ni l'attribut lang, quel que soit le navigateur ou le choix mémorisé.
    const forced = (document.body.dataset.lang || "").slice(0, 2).toLowerCase();
    if (forced && codes.includes(forced)) return forced;
    let st = null; try { st = localStorage.getItem("vyb_lang"); } catch (e) {}
    if (st && codes.includes(st)) return st;
    const nav = (navigator.language || "fr").slice(0, 2).toLowerCase();
    return codes.includes(nav) ? nav : "fr";
  })();
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

  const STORE_BADGES = `<div class="storebadges "><a class="sbadge" href="https://apps.apple.com/app/id6772495371" target="_blank" rel="noopener" aria-label="Télécharger sur l'App Store"><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.6c0-2.5 2-3.7 2.1-3.8-1.2-1.7-3-1.9-3.6-2-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.8-1.7 0-3.2 1-4.1 2.5-1.8 3-.5 7.5 1.3 10 .8 1.2 1.8 2.6 3.2 2.5 1.3-.1 1.8-.8 3.3-.8s2 .8 3.3.8c1.4 0 2.3-1.2 3.1-2.5.9-1.4 1.3-2.7 1.4-2.8-.1 0-2.9-1.1-2.9-4zM13.9 5.1c.7-.8 1.2-2 1-3.1-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.9-1 3 1.1.1 2.2-.6 2.9-1.4z"/></svg><span><small>Télécharger sur</small>App Store</span></a><a class="sbadge" href="https://play.google.com/store/apps/details?id=com.app.vybzz" target="_blank" rel="noopener" aria-label="Disponible sur Google Play"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#34A853" d="M3.6 2.4 13 12l-9.4 9.6c-.4-.2-.6-.6-.6-1.1V3.5c0-.5.2-.9.6-1.1z"/><path fill="#FBBC04" d="M17 8 13 12l4 4 3.5-2c.7-.4.7-1.5 0-2L17 8z"/><path fill="#EA4335" d="M13 12 3.6 21.6c.4.3 1 .3 1.6 0L17 16l-4-4z"/><path fill="#4285F4" d="M13 12 17 8 5.2 2.4c-.6-.3-1.2-.3-1.6 0L13 12z"/></svg><span><small>Disponible sur</small>Google Play</span></a></div>`;
  /* ---------- Chrome : header + footer injectés ---------- */
  // Même menu que la page d'accueil (index.html) : Feed, Boutique, Le deal, FAQ.
  const NAV = [
    // Concert à la une : retiré automatiquement après la date (until, ISO UTC).
    { href: "dj-wilson.html",        key: "nav_djwilson", id: "dj-wilson", until: "2026-10-04T08:00:00Z", hot: true },
    { href: "feed.html",             key: "nav_feed",   id: "feed" },
    { href: "store.html",            key: "nav_store",  id: "store" },
    { href: "index.html#roles",      key: "nav_deal",   id: "_deal" },
    { href: "academie.html",         key: "nav_academy", id: "academie" },
    { href: "faq.html",              key: "nav_faq",    id: "faq" },
    // Live Challenge reporté : lien retiré du menu (remettre à la reprise).
  ];

  function renderHeader() {
    const links = NAV.filter(n => !n.until || Date.now() < Date.parse(n.until)).map(n =>
      `<a href="${n.href}" class="${n.id === page ? "active" : ""}${n.hot ? " nav__hot" : ""}" data-cursor="hover">${t(n.key)}</a>`
    ).join("");
    return `
    <header class="nav" id="nav">
      <a href="index.html" class="nav__brand" data-cursor="hover">
        <img src="assets/logo.svg" alt="" class="brand-logo" />
        <span class="brand">Vybzz<span style="color:var(--gold)">Z</span></span>
      </a>
      <nav class="nav__links" style="margin-left:auto">${links}</nav>
      <div class="nav__cta">
        ${document.body.dataset.lang ? "" : `<select class="langsel" aria-label="Langue" onchange="try{localStorage.setItem('vyb_lang',this.value)}catch(e){};location.reload()">${LANGS.map(l => `<option value="${l.code}" ${l.code === LANG ? "selected" : ""}>${l.name}</option>`).join("")}</select>`}
        <a href="app.html" class="btn btn--ghost nav__dl" data-cursor="hover">📲 ${t("nav_download")}</a>
        <a href="artist.html" class="btn btn--gold magnetic" data-cursor="hover"><span>${t("nav_apply")}</span></a>
      </div>
      <button class="nav__burger" id="burger" aria-label="Menu"><i></i><i></i><i></i></button>
    </header>
    ${["c", "challenge", "artist", "dj-wilson"].includes(page) ? "" : `<a href="app.html" class="dlbar">📲 <span>${t("nav_download")} VybzzZ</span> <b>${t("dlbar_open")}</b></a>`}`;
  }

  function renderFooter() {
    return `
    <footer class="footer">
      <div class="footer__top">
        <div class="footer__brand">
          <a href="index.html" class="nav__brand"><img src="assets/logo.svg" alt="" class="brand-logo" /><span class="brand">Vybzz<span style="color:var(--gold)">Z</span></span></a>
          <p>${t("foot_tagline")}</p>
        </div>
        <div class="footer__cols">
          <div><h4>${t("foot_discover")}</h4><a href="app.html">${t("nav_download")}</a><a href="feed.html">${t("nav_feed")}</a><a href="store.html">${t("nav_store")}</a><a href="index.html#roles">${t("nav_deal")}</a><a href="faq.html">${t("nav_faq")}</a></div>
          <div><h4>${t("foot_artists")}</h4><a href="artist.html">${t("nav_apply")}</a><a href="index.html#roles">${t("foot_roles")}</a><a href="academie.html">${t("nav_academy")}</a><a href="index.html#fondateurs">${t("foot_founders")}</a></div>
          <div><h4>${t("foot_help")}</h4><a href="index.html#reserver">${t("foot_book")}</a><a href="mailto:hello@vybzzz.online">hello@vybzzz.online</a><a href="mentions-legales.html">${t("foot_legal")}</a><a href="confidentialite.html">${t("foot_privacy")}</a><a href="cgu.html">${t("foot_terms")}</a></div>
        </div>
      </div>
      <div class="footer__stores">${STORE_BADGES.replace('class="storebadges ', 'class="storebadges storebadges--sm ')}</div>
      <div class="footer__bottom">
        <span>${t("foot_rights")}</span>
        <span class="footer__made">${t("foot_secure")}</span>
      </div>
    </footer>`;
  }

  /* ---------- Pixels publicitaires : point d'extension ----------
     Aucun script externe n'est chargé pour l'instant (pas d'identifiant Meta
     ou Google disponible). Quand il le sera : charger fbevents.js ici, puis
     remplacer le corps de chacun des quatre cas ci-dessous (fbq('track', …)).
     Appelé par les pages : PageView (ici), spin / InitiateCheckout / Purchase
     (dj-wilson.html). */
  window.vyPixel = function (evt, data) {
    switch (evt) {
      case "PageView":         /* PIXEL_META_PLACEHOLDER */ break;
      case "spin":             /* PIXEL_META_PLACEHOLDER */ break;
      case "InitiateCheckout": /* PIXEL_META_PLACEHOLDER */ break;
      case "Purchase":         /* PIXEL_META_PLACEHOLDER */ break;
    }
  };
  window.vyPixel("PageView");

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
      <a href="index.html#roles" class="vcard__thumb" title="Disponible dans l'appli VybzzZ">
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

  // ---- Feed public : VRAI contenu de l'API (clips, "Pour toi", lives) ----
  // Jouable sans compte. Chaque clip pousse vers l'app ; toutes les 4 vidéos,
  // une carte d'installation. Repli sur data.js si l'API ne répond pas.
  const LINKS = (D.links || {});
  const API = LINKS.api || "https://api.vybzzz.online/api";
  const appHref = "app.html";
  function storeButtons() {
    const b = [STORE_BADGES];
    if (LINKS.whatsapp) b.push(`<a class="btn btn--outline" href="${LINKS.whatsapp}" target="_blank" rel="noopener"><span>💬 Groupe WhatsApp</span></a>`);
    return b.join("");
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }
  function feedItemHTML(it) {
    const pid = it.video;
    const bg = pid ? `https://image.mux.com/${pid}/thumbnail.webp?width=720&fit_mode=smartcrop` : (it.thumb || "");
    const videoTag = pid
      ? `<video class="feed__video" data-src="https://stream.mux.com/${pid}.m3u8" poster="${bg}" muted loop playsinline preload="none"></video>`
      : "";
    const artist = it.artist ? `<div class="feed__artist">${it.artist.image ? `<img src="${esc(it.artist.image)}" alt="" loading="lazy">` : ""}<span>${esc(it.artist.name)}</span><a class="feed__follow" href="${appHref}">Suivre dans l'app</a></div>` : "";
    const badge = it.live ? liveBadge : (it.upcoming ? `<span class="badge-soon">${esc(it.when)}</span>` : (it.feed === "clips" ? `<span class="feed__cat">Clip</span>` : ""));
    const cta = it.upcoming
      ? `<a class="btn btn--gold feed__ticket" href="${appHref}"><span>${it.price ? "Prendre ma place · " + it.price + " €" : "Entrer gratuitement"}</span></a>`
      : "";
    return `
      <section class="feed__item" id="clip-${esc(it.id)}" style="--bg:url('${bg}')">
        ${videoTag}
        <div class="feed__overlay"></div>
        <div class="feed__content">
          <div class="feed__meta">${badge}</div>
          ${artist}
          ${it.name ? `<h2 class="feed__title">${esc(it.name)}</h2>` : ""}
          ${cta}
        </div>
        <aside class="feed__actions">
          <button class="fa-btn" data-act="like" data-cursor="hover"><span>♥</span>${it.likes ? `<i>${H.nb(it.likes)}</i>` : ""}</button>
          <button class="fa-btn" data-act="gift" data-cursor="hover"><span>🎁</span><i>Cadeau</i></button>
          <button class="fa-btn" data-act="share" data-id="${esc(it.id)}" data-name="${esc(it.name || (it.artist && it.artist.name) || "VybzzZ")}" data-cursor="hover"><span>↗</span><i>Partager</i></button>
        </aside>
      </section>`;
  }
  function feedCtaHTML() {
    return `
      <section class="feed__item feed__cta-item">
        <div class="feed__overlay"></div>
        <div class="feed__content" style="justify-content:center;text-align:center;align-items:center">
          <span class="eyebrow">Toute la scène est dans l'app</span>
          <h2 class="feed__title">Suis tes artistes, entre dans leurs lives, envoie des cadeaux.</h2>
          <p style="color:var(--muted);max-width:44ch;margin:0 0 18px">Ce que tu vois ici n'est qu'un extrait. Les lives en direct, le chat et les billets sont dans l'appli VybzzZ.</p>
          <div style="display:flex;gap:10px;flex-wrap:wrap;justify-content:center">${storeButtons()}</div>
        </div>
      </section>`;
  }
  function bindFeed(container) {
    container.addEventListener("click", e => {
      const b = e.target.closest(".fa-btn"); if (!b) return;
      const act = b.dataset.act;
      if (act === "like") { b.classList.toggle("liked"); toast(b.classList.contains("liked") ? "❤️ Pour de vrai, c'est dans l'app" : ""); }
      else if (act === "gift") { openGiftPanel(); }
      else if (act === "share") {
        const url = location.origin.startsWith("http") ? `${location.origin}/feed.html?clip=${b.dataset.id}` : `https://vybzzz.online/feed.html?clip=${b.dataset.id}`;
        const text = `${b.dataset.name} sur VybzzZ`;
        if (navigator.share) navigator.share({ title: "VybzzZ", text, url }).catch(() => {});
        else if (navigator.clipboard) navigator.clipboard.writeText(url).then(() => toast("Lien copié ✓"));
      }
    });
    initFeedVideos(container);
    bindMicro(container);
  }
  // ---- Lecture des vidéos Mux (autoplay muet quand visible, pause sinon) ----
  function attachHls(video, src) {
    if (window.Hls && window.Hls.isSupported()) { const h = new Hls({ capLevelToPlayerSize: true }); h.loadSource(src); h.attachMedia(video); }
    else { video.src = src; }   // Safari / iOS : HLS natif
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
  // ---- Chargement depuis l'API ----
  const getJSON = (u) => fetch(u).then(r => r.json());
  function fromClip(c) { return { id: c.id, video: c.mux_playback_id, name: c.title, artist: c.artist, likes: c.likes, feed: c.feed }; }
  function fromEvent(ev, live) {
    const d = ev.start_date_time ? new Date(ev.start_date_time) : null;
    const when = d ? d.toLocaleDateString("fr-FR", { weekday: "short", day: "numeric", month: "short" }) + " · " + d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" }) : "";
    const artist = ev.artist ? { id: ev.artist.id, name: ev.artist.artist_name || ev.artist.full_name || "Artiste", image: ev.artist.profile_image } : null;
    return { id: "ev" + ev.id, video: live ? (ev.mux_live_playback_id || ev.mux_playback_id) : null, thumb: ev.cover_image, name: ev.name, artist, live, upcoming: !live, when, price: Number(ev.ticket_price) || 0 };
  }
  async function loadFeed(kind) {
    if (kind === "lives") {
      const [live, future] = await Promise.all([getJSON(`${API}/events?status=live`).catch(() => ({})), getJSON(`${API}/events?day=future`).catch(() => ({}))]);
      return [...(live.data || []).map(e => fromEvent(e, true)), ...(future.data || []).filter(e => e.status !== "live").map(e => fromEvent(e, false))];
    }
    const feed = kind === "clips" ? "clips" : "for_you";
    const [clips, live] = await Promise.all([getJSON(`${API}/feed-clips?feed=${feed}&limit=40`), kind === "clips" ? Promise.resolve({}) : getJSON(`${API}/events?status=live`).catch(() => ({}))]);
    return [...(live.data || []).map(e => fromEvent(e, true)), ...(clips.list || []).map(fromClip)];
  }
  function withCtas(items) {
    const out = [];
    items.forEach((it, i) => { out.push(feedItemHTML(it)); if ((i + 1) % 4 === 0) out.push(feedCtaHTML()); });
    if (items.length && items.length % 4 !== 0) out.push(feedCtaHTML());
    return out.join("");
  }
  // ---- Montage du feed : onglets Pour toi / Clips / Lives + bouton son ----
  function setupFeed(feedEl, catsEl, soundEl) {
    if (!feedEl) return;
    let soundOn = false, current = "for_you";
    function applySound() { feedEl.querySelectorAll(".feed__video").forEach(v => { v.muted = !soundOn; }); }
    const wanted = new URLSearchParams(location.search).get("clip");
    async function show(kind) {
      current = kind;
      if (catsEl) catsEl.querySelectorAll(".feed__cat").forEach(b => b.classList.toggle("on", b.dataset.kind === kind));
      feedEl.innerHTML = `<section class="feed__item feed__empty"><div class="feed__content"><p style="color:var(--muted)">Chargement…</p></div></section>`;
      let items = [];
      try { items = await loadFeed(kind); } catch (e) { items = (D.events || []).map(ev => ({ id: ev.id, video: ev.video, name: ev.name, live: false })); }
      if (wanted && kind === "for_you") { const i = items.findIndex(x => String(x.id) === String(wanted)); if (i > 0) items.unshift(items.splice(i, 1)[0]); }
      feedEl.innerHTML = items.length ? withCtas(items) : `<section class="feed__item feed__empty"><div class="feed__content"><h2 class="feed__title">Rien ici pour l'instant.</h2><p style="color:var(--muted)">Les prochains lives s'annoncent dans l'app.</p>${storeButtons()}</div></section>`;
      feedEl.scrollTop = 0;
      bindFeed(feedEl);
      applySound();
    }
    if (catsEl) {
      catsEl.style.display = "";
      catsEl.innerHTML = [["for_you", "Pour toi"], ["clips", "Clips"], ["lives", "Lives"]].map(([k, l]) => `<button class="feed__cat" data-kind="${k}" data-cursor="hover">${l}</button>`).join("");
      catsEl.addEventListener("click", e => { const b = e.target.closest(".feed__cat"); if (b && b.dataset.kind !== current) show(b.dataset.kind); });
    }
    show(wanted ? "for_you" : "for_you");
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
        <a href="index.html#roles" class="btn ${p.featured ? "btn--gold" : "btn--outline"}" data-cursor="hover" title="${t("store_in_app")}"><span>${p.price.toLocaleString("fr-FR", { minimumFractionDigits: 2 })} €</span></a>
      </article>`;
    }).join("");
    // gifts catalogue
    const gg = document.getElementById("giftGrid");
    if (gg) gg.innerHTML = D.gifts.map(g =>
      `<div class="giftc giftc--lg reveal" data-cursor="hover"><span>${g.emoji}</span><strong>${g.name}</strong><small>★ ${g.coins} PTS</small></div>`).join("");
    // Merch officiel (print à la demande) : produits actifs de l'API, section masquée si vide
    const ms = document.getElementById("merchSection"), mg = document.getElementById("merchGrid");
    if (ms && mg) getJSON(`${API}/merch`).then(d => {
      const rows = d.data || []; if (!rows.length) return;
      mg.innerHTML = rows.map(p => `
        <article class="merch glass reveal" data-cursor="hover">
          <div class="merch__img">${p.image_url ? `<img src="${esc(p.image_url)}" alt="${esc(p.name)}" loading="lazy">` : ""}</div>
          <div class="merch__body">
            <h3>${esc(p.name)}</h3>
            <p>${esc(p.description || "")}</p>
            <div class="merch__row"><strong>${Number(p.price_eur).toLocaleString("fr-FR", { minimumFractionDigits: 2 })} €</strong>
              ${p.buy_url ? `<a class="btn btn--gold" href="${esc(p.buy_url)}" target="_blank" rel="noopener"><span>Commander</span></a>` : `<span class="btn btn--outline" style="opacity:.6;pointer-events:none"><span>Bientôt</span></span>`}
            </div>
          </div>
        </article>`).join("");
      ms.hidden = false; refresh(ms);
    }).catch(() => {});
    // (l'ancien bloc "plans Founder" n'existe plus : entrée gratuite, 50 %)
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

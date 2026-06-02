/* ============================================================
   VYBZZZ — Interactions & animations
   ============================================================ */
(function () {
  "use strict";
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- Preloader ---------- */
  window.addEventListener("load", () => {
    const pl = document.getElementById("preloader");
    setTimeout(() => pl && pl.classList.add("done"), 1600);
    playHeroIntro();
  });

  /* ---------- Hero intro (GSAP) ---------- */
  function playHeroIntro() {
    if (reduceMotion || typeof gsap === "undefined") {
      document.querySelectorAll(".hero__title .line>span").forEach(s => (s.style.transform = "none"));
      return;
    }
    gsap.to(".hero__title .line>span", {
      y: 0, duration: 1.1, ease: "power4.out", stagger: 0.12, delay: 1.7,
    });
    gsap.fromTo(".hero__badge, .hero__sub, .hero__actions, .hero__stats",
      { y: 30, opacity: 0 },
      { y: 0, opacity: 1, duration: 0.9, ease: "power3.out", stagger: 0.12, delay: 2.1 }
    );
    gsap.fromTo(".hero__phone",
      { x: 60, opacity: 0, rotate: 4 },
      { x: 0, opacity: 1, rotate: 0, duration: 1.2, ease: "power3.out", delay: 2.2 }
    );
  }

  /* ---------- Navbar scroll state ---------- */
  const nav = document.getElementById("nav");
  const progress = document.getElementById("scrollProgress");
  const onScroll = () => {
    nav.classList.toggle("scrolled", window.scrollY > 40);
    const h = document.documentElement.scrollHeight - window.innerHeight;
    progress.style.width = (window.scrollY / h) * 100 + "%";
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- Mobile menu ---------- */
  const burger = document.getElementById("burger");
  burger && burger.addEventListener("click", () => nav.classList.toggle("open"));
  document.querySelectorAll(".nav__links a").forEach(a =>
    a.addEventListener("click", () => nav.classList.remove("open"))
  );

  /* ---------- Custom cursor ---------- */
  const cursor = document.getElementById("cursor");
  const dot = document.getElementById("cursorDot");
  if (cursor && window.matchMedia("(hover:hover)").matches) {
    let cx = 0, cy = 0, tx = 0, ty = 0;
    window.addEventListener("mousemove", e => {
      tx = e.clientX; ty = e.clientY;
      dot.style.transform = `translate(${tx}px,${ty}px) translate(-50%,-50%)`;
    });
    (function loop() {
      cx += (tx - cx) * 0.18; cy += (ty - cy) * 0.18;
      cursor.style.transform = `translate(${cx}px,${cy}px) translate(-50%,-50%)`;
      requestAnimationFrame(loop);
    })();
    document.querySelectorAll('[data-cursor="hover"]').forEach(el => {
      el.addEventListener("mouseenter", () => cursor.classList.add("is-hover"));
      el.addEventListener("mouseleave", () => cursor.classList.remove("is-hover"));
    });
  }

  /* ---------- Magnetic buttons ---------- */
  if (!reduceMotion) {
    document.querySelectorAll(".magnetic").forEach(el => {
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        const mx = e.clientX - r.left - r.width / 2;
        const my = e.clientY - r.top - r.height / 2;
        el.style.transform = `translate(${mx * 0.3}px, ${my * 0.4}px)`;
      });
      el.addEventListener("mouseleave", () => (el.style.transform = ""));
    });
  }

  /* ---------- 3D tilt cards ---------- */
  if (!reduceMotion && window.matchMedia("(hover:hover)").matches) {
    document.querySelectorAll(".tilt").forEach(el => {
      el.style.transformStyle = "preserve-3d";
      el.addEventListener("mousemove", e => {
        const r = el.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - 0.5;
        const py = (e.clientY - r.top) / r.height - 0.5;
        el.style.transform = `perspective(900px) rotateY(${px * 9}deg) rotateX(${-py * 9}deg) translateY(-4px)`;
      });
      el.addEventListener("mouseleave", () => (el.style.transform = ""));
    });
  }

  /* ---------- Reveal on scroll ---------- */
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
    });
  }, { threshold: 0.15, rootMargin: "0px 0px -8% 0px" });
  document.querySelectorAll(".reveal").forEach(el => io.observe(el));

  /* ---------- Dashboard chart draw ---------- */
  const dash = document.querySelector(".dash");
  if (dash) {
    new IntersectionObserver((entries, obs) => {
      entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add("in"); obs.disconnect(); } });
    }, { threshold: 0.4 }).observe(dash);
  }

  /* ---------- Count-up numbers ---------- */
  function countUp(el) {
    const target = parseFloat(el.dataset.count);
    const dur = 1600, start = performance.now();
    const isFloat = target % 1 !== 0;
    function tick(now) {
      const p = Math.min((now - start) / dur, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      const val = target * eased;
      el.textContent = isFloat ? val.toFixed(1) : Math.round(val).toLocaleString("fr-FR");
      if (p < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }
  const countIO = new IntersectionObserver((entries, obs) => {
    entries.forEach(e => { if (e.isIntersecting) { countUp(e.target); obs.unobserve(e.target); } });
  }, { threshold: 0.6 });
  document.querySelectorAll("[data-count]").forEach(el => countIO.observe(el));

  /* ---------- Parallax (GSAP ScrollTrigger) ---------- */
  if (!reduceMotion && typeof gsap !== "undefined" && typeof ScrollTrigger !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
    document.querySelectorAll("[data-parallax]").forEach(el => {
      const speed = parseFloat(el.dataset.parallax);
      gsap.to(el, {
        yPercent: speed * 100,
        ease: "none",
        scrollTrigger: { trigger: el, start: "top bottom", end: "bottom top", scrub: true },
      });
    });
  }

  /* ---------- Artists carousel (data-driven) ---------- */
  const artists = [
    { name: "NOVA", genre: "Afrobeats", img: "assets/artist_image1.png", viewers: "8.2K", live: true },
    { name: "Layla Skye", genre: "R&B / Soul", img: "assets/artist_image2.png", viewers: "5.7K", live: true },
    { name: "Kairo", genre: "Hip-Hop", img: "assets/artist_image3.png", viewers: "12K", live: true },
    { name: "Mira Sound", genre: "Électro", img: "assets/artist_image4.png", viewers: "3.1K", live: false },
    { name: "DJ Volt", genre: "House", img: "assets/artist_image5.png", viewers: "9.4K", live: true },
    { name: "Selene", genre: "Pop", img: "assets/artist_image1.png", viewers: "6.8K", live: false },
  ];
  const row = document.getElementById("artistsRow");
  if (row) {
    row.innerHTML = artists.map(a => `
      <article class="artist-card reveal" data-cursor="hover">
        ${a.live ? '<span class="artist-card__live"><span class="pulse-dot"></span> LIVE</span>' : ""}
        <img src="${a.img}" alt="${a.name}" loading="lazy" />
        <div class="artist-card__body">
          <h3>${a.name}</h3>
          <small>${a.genre}</small>
          <div class="artist-card__meta">
            <span>👁 ${a.viewers}</span>
            <span>${a.live ? "🔴 En direct" : "⏰ Bientôt"}</span>
          </div>
        </div>
      </article>`).join("");
    // re-observe newly injected reveals + tilt + cursor
    row.querySelectorAll(".reveal").forEach(el => io.observe(el));
  }

  /* ---------- Smooth anchor offset ---------- */
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener("click", e => {
      const id = a.getAttribute("href");
      if (id.length < 2) return;
      const t = document.querySelector(id);
      if (t) { e.preventDefault(); window.scrollTo({ top: t.offsetTop - 70, behavior: "smooth" }); }
    });
  });
})();

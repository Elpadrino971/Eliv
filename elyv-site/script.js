/* Elyv — moteur de défilement cinématique.
   Lit la position de défilement dans la section collante, la lisse, et
   écrit des variables CSS sur :root. Chaque scène est un segment du
   défilement (en px) : entrée, plateau, sortie.
     0    – 650  : titre ELYV et accroche s'effacent, les portes restent fermées
     560  – 1620 : les deux moitiés de la colonnade s'ouvrent → réception (scène 2)
     1760 – 2700 : allée au coucher du soleil (scène 1) → panneau cagnotte
     2600 – 3100 : rotonde du gâteau (scène 3) apparaît en fond
     2760 – 3660 : le carrousel des moments entre par la droite, puis ses boutons */
(() => {
  'use strict';

  const section = document.querySelector('.cinema-scroll');
  const root = document.documentElement;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const track = document.querySelector('.sights-track');
  const sightsControls = document.querySelector('.sights-controls');
  const prevButton = document.querySelector('.sight-prev');
  const nextButton = document.querySelector('.sight-next');
  const originalCards = Array.from(document.querySelectorAll('.sight-card'));

  if (!section || !track) return;

  let targetMouseX = 0, targetMouseY = 0;
  let mouseX = 0, mouseY = 0;
  let targetScroll = 0, smoothScroll = 0;
  let initialized = false;
  let rafPending = false;
  let sightCards = [];
  const originalSightCount = originalCards.length;
  let activeSight = originalSightCount;

  // ── Utilitaires ─────────────────────────────────────────────────────
  const clamp = (v, min = 0, max = 1) => Math.min(max, Math.max(min, v));
  const smoothstep = (e0, e1, v) => {
    const x = clamp((v - e0) / (e1 - e0));
    return x * x * (3 - 2 * x);
  };
  const lerp = (a, b, t) => a + (b - a) * t;
  const segmentInOut = (s, a, b, c, d) => {
    const enter = smoothstep(a, b, s);
    const exit = smoothstep(c, d, s);
    return { enter, exit, active: enter * (1 - exit) };
  };
  const getScrollDistance = () =>
    clamp(-section.getBoundingClientRect().top, 0, section.offsetHeight - window.innerHeight);
  const setVar = (name, value) => root.style.setProperty(name, String(value));

  // ── Image par image ──────────────────────────────────────────────────
  function update() {
    rafPending = false;

    targetScroll = getScrollDistance();
    if (!initialized || reduceMotion.matches) {
      smoothScroll = targetScroll;
      initialized = true;
    } else {
      smoothScroll = lerp(smoothScroll, targetScroll, 0.14);
    }
    if (Math.abs(smoothScroll - targetScroll) < 0.08) smoothScroll = targetScroll;

    mouseX = lerp(mouseX, targetMouseX, 0.12);
    mouseY = lerp(mouseY, targetMouseY, 0.12);
    const mx = reduceMotion.matches ? 0 : mouseX;
    const my = reduceMotion.matches ? 0 : mouseY;

    const frame2 = segmentInOut(smoothScroll, 560, 900, 1300, 1620);
    const frame3 = segmentInOut(smoothScroll, 1760, 2140, 2540, 2700);
    const frame4 = smoothstep(2600, 3100, smoothScroll);
    const progress = clamp(smoothScroll / 2700);
    const introExit = smoothstep(90, 650, smoothScroll);
    const sightsEnterRaw = smoothstep(2760, 3560, smoothScroll);
    const sightsEnter = Math.pow(sightsEnterRaw, 1.55);
    const sightsControlsEnter = smoothstep(3360, 3660, smoothScroll);
    const blurActive = clamp(frame2.active + frame3.active);
    const frame2Opacity = frame2.active * (1 - frame3.enter);
    const splitDrift = Math.pow(frame2.enter, 1.5);
    const panel2Opacity = frame2.active * (1 - frame2.exit);
    const panel3Opacity = frame3.active * (1 - frame3.exit);
    const backScale = 0.76 + progress * 0.2 + frame2.enter * 0.18 + frame3.enter * 0.16;
    const sharedHeroY = progress * -74;
    const sharedHeroScale = progress * 0.23;
    const sightsScreenTop = Math.min(220, Math.max(112, window.innerHeight * 0.19)) - 50;
    const sightsParentTop = window.innerHeight - (window.innerHeight - sightsScreenTop) / backScale;

    setVar('--mx', mx.toFixed(4));
    setVar('--my', my.toFixed(4));

    // Ciel (scène 1) : parallaxe légère, flou et assombrissement pendant le
    // panneau cagnotte pour garder le texte lisible.
    setVar('--sky-x', `${mx * -14}px`);
    setVar('--sky-y', `${my * -6}px`);
    setVar('--blur-px', `${(frame3.active * 5).toFixed(2)}px`);
    setVar('--back-brightness', (1 - frame3.active * 0.3).toFixed(4));

    // Pile arrière : zoom continu, porte le carrousel contre-mis à l'échelle.
    setVar('--back-opacity', (1 - frame2.active * 0.06).toFixed(4));
    setVar('--back-x', `${mx * -12}px`);
    setVar('--back-y', `${my * -4}px`);
    setVar('--back-scale', backScale.toFixed(4));

    // Rotonde du gâteau (scène 3) : fond de la scène des moments.
    setVar('--bazaar-opacity', frame4.toFixed(4));
    setVar('--bazaar-y', `${(1 - frame4) * 40}px`);
    setVar('--bazaar-scale', (1 + (1 - frame4) * 0.06).toFixed(4));
    setVar('--bazaar-blur-px', `${(sightsEnter * 6).toFixed(2)}px`);
    setVar('--bazaar-brightness', (1 - sightsEnter * 0.3).toFixed(4));
    setVar('--bazaar-saturation', (1 + frame4 * 0.18).toFixed(4));

    // Voile : au-dessus du ciel pendant les panneaux, en dessous du
    // carrousel ensuite (sinon il assombrirait les cartes).
    setVar('--shade-opacity', '1');
    setVar('--shade-z', blurActive > 0.02 ? '2' : '0');
    setVar('--shade-top-alpha', (frame3.active * 0.4).toFixed(4));
    setVar('--shade-mid-alpha', (frame3.active * 0.34).toFixed(4));
    setVar('--shade-bottom-alpha', (frame3.active * 0.48).toFixed(4));
    setVar('--hero-shade-opacity', (1 - frame2.enter).toFixed(4));

    // Titre et accroche.
    setVar('--title-y', `${(introExit * -210).toFixed(2)}px`);
    setVar('--title-scale', (1 - introExit * 0.08).toFixed(4));
    setVar('--title-opacity', (1 - introExit).toFixed(4));
    setVar('--intro-copy-y', `${(introExit * 90).toFixed(2)}px`);
    setVar('--intro-copy-opacity', (1 - introExit).toFixed(4));

    // Colonnade (scène 4) : deux moitiés pleines (pas des découpes), donc
    // elles doivent glisser bien au-delà du bord pour disparaître (110vw).
    setVar('--split-left-x', `calc(${(-splitDrift * 110).toFixed(3)}vw + ${(mx * 22).toFixed(2)}px)`);
    setVar('--split-left-y', `${(my * 10 + sharedHeroY - splitDrift * 120).toFixed(2)}px`);
    setVar('--split-left-scale', (1 + sharedHeroScale + frame2.enter * 0.3).toFixed(4));
    setVar('--split-right-x', `calc(${(splitDrift * 110).toFixed(3)}vw + ${(mx * 22).toFixed(2)}px)`);
    setVar('--split-right-y', `${(my * 10 + sharedHeroY - splitDrift * 120).toFixed(2)}px`);
    setVar('--split-right-scale', (1 + sharedHeroScale + frame2.enter * 0.3).toFixed(4));

    // Réception (scène 2) : révélée derrière les portes, assombrie sous le
    // panneau, puis s'envole vers le haut.
    setVar('--frame2-opacity', frame2Opacity.toFixed(4));
    setVar('--frame2-x', `${(mx * 10).toFixed(2)}px`);
    setVar('--frame2-y', `${(my * 8 - frame2.exit * 150).toFixed(2)}px`);
    setVar('--frame2-scale', (1.06 + frame2.enter * 0.08 + frame2.exit * 0.08).toFixed(4));
    setVar('--frame2-brightness', (1 - panel2Opacity * 0.42).toFixed(4));

    // Panneaux de récit.
    setVar('--panel2-opacity', panel2Opacity.toFixed(4));
    setVar('--panel2-y', `calc(-50% + ${(-frame2.exit * 86 + (1 - frame2.enter) * 58).toFixed(2)}px)`);
    setVar('--panel3-opacity', panel3Opacity.toFixed(4));
    setVar('--panel3-y', `calc(-50% + ${(-frame3.exit * 86 + (1 - frame3.enter) * 58).toFixed(2)}px)`);

    // Carrousel des moments.
    setVar('--sights-opacity', sightsEnter.toFixed(4));
    setVar('--sights-controls-opacity', sightsControlsEnter.toFixed(4));
    sightsControls.classList.toggle('is-ready', sightsControlsEnter > 0.98);
    setVar('--sights-visibility', sightsEnter > 0.01 ? 'visible' : 'hidden');
    setVar('--sights-y', '0px');
    setVar('--sights-enter-x', `${((1 - sightsEnter) * 420).toFixed(3)}vw`);
    setVar('--sights-scale', (1 / backScale).toFixed(5));
    setVar('--sights-top', `${sightsParentTop.toFixed(2)}px`);
    setVar('--sights-screen-top', `${sightsScreenTop.toFixed(2)}px`);
    // La pile arrière (106vw de large) est mise à l'échelle autour de son
    // centre : on résout la position de son bord gauche à l'écran pour que la
    // première carte s'aligne sur les boutons (48px, 24px sur mobile).
    const viewportWidth = window.innerWidth;
    const sightsScreenLeft = viewportWidth <= 640 ? 24 : 48;
    const backStackLeft = viewportWidth / 2 - viewportWidth * 0.53 * backScale;
    setVar('--sights-left', `${((sightsScreenLeft - backStackLeft) / backScale).toFixed(2)}px`);

    const scrollSettling = Math.abs(smoothScroll - targetScroll) > 0.08;
    const mouseSettling = Math.abs(mouseX - targetMouseX) > 0.001 || Math.abs(mouseY - targetMouseY) > 0.001;
    if (scrollSettling || mouseSettling) requestTick();
  }

  function requestTick() {
    if (rafPending) return;
    rafPending = true;
    requestAnimationFrame(update);
  }

  // ── Carrousel infini : trois jeux de cartes, saut invisible aux bords ─
  function setupSightSlider() {
    track.replaceChildren();
    for (let setIndex = 0; setIndex < 3; setIndex += 1) {
      originalCards.forEach((card, cardIndex) => {
        const clone = card.cloneNode(true);
        clone.dataset.sightIndex = String(setIndex * originalSightCount + cardIndex);
        track.appendChild(clone);
      });
    }
    sightCards = Array.from(track.querySelectorAll('.sight-card'));
    activeSight = originalSightCount;
    sightCards.forEach((card) => {
      card.addEventListener('click', () => selectSightCard(card));
      card.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          selectSightCard(card);
        }
      });
    });
    track.addEventListener('transitionend', normalizeSightSlider);
    updateSightSlider();
  }

  function updateSightSlider() {
    if (!sightCards.length) return;
    const cardWidth = sightCards[0].offsetWidth;
    const gap = parseFloat(getComputedStyle(track).columnGap || '0') || 0;
    setVar('--sights-shift', `${-(cardWidth + gap) * activeSight}px`);
    sightCards.forEach((card, index) => card.classList.toggle('is-active', index === activeSight));
  }

  function moveSightSlider(direction) {
    activeSight += direction;
    updateSightSlider();
  }

  function selectSightCard(card) {
    const index = Number(card.dataset.sightIndex);
    if (Number.isFinite(index)) activeSight = index;
    updateSightSlider();
  }

  function jumpSightSlider(index) {
    track.classList.add('is-jumping');
    activeSight = index;
    updateSightSlider();
    requestAnimationFrame(() => {
      requestAnimationFrame(() => track.classList.remove('is-jumping'));
    });
  }

  function normalizeSightSlider() {
    if (activeSight >= originalSightCount * 2) jumpSightSlider(activeSight - originalSightCount);
    else if (activeSight < originalSightCount) jumpSightSlider(activeSight + originalSightCount);
  }

  // ── Navigation : chaque lien vise une position du défilement ────────
  function scrollToStory(offset) {
    const top = section.getBoundingClientRect().top + window.scrollY + offset;
    window.scrollTo({ top, behavior: reduceMotion.matches ? 'auto' : 'smooth' });
  }
  document.querySelectorAll('[data-scroll]').forEach((el) => {
    el.addEventListener('click', (event) => {
      event.preventDefault();
      scrollToStory(Number(el.dataset.scroll) || 0);
    });
  });

  // ── Écouteurs ───────────────────────────────────────────────────────
  window.addEventListener('scroll', requestTick, { passive: true });
  window.addEventListener('resize', () => { updateSightSlider(); requestTick(); });
  window.addEventListener('pointermove', (event) => {
    targetMouseX = event.clientX / window.innerWidth - 0.5;
    targetMouseY = event.clientY / window.innerHeight - 0.5;
    requestTick();
  }, { passive: true });
  prevButton.addEventListener('click', () => moveSightSlider(-1));
  nextButton.addEventListener('click', () => moveSightSlider(1));
  reduceMotion.addEventListener('change', requestTick);

  setupSightSlider();
  requestTick();
})();

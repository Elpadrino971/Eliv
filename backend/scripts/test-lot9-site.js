#!/usr/bin/env node
'use strict';
/**
 * Lot 9 — rendu Playwright de la ligne d'urgence « Passe à 9,99 € dans 5 h 12 »
 * sur site/dj-wilson.html (file://, API mockée, réseau externe coupé).
 *
 *   NODE_PATH=$(npm root -g) PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node scripts/test-lot9-site.js
 *
 * Sort en erreur (exit 1) si la ligne n'apparaît pas avec le bon texte, ou si
 * elle reste visible quand l'API ne renvoie pas de prochain palier.
 */
const path = require('path');
const { chromium } = require('playwright');

const PAGE = 'file://' + path.resolve(__dirname, '../../site/dj-wilson.html');
let fails = 0;
const check = (label, ok) => { console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${label}`); if (!ok) fails++; };

async function render(browser, status) {
  const ctx = await browser.newContext({ viewport: { width: 1200, height: 900 } });
  const page = await ctx.newPage();
  // API mockée ; tout autre réseau (polices, pixels, CDN) est coupé.
  await page.route('**/*', (route) => {
    const url = route.request().url();
    if (url.startsWith('file://')) return route.continue();
    if (url.startsWith('https://api.vybzzz.online/api/campaign/dj-wilson')) {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'success', data: status }) });
    }
    return route.abort();
  });
  await page.goto(PAGE, { waitUntil: 'load' });
  await page.waitForTimeout(400);
  const hero = page.locator('#dwNext');
  const ticket = page.locator('#ticketCard .js-next');
  return {
    heroHidden: await hero.evaluate((el) => el.hidden),
    heroText: (await hero.textContent()).trim(),
    ticketHidden: await ticket.evaluate((el) => el.hidden),
    ticketText: (await ticket.textContent()).trim(),
    price: (await page.locator('.dw-price .js-price').textContent()).trim(),
    ctx,
  };
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const base = {
    slug: 'dj-wilson', title: 'DJ Wilson — Anniversaire', wheel_open: true, places: 100, remaining: 42, odds: 0.25,
    starts_at: '2026-10-04T03:50:00Z', wheel_closes_at: '2026-10-04T03:20:00Z', ticketing_open: true, event_id: 1,
  };

  console.log('## 1. prochain palier dans 5 h 12 -> ligne visible (hero + billetterie)');
  const in5h12 = new Date(Date.now() + (5 * 60 + 12) * 60 * 1000 + 20 * 1000).toISOString();
  let r = await render(browser, { ...base, price: '6.99', next_price: '9.99', next_price_at: in5h12 });
  console.log(`  hero: « ${r.heroText} » · billetterie: « ${r.ticketText} » · prix: ${r.price}`);
  check('prix effectif affiché 6,99 €', r.price === '6,99 €');
  check('hero visible « Passe à 9,99 € dans 5 h 12 »', !r.heroHidden && r.heroText === 'Passe à 9,99 € dans 5 h 12');
  check('billetterie : même ligne', !r.ticketHidden && r.ticketText === 'Passe à 9,99 € dans 5 h 12');
  await r.ctx.close();

  console.log('## 2. au-delà de 24 h -> « dans 2 j 3 h »');
  const in2d3h = new Date(Date.now() + (51 * 60 + 5) * 60 * 1000).toISOString();
  r = await render(browser, { ...base, price: '4.99', next_price: '6.99', next_price_at: in2d3h });
  console.log(`  hero: « ${r.heroText} »`);
  check('format jours/heures', r.heroText === 'Passe à 6,99 € dans 2 j 3 h');
  await r.ctx.close();

  console.log('## 3. sans prochain palier -> ligne masquée');
  r = await render(browser, { ...base, price: '9.99', next_price: null, next_price_at: null });
  check('hero masqué', r.heroHidden && r.heroText === '');
  check('billetterie masquée', r.ticketHidden);
  await r.ctx.close();

  console.log('## 4. palier déjà passé (next_price_at dans le passé) -> masqué, statut rechargé');
  r = await render(browser, { ...base, price: '9.99', next_price: '9.99', next_price_at: new Date(Date.now() - 60000).toISOString() });
  check('hero masqué', r.heroHidden);
  await r.ctx.close();

  await browser.close();
  console.log(fails ? `\n${fails} échec(s)` : '\nsite : tout passe');
  process.exit(fails ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });

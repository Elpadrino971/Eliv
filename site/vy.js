/* VybzzZ — mesure d'audience. Sans cookie, sans stockage, sans donnée personnelle.
   Une vue de page à l'arrivée, puis quelques actions clés. N'attend jamais de réponse. */
(function () {
  var API = (window.VYBZZZ && window.VYBZZZ.links && window.VYBZZZ.links.api) || 'https://api.vybzzz.online/api';
  if (location.protocol === 'file:') return;                 // aperçus locaux : on ne compte pas
  if (navigator.webdriver) return;                           // navigateurs pilotés : idem

  function send(name) {
    try {
      // Paramètres de campagne (?utm_source=...&utm_campaign=...) : transmis
      // pour que la conversion reste rattachée à la publicité qui a amené le
      // visiteur, et pas à la page précédente.
      var q = new URLSearchParams(location.search);
      var body = JSON.stringify({
        n: name, p: location.pathname, r: document.referrer, l: navigator.language,
        us: q.get('utm_source') || '', uc: q.get('utm_campaign') || q.get('utm_content') || '',
      });
      // fetch + keepalive, et NON sendBeacon : un beacon part toujours en mode
      // « credentials: include », et le navigateur refuse alors une réponse dont
      // l'origine autorisée est le joker « * ». Résultat : la requête partait
      // mais était rejetée, sans la moindre erreur visible. keepalive survit de
      // la même façon à la fermeture de la page.
      fetch(API + '/track', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: body, keepalive: true, credentials: 'omit', mode: 'cors',
      }).catch(function () {
        if (navigator.sendBeacon) navigator.sendBeacon(API + '/track', new Blob([body], { type: 'text/plain' }));
      });
    } catch (e) {}
  }
  window.vyTrack = send;

  // Vue de page, une fois la page affichée pour ne rien ralentir.
  if (document.readyState === 'complete') send('pageview');
  else addEventListener('load', function () { send('pageview'); }, { once: true });

  // Actions clés : un clic suffit, on ne piste aucun mouvement.
  addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a,button');
    if (!a) return;
    var href = (a.getAttribute && a.getAttribute('href')) || '';
    var txt = (a.textContent || '').trim().toLowerCase();
    if (a.classList && a.classList.contains('sbadge')) return send('store_click');
    if (/app\.html/.test(href)) return send('app_page');
    if (/wa\.me|whatsapp/.test(href)) return send('whatsapp_click');
    if (/challenge\.html/.test(href)) return send('cta_challenge');
    if (/artist\.html/.test(href) || /postuler|apply|participe/.test(txt)) return send('cta_apply');
    if (a.id === 'lbCopy' || a.id === 'lbShare') return send('share_link');
  }, { passive: true, capture: true });
})();

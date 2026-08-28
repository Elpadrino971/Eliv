'use strict';

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const path = require('path');

const { init } = require('./db');
const authRoutes = require('./routes/auth.routes');
const eventRoutes = require('./routes/events.routes');
const miscRoutes = require('./routes/misc.routes');
const adminRoutes = require('./routes/admin.routes');
const muxWebhookRoutes = require('./routes/mux.routes');
const stripeWebhookRoutes = require('./routes/stripe.routes');
const revenuecatWebhookRoutes = require('./routes/revenuecat.routes');
const moderationRoutes = require('./routes/moderation.routes');

init();

const app = express();
// Derrière le reverse-proxy (Nginx/Hostinger) : nécessaire pour que le
// rate-limit voie la vraie IP client (X-Forwarded-For) et pas celle du proxy.
app.set('trust proxy', 1);
app.use(helmet()); // en-têtes de sécurité HTTP (XSS, sniffing, frame, etc.)
app.use(cors());

// Webhooks Mux/Stripe : montés AVANT express.json() car la vérification de
// signature a besoin du corps brut exact (Buffer), pas du JSON déjà parsé.
app.use('/api/mux/webhook', express.raw({ type: '*/*' }), muxWebhookRoutes);
app.use('/api/stripe/webhook', express.raw({ type: '*/*' }), stripeWebhookRoutes);

// L'app Flutter envoie soit du form-urlencoded (Map<String,String>),
// soit du JSON, soit du multipart (uploads). On gère les trois.
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Rate limiting anti-brute-force ────────────────────────────────────────
// Protège les endpoints d'authentification (login, inscription, OTP, reset)
// contre les tentatives massives de mots de passe / d'énumération. 20 requêtes
// par IP toutes les 15 min : large pour un usage normal, bloque un bot.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 'error', message: 'Trop de tentatives, réessaie dans quelques minutes.' },
});
app.use(
  [
    '/api/login',
    '/api/sign-up',
    '/api/social-login',
    '/api/forget',
    '/api/reset-password',
    '/api/update-password',
    '/api/verify',
    '/api/admin/login',
  ],
  authLimiter,
);

const fs = require('fs');
const uploadsDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true }); // dossier temp multer (créé au démarrage)
// Limites d'upload : 200 Mo/fichier et 12 fichiers max (les grosses vidéos de
// concert passent par l'upload direct Mux, pas par ce serveur). Filtre de type :
// on n'accepte que des médias (image/vidéo/audio) — bloque scripts/exécutables.
const ALLOWED_UPLOAD = /^(image|video|audio)\//;
// Extensions média connues : filet de sécurité quand le MIME est générique.
// Flutter (http.MultipartFile.fromPath) n'envoie PAS de Content-Type -> le
// fichier arrive en 'application/octet-stream' et l'ancien filtre le rejetait
// (photo de profil "Type de fichier non supporté"). On accepte alors sur
// l'extension. Les scripts/exécutables restent bloqués (ni MIME média ni ext).
const ALLOWED_UPLOAD_EXT = /\.(jpe?g|png|gif|webp|heic|heif|bmp|tiff?|mp4|mov|m4v|webm|mkv|avi|mp3|m4a|aac|wav|ogg|flac)$/i;
const upload = multer({
  dest: uploadsDir,
  limits: { fileSize: 200 * 1024 * 1024, files: 12 },
  fileFilter: (req, file, cb) => {
    const mime = file.mimetype || '';
    const name = file.originalname || '';
    if (ALLOWED_UPLOAD.test(mime) || ALLOWED_UPLOAD_EXT.test(name)) {
      return cb(null, true);
    }
    cb(new Error('UNSUPPORTED_FILE_TYPE'));
  },
});
app.use(upload.any()); // accepte n'importe quel champ fichier (profile_picture, images[], …)

// Fichiers statiques (covers, profils, vidéos, gifts) — mêmes chemins que l'API live
app.use('/profiles', express.static(path.join(__dirname, '..', 'storage', 'profiles')));
app.use('/events/covers', express.static(path.join(__dirname, '..', 'storage', 'covers')));
app.use('/events/videos', express.static(path.join(__dirname, '..', 'storage', 'videos')));
app.use('/giftImages', express.static(path.join(__dirname, '..', 'storage', 'gifts')));
app.use('/splash', express.static(path.join(__dirname, '..', 'storage', 'splash')));

// Santé
app.get('/', (req, res) => res.json({ status: 'success', service: 'vybzzz-backend', version: '1.0.0' }));
app.get('/api', (req, res) => res.json({ status: 'success', message: 'VYBZZZ API up' }));

// Pages de retour Stripe Checkout (success_url / cancel_url) — le webhook
// active déjà l'abonnement en tâche de fond, ces pages ne font qu'informer.
app.get('/subscribe/merci', (req, res) => res.send(
  '<html><body style="font-family:sans-serif;text-align:center;padding:60px;background:#071426;color:#f4efe6"><h1>Merci ! 🎉</h1><p>Ton abonnement est en cours d\'activation, retourne sur l\'app VybzzZ.</p></body></html>'
));
app.get('/subscribe/annule', (req, res) => res.send(
  '<html><body style="font-family:sans-serif;text-align:center;padding:60px;background:#071426;color:#f4efe6"><h1>Paiement annulé</h1><p>Aucun montant n\'a été prélevé. Retourne sur l\'app VybzzZ pour réessayer.</p></body></html>'
));

// Page publique de validation d'un CODE APPORTEUR (parrainage). L'artiste se
// connecte + saisit le code -> rattaché à l'apporteur + offre activée. Aucune
// modif de l'app nécessaire (donc aucune review Apple). Le code peut être
// pré-rempli via ?code=XXX (lien partageable par l'apporteur).
app.get('/rejoindre', (req, res) => res.send(`<!doctype html><html lang="fr"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rejoindre VybzzZ</title>
<style>
  *{box-sizing:border-box} body{margin:0;min-height:100vh;display:grid;place-items:center;
   background:#0A1226;color:#F4EFE3;font-family:-apple-system,Helvetica,Arial,sans-serif;padding:20px}
  .card{width:100%;max-width:380px;background:#111B33;border:1px solid rgba(230,199,106,.25);
   border-radius:18px;padding:28px}
  h1{margin:0 0 4px;font-size:24px} h1 span{color:#E6C76A}
  p{margin:0 0 20px;color:#C9C4B4;font-size:14px}
  input{width:100%;margin:0 0 12px;padding:13px 14px;border-radius:11px;border:1px solid rgba(230,199,106,.25);
   background:#0D1528;color:#F4EFE3;font-size:15px}
  button{width:100%;padding:14px;border:0;border-radius:11px;background:#E6C76A;color:#0A1226;
   font-weight:800;font-size:16px;cursor:pointer;margin-top:4px}
  #msg{margin-top:14px;font-size:14px;text-align:center;min-height:20px}
  #code{text-transform:uppercase;letter-spacing:1px;font-weight:700}
</style></head><body>
<div class="card">
  <h1>Rejoindre <span>VybzzZ</span></h1>
  <p>Connecte-toi avec ton compte VybzzZ et valide ton code pour activer ton offre.</p>
  <input id="email" type="email" placeholder="Email" autocomplete="username">
  <input id="pass" type="password" placeholder="Mot de passe" autocomplete="current-password">
  <input id="code" placeholder="Code apporteur">
  <button id="go">Valider mon code</button>
  <div id="msg"></div>
</div>
<script>
  var q=new URLSearchParams(location.search); if(q.get('code'))document.getElementById('code').value=q.get('code');
  document.getElementById('go').onclick=async function(){
    var m=document.getElementById('msg'); m.style.color='#C9C4B4'; m.textContent='Validation…';
    try{
      var l=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({email:document.getElementById('email').value.trim(),password:document.getElementById('pass').value})});
      var lj=await l.json(); if(!l.ok||!lj.token) throw new Error(lj.message||'Connexion échouée');
      var r=await fetch('/api/apporteur/redeem',{method:'POST',
        headers:{'Content-Type':'application/json','Authorization':'Bearer '+lj.token},
        body:JSON.stringify({code:document.getElementById('code').value.trim()})});
      var rj=await r.json(); if(!r.ok) throw new Error(rj.message||'Échec');
      m.style.color='#4ADE80'; m.textContent=rj.message||'Rattaché !';
    }catch(e){ m.style.color='#FF6B6B'; m.textContent=e.message; }
  };
</script></body></html>`));

// Page publique « Mon relevé » : l'artiste se connecte et voit / imprime son
// relevé mensuel (billets vendus + tips + net). Transparence de la
// redistribution, sans modif de l'app (donc sans review Apple).
app.get('/mon-releve', (req, res) => res.send(`<!doctype html><html lang="fr"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mon relevé — VybzzZ</title>
<style>
  *{box-sizing:border-box} body{margin:0;min-height:100vh;background:#0A1226;color:#F4EFE3;
   font-family:-apple-system,Helvetica,Arial,sans-serif;display:grid;place-items:start center;padding:20px}
  .card{width:100%;max-width:440px;background:#111B33;border:1px solid rgba(230,199,106,.25);border-radius:18px;padding:26px;margin-top:24px}
  h1{margin:0 0 4px;font-size:22px} h1 span{color:#E6C76A} p.sub{margin:0 0 18px;color:#C9C4B4;font-size:14px}
  input{width:100%;margin:0 0 12px;padding:13px 14px;border-radius:11px;border:1px solid rgba(230,199,106,.25);background:#0D1528;color:#F4EFE3;font-size:15px}
  button{width:100%;padding:14px;border:0;border-radius:11px;background:#E6C76A;color:#0A1226;font-weight:800;font-size:16px;cursor:pointer}
  .row{display:flex;justify-content:space-between;padding:12px 0;border-top:1px solid rgba(230,199,106,.15)}
  .row .lbl{color:#C9C4B4} .row .val{font-weight:700;font-variant-numeric:tabular-nums}
  .total{font-size:20px;color:#E6C76A} .muted{color:#8B94A8;font-size:12px}
  #msg{margin-top:10px;font-size:14px;text-align:center;min-height:18px}
  .hidden{display:none} .head{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:6px}
  .monthsel{width:auto;margin:0} .print{background:transparent;color:#E6C76A;border:1px solid #E6C76A;width:auto;padding:8px 14px;font-size:13px}
  @media print{.noprint{display:none} body{background:#fff;color:#000} .card{border:0}}
</style></head><body>
<div class="card" id="loginCard">
  <h1>Mon relevé <span>VybzzZ</span></h1>
  <p class="sub">Connecte-toi pour voir ton relevé mensuel (billets, tips, montant net).</p>
  <input id="email" type="email" placeholder="Email" autocomplete="username">
  <input id="pass" type="password" placeholder="Mot de passe" autocomplete="current-password">
  <button id="go">Voir mon relevé</button>
  <div id="msg"></div>
</div>
<div class="card hidden" id="stmtCard"></div>
<script>
  var TOKEN='';
  function eur(n){return (Math.round(n*100)/100).toFixed(2).replace('.',',')+' €';}
  async function load(month){
    var m=document.getElementById('msg'); m.textContent='';
    var url='/api/artist/statement'+(month?('?month='+month):'');
    var r=await fetch(url,{headers:{'Authorization':'Bearer '+TOKEN}});
    var j=await r.json(); if(!r.ok){m.style.color='#FF6B6B';m.textContent=(j&&j.message)||'Erreur';return;}
    var d=j.data||j;
    var c=document.getElementById('stmtCard');
    c.innerHTML=''
      +'<div class="head"><h1>Relevé <span>'+d.period+'</span></h1>'
      +'<button class="print noprint" onclick="window.print()">Imprimer</button></div>'
      +'<p class="sub">'+(d.artist||'')+'</p>'
      +'<div class="row"><span class="lbl">🎟️ Billets vendus</span><span class="val">'+d.tickets.count+'</span></div>'
      +'<div class="row"><span class="lbl">Montant net billets</span><span class="val">'+eur(d.tickets.net_eur)+'</span></div>'
      +'<div class="row"><span class="lbl">🎁 Tips reçus</span><span class="val">'+d.tips.count+' ('+d.tips.points+' pts)</span></div>'
      +'<div class="row"><span class="lbl">Montant net tips</span><span class="val">'+eur(d.tips.net_eur)+'</span></div>'
      +'<div class="row"><span class="lbl total">Total net à percevoir</span><span class="val total">'+eur(d.total_net_eur)+'</span></div>'
      +'<div class="head noprint" style="margin-top:16px"><span class="muted">Changer de mois</span>'
      +'<input class="monthsel" type="month" id="msel" value="'+d.month+'"></div>';
    var sel=document.getElementById('msel'); if(sel) sel.onchange=function(){load(sel.value);};
    document.getElementById('loginCard').classList.add('hidden');
    c.classList.remove('hidden');
  }
  document.getElementById('go').onclick=async function(){
    var m=document.getElementById('msg'); m.style.color='#C9C4B4'; m.textContent='Connexion…';
    try{
      var l=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({email:document.getElementById('email').value.trim(),password:document.getElementById('pass').value})});
      var lj=await l.json(); if(!l.ok||!lj.token) throw new Error(lj.message||'Connexion échouée');
      TOKEN=lj.token; await load('');
    }catch(e){ m.style.color='#FF6B6B'; m.textContent=e.message; }
  };
</script></body></html>`));

// Dashboard admin web (statique) sous /admin
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));

// Page apporteurs (statique, lecture seule) adossée à l'admin sous /partner
app.use('/partner', express.static(path.join(__dirname, '..', 'public', 'partner')));

// API admin sous /api/admin
app.use('/api/admin', adminRoutes);

// Vue d'ensemble publique (agrégats OPRAS) sous /api/vibe
app.use('/api/vibe', require('./routes/vibe.routes'));

// Toutes les routes API sous /api (comme baseAPI = mainIP/api)
app.use('/api', authRoutes);
app.use('/api', eventRoutes);
app.use('/api', miscRoutes);

// Webhook RevenueCat : pas de signature HMAC (juste un header Authorization
// fixe), donc pas besoin de corps brut -> monté normalement après express.json().
app.use('/api/revenuecat/webhook', revenuecatWebhookRoutes);

// Callback modération Sightengine (résultats vidéo/live asynchrones).
app.use('/api/moderation', moderationRoutes);

// 404 JSON propre
app.use((req, res) => res.status(404).json({ status: 'error', message: `Not found: ${req.method} ${req.path}` }));

// Erreurs
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  // Erreurs d'upload multer -> réponses propres (pas un 500 générique).
  if (err && (err.code === 'LIMIT_FILE_SIZE' || err.code === 'LIMIT_FILE_COUNT')) {
    return res.status(413).json({ status: 'error', message: 'Fichier trop volumineux.' });
  }
  if (err && err.message === 'UNSUPPORTED_FILE_TYPE') {
    return res.status(415).json({ status: 'error', message: 'Type de fichier non supporté.' });
  }
  // En prod, err.message peut contenir des détails internes (requête SQL,
  // chemin de fichier…) -> message générique côté client, détail dans les logs.
  const message = process.env.NODE_ENV === 'production' ? 'Internal server error.' : err.message;
  res.status(500).json({ status: 'error', message });
});

module.exports = app;

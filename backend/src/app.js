'use strict';

const express = require('express');
const cors = require('cors');
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
app.use(cors());

// Webhooks Mux/Stripe : montés AVANT express.json() car la vérification de
// signature a besoin du corps brut exact (Buffer), pas du JSON déjà parsé.
app.use('/api/mux/webhook', express.raw({ type: '*/*' }), muxWebhookRoutes);
app.use('/api/stripe/webhook', express.raw({ type: '*/*' }), stripeWebhookRoutes);

// L'app Flutter envoie soit du form-urlencoded (Map<String,String>),
// soit du JSON, soit du multipart (uploads). On gère les trois.
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const fs = require('fs');
const uploadsDir = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true }); // dossier temp multer (créé au démarrage)
const upload = multer({ dest: uploadsDir });
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

// Dashboard admin web (statique) sous /admin
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));

// API admin sous /api/admin
app.use('/api/admin', adminRoutes);

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
  // En prod, err.message peut contenir des détails internes (requête SQL,
  // chemin de fichier…) -> message générique côté client, détail dans les logs.
  const message = process.env.NODE_ENV === 'production' ? 'Internal server error.' : err.message;
  res.status(500).json({ status: 'error', message });
});

module.exports = app;

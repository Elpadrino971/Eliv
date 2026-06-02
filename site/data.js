/* ============================================================
   VYBZZZ — Données partagées (réalistes, alignées sur l'app)
   Devise : $ pour le fiat, ARENA POINTS (PTS) pour la monnaie interne.
   Branchable plus tard sur https://vybzzz.fryandeatfood.com/api
   ============================================================ */
window.VYBZZZ = (function () {
  const IMG = (n) => `assets/${n}`;

  // Catégories / genres (cf. /api/genres : Rock, Pop, Jazz…)
  const categories = [
    "Tous", "🔴 En direct", "Afrobeats", "Hip-Hop", "R&B / Soul",
    "Amapiano", "Électro", "House", "Pop", "Jazz", "Reggae", "Gospel",
  ];

  // Artistes vedettes (cf. /api/featured-artists)
  const artists = [
    { id: 1, name: "NOVA", genre: "Afrobeats", avatar: IMG("artist_image1.png"), followers: "1,2M", verified: true },
    { id: 2, name: "Layla Skye", genre: "R&B / Soul", avatar: IMG("artist_image2.png"), followers: "842K", verified: true },
    { id: 3, name: "Kairo", genre: "Hip-Hop", avatar: IMG("artist_image3.png"), followers: "2,1M", verified: true },
    { id: 4, name: "Mira Sound", genre: "Électro", avatar: IMG("artist_image4.png"), followers: "455K", verified: false },
    { id: 5, name: "DJ Volt", genre: "House", avatar: IMG("artist_image5.png"), followers: "990K", verified: true },
    { id: 6, name: "Selene", genre: "Pop", avatar: IMG("artist_image1.png"), followers: "1,5M", verified: true },
  ];

  // Feed = UNIQUEMENT de vraies vidéos Mux (pas de noms/données factices)
  const events = [
    { id: 1, video: "EcO013Q00m3BON019ydIrEUd3YaAES4J9nx02arl7U862P4", name: "Prince &amp; The Revolution — Purple Rain (Live)", live: true, price: 0 },
    { id: 2, video: "ZIAVh2AYyALPoxxrRW01wIqPDzX5eO1vYx1XSOSbj39o", name: "I Wasn't Expecting Her To Rap Like This", live: true, price: 0 },
    { id: 3, video: "sdsKbwNQ5UxSJhyUC9aBhM1m9kVQsJuKxGaBsMpI01VU", name: "KRYS — Live", live: true, price: 0 },
    { id: 4, video: "BC702qp42F2svVH2n4OU4nHDZz7YwMjSvx02r8gQkRA6g", name: "", live: true, price: 0 },
    { id: 5, video: "lnjLfyBrq4FcCpawY1pYXx5B5k02N004xz6CuAkymVRx8", name: "", live: true, price: 0 },
    { id: 6, video: "Vkj8t5Hpg302epwqxak7r4zMbO2kjBTDWRjGitlmTMPo", name: "", live: true, price: 0 },
  ];

  // Packs d'Arena Points (cf. /api/packages/list : title, points, price)
  const packages = [
    { id: 1, title: "Starter",  points: 100,   price: 0.99,  bonus: 0,   featured: false },
    { id: 2, title: "Groupie",  points: 550,   price: 4.99,  bonus: 10,  featured: false },
    { id: 3, title: "Fan",      points: 1200,  price: 9.99,  bonus: 15,  featured: false },
    { id: 4, title: "Super-fan", points: 2800, price: 19.99, bonus: 20,  featured: true  },
    { id: 5, title: "VIP",      points: 6000,  price: 39.99, bonus: 25,  featured: false },
    { id: 6, title: "Légende",  points: 16000, price: 99.99, bonus: 35,  featured: false },
  ];

  // Cadeaux virtuels (cf. /api/gifts : name, coins, price) — coût en Arena Points
  // anim = fichier vidéo dans assets/gifts/ (fond noir → rendu transparent via mix-blend screen)
  const gifts = [
    { name: "Rose",    emoji: "🌹", coins: 5,    anim: "rose.mp4" },
    { name: "Cœur",    emoji: "❤️", coins: 10,   anim: "coeur.mp4" },
    { name: "Étoile",  emoji: "🌟", coins: 50,   anim: "etoile.mp4" },
    { name: "Diamant", emoji: "💎", coins: 100,  anim: "diamant.mp4" },
    { name: "Feu",     emoji: "🔥", coins: 250,  anim: "feu.mp4" },
    { name: "Couronne", emoji: "👑", coins: 500, anim: "couronne.mp4" },
    { name: "Fusée",   emoji: "🚀", coins: 1000, anim: "fusee.mp4" },
    { name: "Château", emoji: "🏰", coins: 5000, anim: "chateau.mp4" },
  ];

  // Programme Founder = offre de lancement, prix par PALIERS selon l'ordre
  // d'inscription (200 places). À vie tant que l'abonnement reste actif, 60%.
  // taken = nombre d'artistes déjà inscrits.
  const founder = {
    taken: 0,
    total: 200,
    quorum: 24,                // nombre d'artistes signés pour DÉMARRER l'app
    commission: 60,            // % gardé par le créateur sur l'offre Founder
    upgradeCommission: 70,     // option 70%
    upgradePrice: 299,         // = plan Elite
    tiers: [
      { price: 79,  seats: 24,  label: "Vague 1 — les 24 premières" },
      { price: 99,  seats: 76,  label: "Vague 2 — les 76 suivantes" },
      { price: 149, seats: 100, label: "Vague 3 — les 100 dernières" },
    ],
  };

  // Plan Elite (option 70%, disponible pendant et après le lancement)
  const elite = {
    name: "Elite", price: 299, commission: 70, tag: "Option 70%",
    features: ["Tu gardes 70% de tes revenus", "Tout le Studio Pro", "Mise en avant premium", "Support prioritaire 24/7", "Analytics avancées"],
    cta: "Passer à 70%",
  };

  // Plans normaux : à partir de la 201ᵉ inscription, l'offre Founder disparaît
  const plansNormal = [
    { name: "Starter", price: 99,  commission: 50, highlight: false, features: ["Tu gardes 50% de tes revenus", "Studio Pro complet", "Billetterie & cadeaux virtuels", "Retraits Stripe / banque"], cta: "Choisir Starter" },
    { name: "Growth",  price: 199, commission: 60, highlight: true, tag: "Populaire", note: "Remplace l'offre Founder", features: ["Tu gardes 60% de tes revenus", "Tout le plan Starter", "Mise en avant prioritaire", "Retraits prioritaires"], cta: "Choisir Growth" },
    { name: "Elite",   price: 299, commission: 70, highlight: false, tag: "Premium", features: ["Tu gardes 70% de tes revenus", "Tout le plan Growth", "Mise en avant premium", "Support prioritaire 24/7", "Analytics avancées"], cta: "Choisir Elite" },
  ];

  // FAQ (cf. /api/settings/get-management — ici en dur, réaliste)
  const faq = [
    { q: "C'est quoi Vybzzz ?", a: "Vybzzz est une plateforme de concerts en direct : tu regardes tes artistes en live HD, tu envoies des cadeaux virtuels, tu achètes des tickets et tu revis les shows en replay. Les artistes diffusent depuis l'appli et sont rémunérés en temps réel." },
    { q: "Qu'est-ce que les Arena Points ?", a: "Les ARENA POINTS (PTS) sont la monnaie interne de Vybzzz. Tu les recharges via la boutique, puis tu les utilises pour envoyer des cadeaux pendant les lives. Plus le pack est gros, plus le bonus est élevé." },
    { q: "Comment envoyer un cadeau pendant un live ?", a: "Pendant un concert, ouvre le panneau cadeaux, choisis ton cadeau (Rose 5 PTS, Diamant 100 PTS, Château 5000 PTS…), confirme, et l'animation se déclenche en direct à l'écran. Le montant est reversé à l'artiste." },
    { q: "Comment acheter un ticket de concert ?", a: "Sur la page d'un événement payant, clique sur « Get Ticket », passe au paiement (carte, Apple Pay, Google Pay ou VyBzzZ Pay), et ton ticket apparaît dans « Mes tickets ». Le replay est inclus." },
    { q: "Quels moyens de paiement sont acceptés ?", a: "Carte bancaire, Apple Pay, Google Pay et VyBzzZ Pay. Tous les paiements sont chiffrés en SSL 256-bit. Les artistes peuvent connecter Stripe ou un compte bancaire pour leurs retraits." },
    { q: "Comment devenir artiste ?", a: "Va dans « Devenir artiste », remplis le formulaire (nom de scène, genre, expérience), télécharge et signe le contrat artiste, et notre équipe valide ton profil. Tu accèdes ensuite au Studio Pro." },
    { q: "Comment retirer mes gains (artistes) ?", a: "Depuis le Studio Pro → Revenus → « Withdraw ». Choisis ta méthode (Stripe ou compte bancaire), saisis le montant (paliers $100 / $500 / $1000 / Tout), et confirme. Délai moyen de versement : 24h." },
    { q: "Les lives sont-ils disponibles en replay ?", a: "Oui. Tout ticket acheté inclut le replay HD, disponible dans « Mes tickets ». Les abonnés VIP ont accès aux replays publics illimités." },
  ];

  const helpers = {
    money: (v) => v === 0 ? "Gratuit" : "$" + v.toFixed(2),
    pts: (v) => v.toLocaleString("fr-FR") + " PTS",
    nb: (v) => v >= 1000 ? (v / 1000).toFixed(v >= 10000 ? 0 : 1).replace(".", ",") + "K" : String(v),
  };

  return { categories, artists, events, packages, gifts, founder, elite, plansNormal, faq, helpers };
})();

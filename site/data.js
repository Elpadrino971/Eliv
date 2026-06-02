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

  // Événements / lives (cf. /lib/Models/event_model.dart : name, artist, genre, ticketPrice, coverImage, viewers, startDateTime)
  const events = [
    { id: 101, name: "Afro Night — Live depuis Lagos", artist: artists[0], genre: "Afrobeats", thumb: IMG("artist_image2.png"), live: true,  viewers: 8243,  price: 4.99,  likes: 12480, ago: "en direct" },
    { id: 102, name: "Midnight Soul Session",          artist: artists[1], genre: "R&B / Soul", thumb: IMG("artist_image3.png"), live: true,  viewers: 5712,  price: 0,     likes: 9320,  ago: "en direct" },
    { id: 103, name: "Cypher 16 — Freestyle Arena",    artist: artists[2], genre: "Hip-Hop",   thumb: IMG("artist_image4.png"), live: true,  viewers: 12044, price: 6.99,  likes: 23110, ago: "en direct" },
    { id: 104, name: "Warehouse Rave",                 artist: artists[4], genre: "House",      thumb: IMG("artist_image5.png"), live: true,  viewers: 9410,  price: 3.49,  likes: 15890, ago: "en direct" },
    { id: 105, name: "Synthwave Dreams",               artist: artists[3], genre: "Électro",    thumb: IMG("background5.png"),    live: false, viewers: 0,     price: 2.99,  likes: 4120,  scheduled: "Ce soir · 21:00" },
    { id: 106, name: "Acoustic Pop Unplugged",         artist: artists[5], genre: "Pop",        thumb: IMG("artist_image1.png"), live: false, viewers: 0,     price: 0,     likes: 6850,  scheduled: "Demain · 18:30" },
    { id: 107, name: "Amapiano Sunset",                artist: artists[0], genre: "Amapiano",   thumb: IMG("artist_image3.png"), live: false, viewers: 0,     price: 1.99,  likes: 5300,  scheduled: "Sam. · 20:00" },
    { id: 108, name: "Late Night Jazz Trio",           artist: artists[1], genre: "Jazz",       thumb: IMG("artist_image5.png"), live: false, viewers: 0,     price: 5.99,  likes: 2980,  scheduled: "Dim. · 19:00" },
    { id: 109, name: "Gospel Praise Live",             artist: artists[5], genre: "Gospel",     thumb: IMG("artist_image2.png"), live: false, viewers: 0,     price: 0,     likes: 7640,  scheduled: "Dim. · 11:00" },
    { id: 110, name: "Roots & Culture Reggae",         artist: artists[2], genre: "Reggae",     thumb: IMG("artist_image4.png"), live: false, viewers: 0,     price: 3.99,  likes: 4410,  scheduled: "Lun. · 22:00" },
    { id: 111, name: "Deep House Marathon",            artist: artists[4], genre: "House",      thumb: IMG("artist_image1.png"), live: true,  viewers: 3120,  price: 0,     likes: 3340,  ago: "en direct" },
    { id: 112, name: "R&B Slow Jams",                  artist: artists[1], genre: "R&B / Soul", thumb: IMG("background5.png"),    live: false, viewers: 0,     price: 2.49,  likes: 5120,  scheduled: "Mar. · 21:30" },
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
  const gifts = [
    { name: "Rose",    emoji: "🌹", coins: 5 },
    { name: "Cœur",    emoji: "❤️", coins: 10 },
    { name: "Étoile",  emoji: "🌟", coins: 50 },
    { name: "Diamant", emoji: "💎", coins: 100 },
    { name: "Feu",     emoji: "🔥", coins: 250 },
    { name: "Couronne", emoji: "👑", coins: 500 },
    { name: "Fusée",   emoji: "🚀", coins: 1000 },
    { name: "Château", emoji: "🏰", coins: 5000 },
  ];

  // Programme Founder (offre de lancement) — cf. spec produit
  // taken/total = jauge des places fondateur affichée sur l'accueil
  const founder = { taken: 0, total: 24, price: 79, commission: 60, deadline: "2026-06-16T20:00:00" };

  // Plans CRÉATEUR (l'artiste s'abonne et garde un % de ses revenus = "commission")
  const plansLaunch = [
    {
      name: "Founder", price: 79, commission: 60, highlight: true, tag: "Offre de lancement",
      note: "Limité aux 24 premiers créateurs fondateurs",
      features: ["Tu gardes 60% de tes revenus", "Prix bloqué à $79/mois tant que ton abonnement reste actif", "Studio Pro complet", "Mise en avant prioritaire au lancement", "Badge « Artiste Fondateur » à vie"],
      cta: "Devenir Fondateur",
    },
    {
      name: "Starter", price: 99, commission: 50, highlight: false,
      features: ["Tu gardes 50% de tes revenus", "Studio Pro complet", "Billetterie & cadeaux virtuels", "Retraits Stripe / banque"],
      cta: "Choisir Starter",
    },
    {
      name: "Elite", price: 299, commission: 70, highlight: false, tag: "Premium",
      features: ["Tu gardes 70% de tes revenus", "Tout le plan Starter", "Mise en avant premium", "Support prioritaire 24/7", "Analytics avancées"],
      cta: "Choisir Elite",
    },
  ];

  // Plans normaux (après que les 200 places Founder soient prises)
  const plansNormal = [
    {
      name: "Starter", price: 99, commission: 50, highlight: false,
      features: ["Tu gardes 50% de tes revenus", "Studio Pro complet", "Billetterie & cadeaux virtuels", "Retraits Stripe / banque"],
      cta: "Choisir Starter",
    },
    {
      name: "Growth", price: 199, commission: 60, highlight: true, tag: "Populaire",
      note: "Remplace l'offre Founder",
      features: ["Tu gardes 60% de tes revenus", "Tout le plan Starter", "Mise en avant prioritaire", "Retraits prioritaires"],
      cta: "Choisir Growth",
    },
    {
      name: "Elite", price: 299, commission: 70, highlight: false, tag: "Premium",
      features: ["Tu gardes 70% de tes revenus", "Tout le plan Growth", "Mise en avant premium", "Support prioritaire 24/7", "Analytics avancées"],
      cta: "Choisir Elite",
    },
  ];

  // En phase de lancement tant que les places Founder ne sont pas toutes prises
  const plans = founder.taken < founder.total ? plansLaunch : plansNormal;

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

  return { categories, artists, events, packages, gifts, plans, founder, faq, helpers };
})();

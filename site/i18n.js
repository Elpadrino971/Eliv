/* ============================================================
   VYBZZZ — Traductions (i18n)
   Clés partagées. window.I18N[lang][key].
   Langues : fr, en (puis es, it, de, pt, zh, ko, ja, ar, hi, ru).
   Les clés *_html contiennent du HTML volontaire (à conserver).
   ============================================================ */
window.I18N = window.I18N || {};

window.I18N.fr = {
  // Nav
  nav_home: "Accueil", nav_deal: "Le deal", nav_studio: "Studio Pro", nav_faq: "FAQ",
  nav_login: "Se connecter", nav_apply: "Postuler", lang_label: "Langue",
  // Hero
  hero_badge: "✦ Offre de lancement · le prix monte à chaque vague",
  hero_title_html: 'Sois créateur <span class="grad">Founder</span> avant que le prix monte.',
  hero_lead_html: 'Les <strong>24 premières places</strong> sont à <strong>$79/mois</strong>, les 76 suivantes à $99, les 100 dernières à $149. <strong>Tu gardes 60%</strong> de tes revenus, <strong>à vie</strong> tant que ton abonnement reste actif.',
  perk1_html: "Tu gardes <b>60%</b> de tes revenus, dès le 1ᵉʳ live",
  perk2_html: "Tarif <b>bloqué à vie</b> tant que ton abonnement reste actif",
  perk3_html: "<b>Studio Pro</b> complet : lives, billetterie, cadeaux",
  perk4_html: "Passe à <b>70%</b> quand tu veux (Elite $299)",
  cta_reserve: "Réserver ma place Founder", cta_studio: "Voir le Studio Pro",
  reassure: "🔒 Paiement sécurisé · Sans engagement · Annulable à tout moment",
  feed_sound: "Activer le son",
  // Avantages
  av_eyebrow: "Ce que tu obtiens", av_title_html: 'Le deal <span class="grad">Founder</span>.',
  av_p: "Des avantages réservés aux 200 créateurs fondateurs, pensés pour te faire gagner de l'argent et de la visibilité dès le lancement. Plus tu t'inscris tôt, moins tu paies — à vie.",
  // Tarifs
  pricing_eyebrow: "Tarifs créateur", pricing_title_html: 'Choisis ton <span class="grad">plan</span>.',
  pricing_p: "Pendant le lancement, le tarif Founder monte par paliers selon l'ordre d'inscription ($79 → $99 → $149, toujours 60% gardés). Dès la 201ᵉ inscription, on passe aux plans normaux (Starter $99 · Growth $199 · Elite $299).",
  // Studio / étapes
  studio_title: "Ton tableau de bord créateur",
  studio_p: "Revenus en temps réel, ventes de tickets, cadeaux reçus, retraits Stripe. Le même outil que tu utiliseras au quotidien.",
  studio_cta: "Explorer le Studio Pro →",
  steps_title: "Rejoindre les fondateurs",
  step1_t: "Candidate", step1_p: "Remplis le formulaire créateur (2 min) : nom de scène, genre, expérience.",
  step2_t: "Signe le contrat", step2_p: "Télécharge le contrat Founder en PDF, signe-le et accepte les conditions.",
  step3_t: "Passe en live", step3_p: "On valide ton profil, on configure ton studio, et tu crées ton premier événement.",
  // Parrainage / idées
  ref_title: "Parraine tes artistes",
  ref_p_html: "Tu connais l'artiste parfait pour Vybzzz ? <strong>Amène-le</strong> et gagne <strong>−10% sur ton abonnement par artiste</strong> qui rejoint — jusqu'à <strong>10 artistes = abonnement gratuit à vie</strong>.",
  ref_invite: "Inviter", ref_ph: "@pseudo ou nom de l'artiste à inviter",
  idea_title: "Boîte à idées",
  idea_p: "Une fonctionnalité qui te manque ? Dis-nous tout — les fondateurs façonnent Vybzzz.",
  idea_ph: "Ton idée pour améliorer Vybzzz…", idea_send: "Envoyer mon idée",
  // CTA final
  cta_title_html: 'Plus que <span class="grad" id="ctaLeft">—</span> places au tarif actuel.',
  cta_p: "Le prix monte à chaque vague ($79 → $99 → $149), puis l'offre Founder ferme à la 201ᵉ inscription. Bloque ton tarif maintenant — à vie.",
  cta_btn: "Réserver ma place Founder",
  // Footer
  foot_tagline: "La scène live qui ne dort jamais.",
  foot_discover: "Découvrir", foot_artists: "Artistes", foot_help: "Aide",
  foot_rights: "© 2026 Vybzzz. Tous droits réservés.",
  foot_secure: "Paiements sécurisés · VyBzzZ Pay · SSL 256-bit",
};

window.I18N.en = {
  nav_home: "Home", nav_deal: "The deal", nav_studio: "Pro Studio", nav_faq: "FAQ",
  nav_login: "Log in", nav_apply: "Apply", lang_label: "Language",
  hero_badge: "✦ Launch offer · the price rises with every wave",
  hero_title_html: 'Become a <span class="grad">Founder</span> creator before the price goes up.',
  hero_lead_html: 'The <strong>first 24 spots</strong> are <strong>$79/mo</strong>, the next 76 at $99, the last 100 at $149. <strong>You keep 60%</strong> of your revenue, <strong>for life</strong> as long as your subscription stays active.',
  perk1_html: "You keep <b>60%</b> of your revenue, from your very first live",
  perk2_html: "Price <b>locked for life</b> as long as your subscription stays active",
  perk3_html: "Full <b>Pro Studio</b>: lives, ticketing, gifts",
  perk4_html: "Upgrade to <b>70%</b> anytime (Elite $299)",
  cta_reserve: "Reserve my Founder spot", cta_studio: "See the Pro Studio",
  reassure: "🔒 Secure payment · No commitment · Cancel anytime",
  feed_sound: "Turn on sound",
  av_eyebrow: "What you get", av_title_html: 'The <span class="grad">Founder</span> deal.',
  av_p: "Perks reserved for the 200 founding creators, built to help you earn money and visibility from day one. The earlier you join, the less you pay — for life.",
  pricing_eyebrow: "Creator pricing", pricing_title_html: 'Choose your <span class="grad">plan</span>.',
  pricing_p: "During launch, the Founder price rises in waves based on signup order ($79 → $99 → $149, always keeping 60%). From the 201st signup, normal plans apply (Starter $99 · Growth $199 · Elite $299).",
  studio_title: "Your creator dashboard",
  studio_p: "Real-time revenue, ticket sales, gifts received, Stripe payouts. The exact tool you'll use every day.",
  studio_cta: "Explore the Pro Studio →",
  steps_title: "Join the founders",
  step1_t: "Apply", step1_p: "Fill in the creator form (2 min): stage name, genre, experience.",
  step2_t: "Sign the contract", step2_p: "Download the Founder contract as a PDF, sign it and accept the terms.",
  step3_t: "Go live", step3_p: "We approve your profile, set up your studio, and you create your first event.",
  ref_title: "Refer your artists",
  ref_p_html: "Know the perfect artist for Vybzzz? <strong>Bring them in</strong> and earn <strong>−10% off your subscription per artist</strong> who joins — up to <strong>10 artists = free subscription for life</strong>.",
  ref_invite: "Invite", ref_ph: "@handle or name of the artist to invite",
  idea_title: "Idea box",
  idea_p: "Missing a feature? Tell us everything — founders shape Vybzzz.",
  idea_ph: "Your idea to improve Vybzzz…", idea_send: "Send my idea",
  cta_title_html: 'Only <span class="grad" id="ctaLeft">—</span> spots left at the current price.',
  cta_p: "The price rises with every wave ($79 → $99 → $149), then the Founder offer closes at the 201st signup. Lock in your price now — for life.",
  cta_btn: "Reserve my Founder spot",
  foot_tagline: "The live stage that never sleeps.",
  foot_discover: "Discover", foot_artists: "Artists", foot_help: "Help",
  foot_rights: "© 2026 Vybzzz. All rights reserved.",
  foot_secure: "Secure payments · VyBzzZ Pay · SSL 256-bit",
};

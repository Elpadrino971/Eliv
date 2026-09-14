'use strict';
/**
 * Textes légaux par défaut affichés dans l'app (Profil → À propos / Réglages),
 * lus via GET /api/settings/get-settings (clés privacy_policy,
 * terms_and_conditions, about_us, support_email). Seedés au démarrage
 * UNIQUEMENT si la clé est vide ; modifiables ensuite depuis l'admin
 * (Support & contenu → Textes légaux). Les versions complètes sont sur le site :
 * https://vybzzz.online/confidentialite.html et https://vybzzz.online/cgu.html
 */

const SITE = 'https://vybzzz.online';

const privacy_policy = `POLITIQUE DE CONFIDENTIALITÉ — VybzzZ
Version complète : ${SITE}/confidentialite.html

Ce que nous collectons
• Compte : e-mail, nom ou nom de scène, mot de passe chiffré, photo, bio, genres musicaux.
• Connexion Google ou Apple : e-mail et nom transmis par le fournisseur via un jeton vérifié. Aucun mot de passe tiers.
• Usage : lives regardés, clips aimés, cadeaux envoyés, billets, messages de chat, questions, signalements.
• Achats : identifiants de transaction App Store / Google Play / RevenueCat. Nous ne voyons jamais votre numéro de carte.
• Artistes : candidature, signature du contrat, coordonnées de versement (Stripe ou IBAN), revenus et retraits.
• Techniques : adresse IP et pays approximatif, appareil, version de l'app, jeton de notification.
• Caméra et micro : uniquement pendant un live ou une prise de parole, après votre autorisation.

Pourquoi
Fournir le service, rémunérer les artistes, prévenir la fraude, modérer, envoyer des notifications (désactivables), produire des statistiques agrégées, répondre à vos demandes.

Avec qui
Hostinger (hébergement), Mux (vidéo), ZEGOCLOUD (direct), Firebase / Google et Apple (connexion, notifications, achats), Google Play, RevenueCat (achats intégrés), Stripe (versements). Certains sont hors UE ; les transferts sont encadrés par les clauses contractuelles types. Nous ne vendons jamais vos données.

Combien de temps
Compte : durée du compte + 30 jours. Transactions : 10 ans (obligation comptable). Chats et questions de live : 12 mois. Journaux techniques : 12 mois.

Vos droits
Accès, rectification, effacement, opposition, portabilité, limitation. Suppression du compte directement dans l'app (Réglages → Supprimer mon compte). Contact : hello@vybzzz.online. Recours possible auprès de la CNIL (cnil.fr).

Mineurs
VybzzZ est réservé aux 16 ans et plus ; entre 16 et 18 ans, accord d'un parent requis pour les achats.

Dernière mise à jour : 14 septembre 2026.`;

const terms_and_conditions = `CONDITIONS GÉNÉRALES D'UTILISATION — VybzzZ
Version complète : ${SITE}/cgu.html

1. Le service
VybzzZ est une plateforme de concerts en direct. Les artistes diffusent des lives et publient des clips. Les fans regardent, achètent des billets, envoient des cadeaux et pourboires avec des Arena Points, et revoient les concerts en replay.

2. Compte
16 ans révolus, informations exactes, un seul compte par personne, mot de passe confidentiel. Suppression possible à tout moment dans l'app.

3. Arena Points, billets, cadeaux
Les Arena Points sont achetés via l'App Store ou Google Play. Ils n'ont pas de valeur hors de VybzzZ, ne sont ni transférables ni remboursables sauf obligation légale. Un billet donne accès au live indiqué et à son replay ; si un live payant n'a pas lieu, le billet est recrédité ou remboursé selon les règles du store. Un cadeau ou un pourboire est un soutien volontaire, définitif une fois envoyé.

4. Artistes
Entrée gratuite, après examen de la candidature et signature du contrat artiste. Sur chaque montant payé par un fan, après les frais des stores (environ 15 %), l'artiste perçoit 50 % du montant payé. 90 minutes de diffusion par mois sont incluses ; au-delà, les minutes sont financées par les revenus du live. Retraits via Stripe ou virement, délai moyen 24 h après validation. L'artiste garantit détenir les droits sur ce qu'il diffuse et autorise VybzzZ à diffuser, enregistrer et proposer en replay ses lives et clips, et à en utiliser des extraits pour la promotion de la plateforme.

5. Règles de conduite
Interdits : contenus illégaux, haineux, violents, sexuellement explicites, diffusion d'œuvres sans droits, harcèlement, usurpation d'identité, fraude. VybzzZ peut retirer un contenu, couper un live, suspendre ou fermer un compte.

6. Signalement et blocage
Chaque utilisateur peut signaler un contenu ou un comportement et bloquer un autre utilisateur depuis l'app. Les contenus manifestement illicites sont retirés sans délai.

7. Disponibilité et responsabilité
Service fourni sans garantie d'absence d'interruption. Les artistes sont responsables de leurs contenus. La responsabilité de VybzzZ est limitée aux sommes perçues pour le service concerné, sauf faute lourde ou disposition légale impérative.

8. Droit applicable
Droit français. Solution amiable en priorité via hello@vybzzz.online.

Dernière mise à jour : 14 septembre 2026.`;

const about_us = `VybzzZ — Un monde de concerts en direct.

Les artistes montent sur scène depuis leur téléphone, où qu'ils soient. Les fans achètent leur place, envoient des cadeaux et vibrent en temps réel. L'entrée est gratuite pour les artistes, qui gardent 50 % de leurs revenus.

Site : ${SITE}
Contact : hello@vybzzz.online`;

const support_email = 'hello@vybzzz.online';

module.exports = { privacy_policy, terms_and_conditions, about_us, support_email };

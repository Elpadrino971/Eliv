# VybzzZ — brief pour Atelier

> Fiche de marque destinée aux agents d'Atelier (Analyste → Stratège → Directeur
> artistique → Rédacteur) **et** à l'adaptateur `publishers/vybzzz.py`. Elle dit
> ce qu'est VybzzZ, à qui il parle, ce qui marche, et comment publier dessus —
> pour que le programme éditorial serve réellement le business.

---

## 1. En une phrase

**VybzzZ, c'est la scène live dans ta poche** : une plateforme de concerts en
direct où l'artiste garde **50 %** de ses revenus, et où les fans achètent leur
place, envoient des cadeaux et vibrent en temps réel — sans salle, sans
frontière, sans intermédiaire.

Signature de marque : **« La scène est à toi. Monte maintenant. »**

## 2. Le modèle (à marmarteler, c'est le différenciateur)

- **Gratuit à l'entrée** pour l'artiste : aucun abonnement, aucune avance.
- **L'artiste garde 50 %** de chaque montant payé par un fan (après ~15 % de
  frais store). Un ticket à 10 € → 5 € pour l'artiste.
- **Payé en direct** : billets, cadeaux, pourboires crédités le soir même,
  retrait Stripe/banque en ~24 h.
- **90 min de live incluses / mois**, lives mondiaux illimités.
- Trois façons d'exister : **Le Live** (concert mondial), **Le Feed & Clips**
  (découverte entre deux lives), **Le Studio Pro** (régie complète).

## 3. Le public

- **Deux cibles** : les **artistes** (à recruter) et les **fans** (à faire venir
  aux lives).
- **Géographie réelle** : forte présence **France métropolitaine + DOM**
  (Guadeloupe, Martinique, Guyane, La Réunion) et **diaspora afro-caribéenne**.
  Toute campagne doit parler à cet ancrage (créole/île, diaspora, fierté locale)
  autant qu'au marché hexagonal.
- **Genres phares** : Afrobeats, Amapiano, Hip-Hop, R&B/Soul, Dancehall/Reggae,
  Gospel, Pop urbaine.
- **Ton du public** : jeune, mobile-first, communautaire, sensible à l'authentique
  et au « vrai live » (pas au clip sur-produit et froid).

## 4. Identité de marque (à respecter par le DA)

- **Palette** : nuit bleu profond (`#070C18`), ivoire (`#F4EFE3`), **or**
  (`#E6C76A`) en accent. Ambiance **cinématique, premium mais chaleureuse**.
- **Typo** : serif éditorial (Playfair Display) pour les titres, sans (Inter)
  pour le texte. Grandes accroches, italique or sur les mots forts.
- **Nom** : toujours écrit **VybzzZ** (V majuscule, dernier Z majuscule). Jamais
  « Vibe », jamais « VYBZZZ » tout en capitales dans le corps de texte.
- **Registre** : tutoiement, direct, motivant, français. « Monte sur scène »,
  « tu gardes 50 % », « en direct, où que tu sois ».

## 5. Ce qui marche comme contenu

**Format vidéo : 16:9 horizontal.** Les artistes VybzzZ filment en **paysage**
(sessions live, acoustiques, concerts) — **pas de vertical/format story** comme
contenu principal. Les vignettes du feed sont en 16:9.

Angles à exploiter (par ordre de force) :

1. **« L'artiste garde 50 % »** — le crochet business le plus fort. Comparaison
   franche avec les plateformes qui prennent tout.
2. **« Payé le soir même »** — la preuve concrète (billets/cadeaux en direct).
3. **« Un concert mondial depuis ta chambre »** — le live sans salle ni frontière.
4. **Fierté locale / diaspora** — mettre en avant les artistes DOM & afro.
5. **Extraits de live / sessions acoustiques** — l'énergie brute qui « passe
   l'écran », pas le clip léché.
6. **Onboarding artiste** — « postule, monte sur scène cette semaine ».

À éviter : promesses de gains irréalistes, ton corporate froid, format vertical
imposé, tout ce qui ressemble à de la pub agressive.

## 6. Objectifs business (ce que la campagne doit servir)

| Priorité | Objectif | Métrique qui compte |
|---|---|---|
| 1 | **Recruter des artistes** | candidatures (page « Postuler ») |
| 2 | **Faire venir des fans** | téléchargements / inscriptions |
| 3 | **Remplir les lives** | billets vendus, cadeaux envoyés |
| 4 | **Fidéliser** | retours sur les prochains concerts |

L'analyste d'Atelier doit boucler sur ces résultats : un mois qui génère des
candidatures artistes et des vues de clips a mieux marché qu'un mois « joli ».

## 7. Publier SUR VybzzZ (canal de diffusion)

VybzzZ n'est pas qu'un client : c'est **aussi une destination de publication**.
Un contenu publié sur VybzzZ apparaît dans le **feed de l'app** (onglet
« Pour toi » ou « Clips »). L'adaptateur `publishers/vybzzz.py` parle à l'API
`/api/v1` (voir `docs/API_PUBLICATION.md`). Résumé du contrat :

- **authenticate** : clé API `X-API-Key` (générée dans l'admin VybzzZ →
  « API / Atelier »).
- **publish** : `POST /api/v1/publish` avec `video_url` (URL publique, VybzzZ
  ingère dans Mux) **ou** `mux_playback_id`. Champs : `title`, `feed`
  (`for_you` | `clips`), `artist_id?`, `external_ref?` (idempotence).
- **status** : `GET /api/v1/publications/:id` → `state` (`processing`/`ready`),
  `mux_playback_id`, `hls_url`.
- **stats** : `GET /api/v1/publications/:id/stats` → `views`, `likes` (alimente
  la boucle d'analyse d'Atelier / M7).

Recommandations de diffusion :

- Vidéo **16:9**, courte (15–45 s pour un clip de feed).
- Titre accrocheur en français, ton VybzzZ.
- Utiliser `external_ref` = l'id de la pièce côté Atelier (rejouable sans doublon).
- Renseigner `artist_id` quand le contenu concerne un artiste précis (il apparaît
  alors sur sa fiche).

## 8. Garde-fous (conformité — non négociable)

- **Droit à l'image** : ne publier que du contenu dont les droits sont acquis
  (artiste consentant, pas de tiers non consentant). VybzzZ modère les clips.
- **Musique** : droits musicaux à jour (pas d'œuvre tierce non autorisée).
- **Pas de format vertical** imposé comme contenu principal ; VybzzZ est paysage.
- **Casse de marque** : « VybzzZ » exactement.
- Respecter le **ton** : motivant, jamais mensonger sur les gains.

## 9. Punchlines prêtes à l'emploi (banque du rédacteur)

- « La scène est à toi. Monte maintenant. »
- « Ton concert. Ton public. **Ta** part : 50 %. »
- « Payé le soir même du live. »
- « Un monde de concerts en direct — sans salle, sans frontière, sans
  intermédiaire. »
- « Accès privé. Scène ouverte. »
- « Le prochain grand concert commence maintenant, dans ta poche. »

---

*Ce document est un point de départ vivant : à enrichir avec les statistiques
réelles remontées par l'API de publication (§7) au fil des campagnes.*

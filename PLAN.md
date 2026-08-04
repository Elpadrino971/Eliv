# Plan d'action Vybzzz — de l'urgence sécurité au déploiement

Cibles de déploiement réelles : **Android (Play Store)** + **iOS (App Store)**.
État de départ : 1 commit, 0 test réel, secrets commités, build release signé en debug, pas de CI.

Légende effort : S = < 0.5j · M = ~1j · L = 2-3j

---

## PHASE 0 — Sécurité critique / confinement (IMMÉDIAT, avant tout le reste)
> Objectif : stopper la fuite. Rien d'autre ne démarre tant que ce n'est pas fait.

| # | Action | Fichier | Effort |
|---|--------|---------|--------|
| 0.1 | **Révoquer la clé privée Firebase Admin** dans Google Cloud Console (IAM > service accounts > supprimer/régénérer la clé `bf1200fc5027…`) | console | S |
| 0.2 | **Régénérer l'AppSign ZegoCloud** depuis le dashboard Zego | console | S |
| 0.3 | **Régénérer la clé API RevenueCat** | console | S |
| 0.4 | Supprimer `lib/services/vybzzz_bf1200fc5027.dart` du code **et de l'historique Git** (`git filter-repo`) | repo | M |
| 0.5 | Déplacer l'envoi de notifications FCM **côté backend** (endpoint serveur) ; le client ne fait plus que recevoir | backend + `push_notification.dart` | M |
| 0.6 | Retirer le log du token (`push_notification.dart:80`) | services | S |

**Critère de sortie :** aucun secret Admin/serveur dans le binaire ni l'historique ; notifications envoyées par le serveur.

---

## PHASE 1 — Gestion des secrets & stockage sécurisé (P0-P1)
> Dépend de Phase 0.

| # | Action | Effort |
|---|--------|--------|
| 1.1 | Introduire `--dart-define` / `--dart-define-from-file` pour les clés client (Zego appId, RevenueCat, OAuth) ; fichier `env/*.json` **gitignoré** | M |
| 1.2 | Mettre à jour `.gitignore` (env, keystores, `*.jks`, `*.p8`, service accounts) | S |
| 1.3 | Remplacer `GetStorage` par **`flutter_secure_storage`** pour token & données sensibles | M |
| 1.4 | Retirer le champ `password` de `UserModel` (`user_model.dart:54`) | S |
| 1.5 | Sécuriser l'accès Zego via **token serveur** (ZegoUIKitToken) au lieu de l'appSign en dur | M |

**Critère de sortie :** secrets injectés au build, token chiffré sur l'appareil.

---

## PHASE 2 — Robustesse réseau & refactor API (P1)
> Élimine la fragilité « split('error ') » et la duplication.

| # | Action | Effort |
|---|--------|--------|
| 2.1 | Créer un **`ApiProvider` centralisé** (timeout, parse JSON sûr, type de retour `Result<T>` au lieu de string `"error …"`) | L |
| 2.2 | Gestion **401 / token expiré** → refresh ou redirection login | M |
| 2.3 | **Retry + backoff exponentiel** sur erreurs réseau | S |
| 2.4 | Migrer les contrôleurs (`auth`, `event`, `artist`, `subscription`, `support`) vers l'`ApiProvider` | L |
| 2.5 | Remplacer `parseError` (`global.dart`) par un parsing JSON défensif | S |
| 2.6 | **Certificate pinning** sur le client HTTP | M |

**Critère de sortie :** un seul chemin API, aucune erreur basée sur du parsing de chaîne, aucune requête sans timeout.

---

## PHASE 3 — Qualité, validations & tests (P1-P2)

| # | Action | Effort |
|---|--------|--------|
| 3.1 | `fromJson` défensifs (types, `DateTime.tryParse`, valeurs par défaut) sur tous les Models | M |
| 3.2 | Rate limiting / sanitization des messages & cadeaux ZegoCloud ; validation du parsing `split(':')` | M |
| 3.3 | Corriger les memory leaks (dispose des `Timer` / `VideoPlayerController`) | M |
| 3.4 | Remplacer `test/widget_test.dart` (template compteur) par de **vrais tests** : controllers (mock API), parsing models, golden des écrans clés | L |
| 3.5 | Renommer les fichiers mal orthographiés (`create_acount`, `spalash_screen`, `susbcription_model`, `disscover_screen`, `create_passwrod`, `artist_histroy_screen`) | S |
| 3.6 | `flutter analyze` propre + logging structuré à la place de `myPrint` | M |

**Critère de sortie :** `flutter analyze` sans warning, tests verts, 0 leak détecté.

---

## PHASE 4 — Préparation build release (P1, bloquant déploiement)

| # | Action | Effort |
|---|--------|--------|
| 4.1 | **Android : vraie signature release** — keystore, `key.properties` gitignoré, remplacer `signingConfigs.debug` (`android/app/build.gradle.kts:41`) | M |
| 4.2 | **iOS** : Bundle ID, certificats/provisioning, capacités (Push, IAP) | M |
| 4.3 | App ID applicationId / nom / icônes / splash propres (le projet s'appelle encore `artist`) | S |
| 4.4 | Stratégie de **version** (`version: 1.0.0+1` → bump + build number auto) | S |
| 4.5 | Activer ProGuard/R8 (Android) + obfuscation `--obfuscate --split-debug-info` | S |
| 4.6 | Vérifier permissions manifest (Android/iOS) — caméra, micro, notifications | S |

**Critère de sortie :** `flutter build appbundle --release` et `flutter build ipa --release` signés correctement.

---

## PHASE 5 — CI/CD (P2)

| # | Action | Effort |
|---|--------|--------|
| 5.1 | Workflow GitHub Actions **CI** : `flutter analyze` + `flutter test` sur chaque PR | M |
| 5.2 | Secrets de build dans **GitHub Secrets** (keystore base64, `.p8`, dart-define) | S |
| 5.3 | Job **build release** Android (.aab) + iOS (.ipa) sur tag | M |
| 5.4 | (option) Déploiement auto Play Console (internal track) + TestFlight via Fastlane | L |

**Critère de sortie :** PR vert obligatoire, artefacts release produits automatiquement.

---

## PHASE 6 — Déploiement & post-lancement (P2)

| # | Action | Effort |
|---|--------|--------|
| 6.1 | **Beta** : Play Store internal testing + TestFlight | M |
| 6.2 | Fiches stores (descriptions, captures, politique de confidentialité — requise vu IAP & données) | M |
| 6.3 | Conformité : Data Safety (Play) / App Privacy (Apple), déclaration IAP RevenueCat | M |
| 6.4 | Crash reporting + analytics (Firebase Crashlytics) | S |
| 6.5 | Soumission production → review → release progressif (staged rollout) | M |
| 6.6 | Monitoring post-release (Crashlytics, taux d'erreur API, alerting) | S |

**Critère de sortie :** app publiée, rollout surveillé, crash-free > seuil défini.

---

## PHASE 7 — CRM interne & agent IA prospection/contrats (post-lancement)
> Usage interne VybzzZ (pas un produit à revendre) : gérer les prospects business
> (artistes, salles, sponsors, partenaires), jusqu'à la signature de contrat.
> Décisions déjà actées : e-signature = **Dropbox Sign (HelloSign)** ; l'IA
> **rédige** messages de prospection et contrats mais **n'envoie jamais toute
> seule** (validation humaine à chaque étape) ; vit dans l'admin panel existant
> (`backend/public/admin/`), même backend/VPS — pas de nouvelle app séparée.

| # | Action | Fichier | Effort |
|---|--------|---------|--------|
| 7.1 | Schéma DB : `crm_contacts` (type artiste/salle/sponsor/partenaire, stage du pipeline, coordonnées, notes), `crm_activities` (historique/notes horodatées), `crm_contracts` (contenu, statut, lien Dropbox Sign) | `backend/src/db.js` | M |
| 7.2 | Routes CRUD contacts + pipeline (`GET/POST/PUT /admin/crm/contacts`, changement de stage) | `backend/src/routes/crm.routes.js` | M |
| 7.3 | Endpoint IA "rédiger message de prospection" — réutilise `services/anthropic.js` déjà en place (déjà utilisé pour bios/descriptions), aucune nouvelle clé API nécessaire | `backend/src/routes/crm.routes.js` | S |
| 7.4 | Endpoint IA "rédiger contrat" à partir d'un template + paramètres du deal (type, montant, durée) | `backend/src/routes/crm.routes.js` | M |
| 7.5 | Intégration **Dropbox Sign** (créer une demande de signature depuis le texte généré, suivi statut envoyé/vu/signé) — **nécessite une clé API Dropbox Sign à obtenir et ajouter au `.env` du VPS** | `backend/src/services/dropbox_sign.js` | M |
| 7.6 | Webhook Dropbox Sign (mise à jour statut contrat à la signature) | `backend/src/routes/webhooks.routes.js` | S |
| 7.7 | UI admin : nouvelle section "CRM" — liste/pipeline des contacts, fiche contact (notes, boutons "Générer message" / "Générer contrat" / "Envoyer pour signature") | `backend/public/admin/index.html` + `app.js` | L |

**Critère de sortie :** un prospect peut être ajouté, un message/contrat généré par l'IA et édité, envoyé en signature électronique, et son statut suivi jusqu'à signature — le tout sans quitter l'admin panel.
**Bloquant à lever avant 7.5/7.6 :** obtenir la clé API Dropbox Sign (compte + clé sur dashboard.hellosign.com).

---

## PHASE 8 — V3 : croissance & monétisation avancée
> Capturé tel quel, pas encore cadré en détail — à préciser (maquettes, règles
> de scoring, périmètre exact) avant de commencer chaque chantier.

| # | Action | Notes | Effort |
|---|--------|-------|--------|
| 8.1 | **Widget iOS** (écran d'accueil) + miniatures adaptées par taille de widget (small/medium/large) | Nécessite une **Widget Extension** native (WidgetKit/Swift, pas du Flutter) + un **App Group** pour partager les données concert/artiste entre l'app et le widget | L |
| 8.2 | **Abonnement sur-mesure** pour artiste "bancable" (deal négocié individuellement, hors grille Starter/Growth/Elite/Founder) | À brancher sur le futur CRM (Phase 7) : le contrat signé définit les termes, l'admin crée l'abonnement custom correspondant | M |
| 8.3 | **Classement des artistes** — par attraction/traction, par étoiles (`reviews` déjà en base), par notoriété, avec **bonus** (commission boostée ou cash) pour ceux qui ramènent le plus de flux | Formule de score à définir (mix ventes billets + cadeaux + spectateurs live + follows) ; bonus à brancher sur le split de commission déjà en place (P1, `platform_earnings`) | L |
| 8.4 | **Boutique merch** (produits physiques/digitaux vendus par les artistes) | Nouveau domaine : catalogue produits, stock, expédition/fulfillment, paiement Stripe séparé des billets/abonnements | L |

**Critère de sortie :** chaque sous-chantier cadré individuellement (specs + maquettes) avant tout code — trop flou en l'état pour estimer plus finement.

---

## PHASE 9 — Programme Pionnier (statut fondateur, invité — pas un produit vendu)
> Distinct de la grille Founder (payante, 200 places, auto-tiering par prix
> croissant). Le Pionnier ne s'achète pas, il se reçoit : invitation
> nominative, gratuite, à 5 artistes choisis pour couvrir 5 territoires —
> plus 5 remplaçants en réserve. **Palier créé côté admin** (`Pionnier`,
> tier `pionnier`, 0€, commission 70%, **inactif/invisible dans l'app** —
> attribution uniquement via Admin → Abonnements attribués).

### La structure à trois étages
| Étage | Qui | Condition | Commission | Prix |
|---|---|---|---|---|
| 1. Grille standard | Ouverte à tous (plus tard) | Achat libre | 50/60/70% | 99€/199€/299€ mois |
| 2. Founder (200 places) | Payant, paliers croissants | Places limitées, prix monte par palier | 60% à vie | 79€/mois (vs 199€ normal) |
| 3. **Pionnier (5 + 5 réserve)** | **Invité, nominatif** | Engagement (voir plus bas) | **70% à vie** | **Offert** |

Les deux systèmes (Founder / Pionnier) sont étanches : un Pionnier ne consomme aucune des 200 places Founder.

### Les 5 noms (+ Kassav' en Parrain honorifique, sans obligation de live)
| N° | Artiste | Territoire / raison |
|---|---|---|
| 01 | Admiral T | Légitimité Guadeloupe |
| 02 | Kalash | Audience hexagonale |
| 03 | Fanny J | Audience féminine, Guyane |
| 04 | Lil Cool | Guyane |
| 05 | Buchi | Moteur opérationnel (1M vues/vidéo) |
| — | Kassav' | Parrain honorifique, pas d'obligation de live |

Le **numéro s'attribue par notoriété, pas par ordre de signature** : Admiral T reste n°01 même s'il signe en 4ᵉ. Pas de champ en base pour ça pour l'instant — à suivre à la main (tableur/notes) tant que ce n'est pas trackée en base (voir 9.3).

### L'équilibre donnant-donnant (contrat, pas un cadeau)
En face des 5 avantages (70% à vie, invitation nominative, statut, etc.), **3 engagements** :
1. Un live par mois pendant 6 mois
2. Une annonce publique de leur arrivée
3. Deux artistes qu'ils présentent eux-mêmes (parrainage)

Statut maintenu tant que l'engagement est tenu — sinon, **rétrogradation réelle** au tarif Founder. Point de vigilance explicite : si la clause n'est jamais appliquée en pratique, elle devient décorative et les 200 Founder (qui payent, eux) s'en rendront compte.

### Mécanique d'entraînement
Chaque Pionnier amène 2 artistes = 10 arrivées issues du cercle (recommandation, pas prospection), qui rejoignent la grille Founder payante. Les Pionniers financent donc indirectement une partie des 200 places : 5 Pionniers ouvrent la voie, 200 Founder créent le chiffre d'affaires.

### Ordre d'approche recommandé
**Buchi d'abord** (le plus accessible) → **Lil Cool** → **Admiral T** (avec 2 noms déjà signés en poche) → **Fanny J** et **Kalash** en dernier. Ne jamais approcher le plus gros nom en premier avec une liste vide.

| # | Action | Effort |
|---|--------|--------|
| 9.1 | ~~Créer le palier "Pionnier" en base (0€, 70%, inactif)~~ | ✅ Fait (admin panel) |
| 9.2 | Attribuer le palier à chaque artiste au fur et à mesure de leur signature (Admin → Abonnements attribués) | S (par artiste, manuel) |
| 9.3 | (optionnel) Champ `pioneer_number` + suivi des 3 engagements (live du mois, annonce faite, parrainages) directement en base plutôt qu'à la main | M |
| 9.4 | Process de rétrogradation si engagement non tenu (repasse en Founder au tarif normal) | S |

**Critère de sortie :** 5 Pionniers signés et actifs, engagements suivis, aucune confusion avec la grille Founder payante.

---

## Ordre d'exécution résumé
**0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8**
Phases 0-1 = urgence sécurité (à enchaîner immédiatement).
Phase 4 peut démarrer en parallèle de 2-3 si une personne dédiée release.
Phases 5-6 = mise en production.
Phase 7 = post-lancement, dès qu'une clé API Dropbox Sign est disponible.
Phase 8 = V3, à cadrer chantier par chantier avant de démarrer.
Phase 9 = programme Pionnier, piste business indépendante (pas de dépendance technique avec 0-8), démarrable dès maintenant.

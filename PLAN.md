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

## Ordre d'exécution résumé
**0 → 1 → 2 → 3 → 4 → 5 → 6 → 7**
Phases 0-1 = urgence sécurité (à enchaîner immédiatement).
Phase 4 peut démarrer en parallèle de 2-3 si une personne dédiée release.
Phases 5-6 = mise en production.
Phase 7 = post-lancement, dès qu'une clé API Dropbox Sign est disponible.

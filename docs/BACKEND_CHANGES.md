# VYBZZZ — Annexe backend (changements à opérer)

> Document destiné au développeur backend (`vybzzz.fryandeatfood.com`).
> Recense les endpoints / champs / règles métier nécessaires pour les nouvelles
> fonctionnalités côté app. À réajuster une fois les accès backend disponibles.
>
> Légende priorité : 🔴 critique (sécurité) · 🟠 nécessaire à une feature · 🟢 confort
> Légende effort : S (petit) · M (moyen) · L (gros)

---

## 0. 🔴 SÉCURITÉ — À TRAITER EN PRIORITÉ ABSOLUE

### 0.1 Révoquer la clé Firebase Admin exposée
- Le service account **Firebase Admin SDK** (`firebase-adminsdk-fbsvc@vybzzz`,
  clé `bf1200fc5027…`) était **embarqué en clair dans l'app mobile**
  (`lib/services/vybzzz_bf1200fc5027.dart`, désormais supprimé côté app).
- **Action** : révoquer/régénérer cette clé dans Google Cloud Console
  (IAM → Comptes de service → Clés). **La considérer comme compromise.**
- La nouvelle clé doit rester **uniquement côté serveur** (variable
  d'environnement), jamais renvoyée à l'app.

### 0.2 Envoi des notifications push côté serveur
- L'app ne génère plus de token FCM admin (retiré). L'envoi des notifications
  doit se faire **exclusivement côté backend** (endpoint serveur).
- Vérifier/exposer un mécanisme : « envoyer notif à user X / topic Y ».

### 0.3 Autres secrets à faire tourner si exposés
- `appSign` ZegoCloud et clé RevenueCat : si présents dans des dépôts publics,
  prévoir rotation. Idéalement, accès Zego via **token serveur** (voir §4).

---

## 1. 🟠 TEASER LIVE (aperçu gratuit du live en cours)

**Objectif UX** : l'utilisateur swipe (droite → gauche) vers le live en cours
et peut le regarder **gratuitement 30 s ou 60 s**. Un overlay s'assombrit
progressivement jusqu'à devenir opaque, puis un CTA propose d'acheter l'accès /
voir d'autres lives / des shorts.

### Champs à ajouter sur l'objet `event`
| Champ | Type | Rôle |
|---|---|---|
| `teaser_enabled` | bool | Active/désactive l'aperçu gratuit pour ce live |
| `teaser_duration` | int (secondes) | Durée de l'aperçu (ex. 30 ou 60) |
| `teaser_stream_url` | string (option) | Flux/segment dédié au teaser si différent du live complet |

> Si on ne veut pas gérer la durée par event, l'app peut utiliser une valeur
> fixe (60 s). Mais une valeur backend par live est préférable (flexibilité
> artiste/admin).

### Règle métier
- Le visionnage du teaser **ne consomme pas** de ticket et **ne compte pas**
  comme une entrée payante (à exclure des stats de vente / revenus artiste).
- (Option anti-abus) limiter le nombre de teasers par user/live → voir §5.

---

## 2. 🟠 VÉRIFICATION D'ACCÈS AU LIVE (ticket)

**Objectif** : au passage sur le live, l'app vérifie automatiquement si
l'utilisateur a le droit d'entrer.

### Existant
- Le modèle `event` expose déjà `ticket_buyer_ids` (liste des acheteurs).
  L'app peut comparer avec l'ID user. ✅

### À confirmer / exposer
- Un endpoint fiable du type **`GET /event/{id}/access`** renvoyant l'état
  d'accès de l'utilisateur courant :
  ```json
  {
    "has_access": true,
    "access_type": "ticket | ghost_pass | referral | none",
    "expires_at": "2026-06-15T20:30:00Z"  // pour les accès limités dans le temps
  }
  ```
- Pourquoi un endpoint dédié plutôt que `ticket_buyer_ids` : nécessaire pour
  gérer les accès **temporaires** (passe fantôme, referral) qui ne sont pas de
  simples achats.

---

## 3. 🟠 PARRAINAGE (referral) — artiste ET user

**Objectif** : un artiste ou un user peut parrainer quelqu'un.
- **Artiste → user** : offrir des **tickets gratuits complets**.
- **User → user** : récompenses (ex. passe fantôme, points…).

### Endpoints à créer
| Méthode | Endpoint | Rôle |
|---|---|---|
| `POST` | `/referral/generate` | Génère un code/lien de parrainage pour l'utilisateur courant |
| `GET` | `/referral/me` | Liste des parrainages émis + statut (en attente / validé) |
| `POST` | `/referral/redeem` | Valider un code reçu (body : `{ "code": "..." }`) |

### Règles métier à définir
- Qui peut parrainer quoi (artiste = tickets complets ; user = récompense moindre).
- Limites (nb max de parrainages, anti-fraude : pas d'auto-parrainage, 1 redeem
  par user, etc.).
- Récompense attribuée au parrain ET/OU au filleul.

### Champs user utiles
- `referral_code` (string, unique) sur l'objet user.
- `referred_by` (id, option) pour tracer la source.

---

## 4. 🟠 PASSE FANTÔME 👻 (accès VIP gamifié, gratuit, limité)

**Objectif** : donner un accès VIP **temporaire** (ex. 10 min) à un live, qui
**n'est PAS compté comme un client payant** mais comme une **récompense de
gamification** (engagement, série de connexions, parrainage…).

### Point clé
- Doit être un **type d'accès distinct** d'un ticket payant, pour que le backend
  puisse l'**exclure des statistiques de vente et des revenus de l'artiste**.

### Endpoints / champs
| Méthode | Endpoint | Rôle |
|---|---|---|
| `POST` | `/ghost-pass/grant` | Octroie un passe fantôme à un user pour un event (durée en min) |
| `GET` | `/ghost-pass/me` | Passes fantômes actifs de l'utilisateur (avec `expires_at`) |

- Type d'accès renvoyé par `/event/{id}/access` : `"access_type": "ghost_pass"`.
- Champ `duration_minutes` + `expires_at` pour le compte à rebours côté app.
- Règle : un passe fantôme **expiré** ne redonne pas accès (l'app force la sortie
  ou propose l'achat à l'expiration).

---

## 5. 🟢 DÉCOUVERTE & ANTI-ABUS (confort)

### Feed découverte élargi
- Endpoint pour récupérer des lives/shorts **hors centres d'intérêt** de l'user
  (découverte large), ex. `GET /discover/live?scope=all`.
- Permet le CTA de fin de teaser « découvrir plus de concerts ».

### Shorts « accroche »
- Marquer certains shorts comme **accroche/teaser** (`is_hook: true`) pour les
  pousser en fin d'aperçu live.

### Anti-abus teaser (optionnel)
- Suivi du nombre de teasers vus par user/live (`teaser_views`) si on veut
  limiter le re-visionnage gratuit.

---

## 6. 🟢 QUALITÉ DES DONNÉES DE TEST (à nettoyer)

- Le champ `link` / `stream_url` de certains events de test pointe vers un site
  marchand tiers (`ordaraat.com`) — visible dans le live en démo.
  → Nettoyer les données de test pour qu'elles pointent vers de vrais flux VYBZZZ.
- Plusieurs artistes de test n'ont **pas de photo de profil** (avatar gris).
  → Ajouter des `profile_image` réalistes sur les comptes de démo.

---

## 7. RÉCAP — Ce que l'app peut faire SANS backend vs CE QUI BLOQUE

| Feature | App seule | Backend requis |
|---|---|---|
| Overlay teaser qui s'assombrit + countdown | ✅ | — |
| CTA de fin de teaser (UI) | ✅ | — |
| Durée de teaser fixe (60 s) | ✅ | — (mais § 1 préférable) |
| Durée de teaser par live | — | 🟠 `teaser_duration` |
| Vérif accès live | partiel (`ticket_buyer_ids`) | 🟠 `/event/{id}/access` pour accès temporaires |
| Parrainage réel | UI seulement | 🟠 endpoints `/referral/*` |
| Passe fantôme réel | UI + timer | 🟠 `ghost_pass` + exclusion stats |
| Découverte élargie | — | 🟢 `/discover/*` |

---

## 8. NOTES DIVERSES (déjà fait côté app)

- Refonte design complète en **bleu nuit + or** (thème unique verrouillé, polices
  Cinzel/Playfair/Montserrat/Inter).
- Gestion d'erreur améliorée : l'app affiche désormais les **erreurs de validation
  détaillées** renvoyées par l'API (`errors` par champ) au lieu d'un message
  générique. → garder ce format de réponse côté backend.
- L'app force le **mode sombre** (identité visuelle unique).

---

_Document à compléter une fois les accès backend obtenus._

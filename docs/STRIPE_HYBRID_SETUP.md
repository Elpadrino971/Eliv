# VYBZZZ — Abonnements : modèle Hybride (IAP + Stripe Web)

> Objectif : garder l'**IAP** (Apple/Google) comme chemin **instantané** (concert
> imminent → 1 tap), et proposer **Stripe Web** comme chemin **marge** (0 %
> commission Apple). Moins de friction = plus de cash.

L'app est **déjà scaffoldée** (branche `claude/magical-pasteur-zX3IV`) :
- `APIs.webSubscribeUrl` ← **le seul truc à remplir** (voir Partie 2)
- `SubscriptionController.subscribeOnWeb()` ← ouvre le checkout web
- Bannière « S'abonner sur le web » sous les plans (non bloquante)

---

## Partie 1 — À FAIRE DANS LE DASHBOARD STRIPE (aucun code, Mode test)

### 1. Créer le produit + le tarif récurrent
1. Menu gauche → **Catalogue de produits** → **+ Ajouter un produit**
2. **Nom** : `VYBZZZ Premium` (par ex.)
3. **Modèle de tarification** : *Récurrent* → **Mensuel** → prix (ex. `9,99 €`)
   - (option) ajouter un 2e tarif **Annuel** sur le même produit
4. **Enregistrer**

### 2. Créer le lien de paiement (Payment Link)
1. Menu → **Payments → Liens de paiement** (ou « Créer un lien de paiement »
   depuis l'accueil)
2. **Nouveau** → choisir le produit/tarif `VYBZZZ Premium`
3. **Après le paiement** : *Rediriger les clients* → mettre une page de retour
   (ex. `https://vybzzz.fryandeatfood.com/merci`) — facultatif mais propre
4. **Créer** → **copier l'URL** (forme `https://buy.stripe.com/test_xxxxx`)

> 🔑 **Important — relier le paiement à l'utilisateur** : les Payment Links
> acceptent un paramètre `client_reference_id`. L'app l'ajoute automatiquement.
> Stripe le renverra dans le webhook → c'est comme ça que le backend saura
> **quel user** a payé. (L'app envoie déjà `?user_id=...`; voir Partie 3 pour
> mapper `user_id` → `client_reference_id`.)

---

## Partie 2 — BRANCHER L'APP (1 ligne, je m'en occupe)

Dans `lib/Global/api.dart` :
```dart
static const String webSubscribeUrl = 'https://buy.stripe.com/test_xxxxx';
```
→ Donne-moi l'URL copiée à l'étape 2, je la mets et je commit. Fini côté app.

---

## Partie 3 — POUR LE DEV BACKEND (Laravel) — le minimum

### A. Webhook Stripe (activer l'abo après paiement) — OBLIGATOIRE
Sans ça, le paiement passe mais l'app ne sait pas que le user est devenu premium.

1. **Dashboard Stripe → Développeurs → Webhooks → + Ajouter un endpoint**
   - URL : `https://vybzzz.fryandeatfood.com/api/stripe/webhook`
   - Événements : `checkout.session.completed`,
     `customer.subscription.deleted` (pour gérer l'expiration/annulation)
2. **Code Laravel** (endpoint `POST /api/stripe/webhook`) :
   - **Vérifier la signature** (`Stripe-Signature` + `whsec_...`)
   - Sur `checkout.session.completed` :
     - récupérer `session.client_reference_id` (= `user_id` envoyé par l'app)
     - marquer l'utilisateur **abonné** en base (même effet que l'actuel
       `/api/subscription/buy`, mais déclenché par Stripe)
     - stocker `stripe_customer_id` + `stripe_subscription_id` sur le user
   - Sur `customer.subscription.deleted` : repasser l'utilisateur **non-abonné**
3. Renvoyer **HTTP 200** rapidement.

> L'app appelle le lien sous la forme :
> `…/test_xxx?user_id=<ID>` — mais Stripe attend `client_reference_id`.
> **Deux options** (au choix du dev) :
> - (simple) le dev change le paramètre attendu, **ou**
> - on aligne l'app pour envoyer `client_reference_id=<ID>` au lieu de
>   `user_id` (dis-moi, je change la ligne dans `subscribeOnWeb()`).

### B. Fuite Android — À VÉRIFIER EN PRIORITÉ 🚨
Aujourd'hui, sur Android l'app appelle directement
`POST /api/subscription/buy` (user_id + subscriptions_id) **sans aucun
paiement** → l'abo semble s'activer **gratuitement**.
- **Vérifier** : est-ce que `/api/subscription/buy` exige réellement un
  paiement ? Si non → **faille de revenu**.
- **Corriger** : l'activation premium ne doit se faire **que** via :
  - un achat **IAP** validé (RevenueCat), **ou**
  - le **webhook Stripe** ci-dessus.
  → ne plus jamais activer un abo sur simple appel client non payé.

---

## Partie 4 — Test de bout en bout (Mode test Stripe)
1. App → écran Abonnements → **« S'abonner sur le web »** → ouvre le lien Stripe
2. Payer avec la carte test `4242 4242 4242 4242`, date future, CVC quelconque
3. Vérifier : Stripe Dashboard → **Paiements** montre le paiement test
4. Vérifier : le webhook a bien passé le user en **premium** dans l'app
5. OK en test → recréer produit/lien/webhook en **Mode Live** + remplacer l'URL

---

## Récap « qui fait quoi »
| Tâche | Qui |
|---|---|
| Produit + Tarif + Payment Link (dashboard) | **Toi (5 clics)** ou le dev |
| Brancher `webSubscribeUrl` dans l'app | **Claude (1 ligne)** |
| Webhook Laravel (activation abo) | **Dev** |
| Vérifier/fermer la fuite Android | **Dev** |
| Passage Test → Live | Toi + Dev |

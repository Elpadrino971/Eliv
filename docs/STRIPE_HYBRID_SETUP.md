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

---

# Partie 5 — CODE PRÊT À DÉPOSER (pour le dev)

## 5.A — La page `vybzzz.com/subscribe` (Supabase Edge Function)

> Rôle : lire `user_id` → demander le palier courant à Supabase
> (`current_founder_plan()`) → créer un Stripe Checkout avec le bon `price_id`
> → rediriger l'artiste vers le paiement. Le `user_id` part en
> `client_reference_id` (le webhook s'en sert pour activer l'abo).

`supabase/functions/subscribe/index.ts`
```ts
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
});
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// Palier -> Stripe price_id (LIVE). TODO: remplacer le price_id Pro.
const PRICE_BY_PLAN: Record<string, string> = {
  founder_t1: "price_1TajbvHfGnA3ljfTyRCpfKvX", // 79 €
  founder_t2: "price_1Tajc5HfGnA3ljfTqXyJ9kIZ", // 99 €
  founder_t3: "price_1TajcGHfGnA3ljfTYWvJHbhO", // 129 €
  pro:        "price_PRO_199_A_REMPLACER",       // 199 € (à renseigner)
};

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const userId = url.searchParams.get("user_id");
  if (!userId) return new Response("missing user_id", { status: 400 });

  // 1) Palier courant. TODO: aligner sur le vrai retour de current_founder_plan()
  const { data, error } = await supabase.rpc("current_founder_plan");
  if (error) return new Response("plan error", { status: 500 });
  const plan = typeof data === "string" ? data : (data?.plan ?? "pro");
  const price = PRICE_BY_PLAN[plan] ?? PRICE_BY_PLAN.pro;

  // 2) Session Checkout (abonnement) reliée à l'utilisateur
  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price, quantity: 1 }],
    client_reference_id: userId,
    metadata: { user_id: userId, plan },
    success_url: "https://vybzzz.com/merci?session_id={CHECKOUT_SESSION_ID}",
    cancel_url: "https://vybzzz.com/subscribe",
  });

  // 3) Redirection vers la page de paiement Stripe
  return Response.redirect(session.url!, 302);
});
```
Déploiement : `supabase functions deploy subscribe --no-verify-jwt`
Secrets : `supabase secrets set STRIPE_SECRET_KEY=sk_live_...`
Router `vybzzz.com/subscribe` → cette fonction (ou appeler l'URL de la fonction
directement depuis le bouton — dans ce cas mettre cette URL dans
`APIs.webSubscribeUrl`).

## 5.B — Webhook (déjà décrit Partie 3.A) — squelette
`supabase/functions/stripe-webhook/index.ts` → écouter
`checkout.session.completed`, lire `session.client_reference_id` (= user_id),
passer l'artiste **premium** + stocker `stripe_customer_id` /
`stripe_subscription_id`. Sur `customer.subscription.deleted` → retirer premium.

---

# Partie 6 — RevenueCat / IAP iOS (les "modifs" à faire)

> Pour que le **bouton IAP** vende les paliers, il faut les produits côté Apple.
> Sur Stripe le "prix gelé à vie" est trivial ; sur Apple, ça passe par le
> **grandfathering** (un abonné garde son prix tant qu'on ne l'augmente pas).

**À créer dans App Store Connect** (groupe d'abonnement unique, auto-renouvelable) :
| Produit | Prix cible | Palier Apple à choisir |
|---|---|---|
| `vybzzz_founder_t1` | 79 € | le plus proche |
| `vybzzz_founder_t2` | 99 € | le plus proche |
| `vybzzz_founder_t3` | 129 € | le plus proche |
| `vybzzz_pro` | 199 € | le plus proche |

**Dans RevenueCat** :
1. Ajouter ces 4 produits + une **entitlement** `premium`.
2. Créer une **offering** par palier (ou 1 offering et l'app choisit le package).
3. L'app doit présenter **uniquement le produit du palier courant**
   (via `current_founder_plan()` exposé par une petite API). Les abonnés
   existants restent sur leur produit → **prix gelé** (grandfathering Apple).

**Côté app (je m'en charge quand RevenueCat sera prêt)** : aujourd'hui
`fetchOffers` filtre par `storeProduct.title == title`. Je l'alignerai pour
sélectionner le package du **palier courant** au lieu du titre.

> 💡 Reco honnête : le "gelé à vie" fondateur est **simple sur le web**, **fiddly
> sur Apple**. Si tu veux simplifier, l'IAP pourrait ne vendre que le **Pro
> 199 €** (1 seul produit), et réserver les **tarifs fondateurs au web**. À toi
> de voir — mais le web reste le chemin "marge" de toute façon.

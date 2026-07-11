# VYBZZZ — Abonnements : modèle Hybride (IAP + Stripe Web)

> Objectif : garder l'**IAP** (Apple/Google) comme chemin **instantané**, et
> proposer **Stripe Checkout** comme chemin **marge** (0 % commission Apple).
> **Implémenté et testé** contre le vrai compte Stripe (`vybzzz.com`).

## Architecture réelle (backend Node/Express, pas Laravel/Supabase)

```
App (Android uniquement, anti-steering Apple 3.1.1)
  -> POST /api/subscription/checkout { subscriptions_id, annual }
  -> backend crée une Stripe Checkout Session (services/stripe.js)
  -> renvoie { checkout_url } -> l'app l'ouvre au navigateur
  -> paiement -> Stripe envoie le webhook checkout.session.completed
  -> POST /api/stripe/webhook (routes/stripe.routes.js, corps brut + signature)
  -> INSERT INTO user_subscriptions (status='active', stripe_*)
```

Sur **iOS**, le lien "Payer par carte" est masqué (`onWebPurchaseTap: null`
dans `all_subscription_screen.dart`) — uniquement l'IAP (RevenueCat) y est
proposé, conformément à la règle anti-steering Apple.

## Côté Stripe Dashboard (déjà fait pour cette session)

Produits/Prix nettoyés en mode **LIVE** (argent réel) :
- `Vybzzz — Starter / Growth / Elite` : 1 prix EUR chacun (99€/199€/299€ / mois)
- `Vybzzz Fondateur — Palier 1/2/3` : 79€/99€/129€ / mois (sièges limités)
- Les anciens prix USD en doublon ont été désactivés (pas supprimés, Stripe
  ne permet pas de supprimer un Price, seulement `active: false`).

**Reste à faire dans le Dashboard** :
1. Développeurs → Webhooks → + Ajouter un endpoint
   - URL : `https://api.vybzzz.online/api/stripe/webhook`
   - Événements : `checkout.session.completed`, `customer.subscription.updated`,
     `customer.subscription.deleted`
   - Copier le **Signing secret** → `STRIPE_WEBHOOK_SECRET` sur le VPS
2. Développeurs → Clés API → copier la clé secrète → `STRIPE_SECRET_KEY` sur le VPS

## Côté admin VYBZZZ

Chaque ligne de la table `subscriptions` (page **Abonnements**) a maintenant
2 champs à coller à la main : **Stripe Price ID — mensuel** / **annuel**
(format `price_...`, visible dans le Dashboard Stripe sur la fiche du
produit). Tant qu'un plan n'a pas de Price ID renseigné, le bouton "Payer par
carte" renvoie une erreur propre côté app (pas de crash).

## Sécurité — pas d'activation gratuite

`/api/subscription/buy` (ancien endpoint IAP) ne touche plus la base tout
seul. Un abonnement ne devient `active` dans `user_subscriptions` que via :
- le webhook Stripe (`checkout.session.completed`), **ou**
- une attribution manuelle depuis l'admin (bouton "Abonner").

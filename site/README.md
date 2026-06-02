# Vybzzz — Site web (style YouTube + TikTok)

Site web multi-pages inspiré de l'application mobile Flutter **Vybzzz**
(concerts en direct, cadeaux virtuels en **Arena Points**, billetterie,
Studio Pro artiste, paiement **VyBzzZ Pay / Stripe**).

Charte reprise de l'app : **or/bronze `#c6a75e`** sur fond sombre `#0b0e14`.
Toutes les données (prix, packs, cadeaux, abonnements) sont en **`$` et ARENA
POINTS**, cohérentes avec l'app, et centralisées dans `data.js`.

## 📄 Pages
| Fichier | Rôle |
|---|---|
| `index.html` | Accueil **grille YouTube** : artistes vedettes, catégories filtrables, grille de lives/vidéos |
| `feed.html` | **Feed vertical TikTok** plein écran (snap) : like, cadeau, partage, suivre |
| `store.html` | **Boutique** : packs d'Arena Points (avec bonus), catalogue de cadeaux, abonnements |
| `dashboard.html` | **Studio Pro** : KPIs (tickets, revenus, spectateurs), courbe de revenus, transactions, retraits + Connect Stripe |
| `checkout.html` | **Paiement** (maquette) : carte animée, Apple/Google Pay, VyBzzZ Pay, récap dynamique (`?event=` ou `?pack=`) |
| `faq.html` | **FAQ** en accordéon |
| `artist.html` | **Devenir artiste** + **contrat PDF téléchargeable** (jsPDF) |

## 🧠 Fichiers communs
- `data.js` — toutes les données (artistes, events, packs, cadeaux, plans, FAQ) + helpers de format.
- `app.js` — châssis (header/footer injectés), curseur, reveals, compteurs, boutons magnétiques, tilt, panneau cadeaux, rendu de chaque page.
- `styles.css` — design system complet.

## ✨ Animations
Préchargeur de reveals au scroll, curseur custom + boutons magnétiques, fond
*aurora* animé, grille hover/zoom, feed TikTok snap + actions, animation de
cadeaux qui s'envolent, compteurs animés, courbe de revenus qui se dessine,
carte de paiement live, toasts.

## 🚀 Lancer en local
```bash
cd site
python3 -m http.server 8080
# ouvrir http://localhost:8080 dans le navigateur
```
Aucune build : HTML/CSS/JS pur. Seule dépendance externe = jsPDF (CDN) pour
le contrat PDF.

## 🔌 Brancher sur l'API Vybzzz (plus tard)
Remplacer les tableaux de `data.js` par des `fetch()` vers
`https://vybzzz.fryandeatfood.com/api` :
- `events` → `/events`, `/banner-events`
- `artists` → `/featured-artists`
- `packages` → `/packages/list`
- `gifts` → `/gifts`
- `plans` → `/subscription/get`
- `faq` → `/settings/get-management`

> ⚠️ Le paiement est une **maquette UI** (aucun débit réel, aucune clé secrète).
> Pour un vrai Stripe Checkout, il faut un backend qui crée la session côté serveur.

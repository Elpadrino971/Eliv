# Vybzzz — Site web (landing premium)

Interface web vitrine inspirée de l'application mobile Flutter **Vybzzz**
(plateforme de live streaming musical : concerts en direct, cadeaux virtuels,
billetterie, studio artiste, wallet).

Reprend la charte graphique de l'app : **or/bronze `#c6a75e`** sur fond sombre,
typographies modernes, le tout dans un univers « dark luxe ».

## ✨ Ce qui est inclus
- Préchargeur animé (révélation du logotype)
- Curseur personnalisé + traînée, et boutons magnétiques
- Fond *aurora* animé + grain cinématographique
- Hero avec carte « live » flottante et cadeaux qui s'envolent
- Bandeau marquee défilant
- Cartes features en glassmorphism avec tilt 3D
- Carrousel d'artistes (données en JS, facile à brancher sur l'API)
- Section cadeaux avec orbite animée, dashboard studio avec graphe animé
- Compteurs animés, reveals au scroll (GSAP ScrollTrigger), parallax
- 100 % responsive + respect de `prefers-reduced-motion`

## 🚀 Lancer en local
Aucune build nécessaire (HTML/CSS/JS pur, GSAP via CDN) :

```bash
cd site
python3 -m http.server 8080
# puis ouvrir http://localhost:8080
```

## 🔌 Brancher sur l'API Vybzzz
- Carrousel artistes : tableau `artists` dans `app.js` → remplacer par un
  `fetch('https://vybzzz.fryandeatfood.com/api/featured-artists')`.
- Compteurs / stats : attributs `data-count` dans `index.html`.

## 📁 Structure
```
site/
├── index.html     # structure des sections
├── styles.css     # design system (couleurs, glass, animations)
├── app.js         # interactions, GSAP, carrousel, compteurs
└── assets/        # logo + visuels repris de l'app mobile
```

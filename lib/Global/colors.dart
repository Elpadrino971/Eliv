import 'package:flutter/material.dart';

const Color scaffoldBackgroundColor = midnightPrimary;
const Color whiteColor = Colors.white;
const Color blackColor = Colors.black;
// Accent de base unifie sur l'or premium (voir goldPrimary plus bas).
const Color mainThemeColor = goldPrimary;
const Color borderGreyColor = Color(0xffB3B3B3);
const Color greyColor = Color(0xff808080);
const Color yellowColor = Color(0xffFFBD22);
const Color textXolor = Color(0xffD4D4D4);
const Color boxColor = Color.fromARGB(255, 243, 243, 243);
const Color redColor = Color(0xff7A0709);
const Color darkmodeColor = cardDeep;

/// VYBZZZ premium design tokens (deep navy + gold)
/// Utilisés par les widgets timeline / carte billet / empty states.
const Color vybzzzNavy = Color(0xff06111F); // primary background
const Color vybzzzSurface = Color(0xff0B1A2A); // card surface
const Color vybzzzGold = Color(0xffD4A72C); // gold accent
const Color vybzzzGoldLight = Color(0xffE7C766); // gold gradient start
const Color vybzzzGoldDark = Color(0xffB98A20); // gold gradient end
const Color vybzzzTextSecondary = Color(0xffAEB6C2); // secondary text
const Color vybzzzGoldBorder = Color(0x40D4A72C); // rgba(212,167,44,0.25) subtle border

/// ─────────────────────────────────────────────────────────────
/// VYBZZZ — Premium design tokens (Midnight blue + Gold)
/// Direction : live concert haut de gamme, cinématique, immersif.
/// ─────────────────────────────────────────────────────────────

// Fonds
const Color midnightPrimary = Color(0xff071426); // fond principal (bleu nuit)
const Color midnightSecondary = Color(0xff0B1020); // cartes principales, bottom nav
const Color cardDeep = Color(0xff0D1B2A); // cartes secondaires, listes

// Or premium
const Color goldPrimary = Color(0xffD8B45A); // boutons, logo, états actifs, prix
const Color goldSecondary = Color(0xffC8A24A); // contours, icônes, séparateurs

// Texte
const Color ivory = Color(0xffF4EFE6); // titres et textes importants
const Color textMuted = Color(0xffAEB7C2); // sous-titres, dates, lieux, méta

// Live
const Color liveRed = Color(0xffB1121B); // badges LIVE uniquement

/// Dégradé de carte premium (haut → bas)
const LinearGradient kCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [cardDeep, midnightPrimary],
);

/// Dégradé du bouton or principal (haut → bas)
const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xffE6C76A), goldSecondary],
);

/// Overlay bleu nuit appliqué sur les images de concert (lisibilité)
const LinearGradient kImageOverlay = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x33071426), Color(0xD9071426)], // 0.2 → 0.85
);

/// Bordure fine or pour les cartes premium
final Border kGoldBorder = Border.all(
  color: goldSecondary.withValues(alpha: 0.35),
  width: 1,
);

/// Ombre douce des cartes premium
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12)),
];

import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// En-tête de section premium VYBZZZ.
/// Titre ivoire en uppercase espacé, accent or, et "View All" discret
/// avec une flèche dorée. Unifie toutes les sections de l'accueil.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.onViewAll,
  });

  final String title;

  /// Asset optionnel affiché avant le titre (teinté en or).
  final String? icon;

  /// Si non nul, affiche le bouton "View All".
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Image.asset(icon!, width: 18, height: 18, color: goldPrimary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              color: ivory,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 3,
            ),
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewAll,
            child: Row(
              children: [
                Text(
                  'view_all'.tr.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward,
                  size: 15,
                  color: goldPrimary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

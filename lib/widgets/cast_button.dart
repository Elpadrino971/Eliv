import 'package:artist/Global/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Bouton "Caster" pour diffuser un concert/replay sur une TV.
///
/// - **iOS** : affiche le bouton AirPlay natif (`AVRoutePickerView` via PlatformView
///   `vybzzz/airplay_button`, enregistré dans AppDelegate.swift). Au tap, iOS ouvre
///   le sélecteur AirPlay et diffuse le flux Mux HLS en cours sur l'Apple TV / TV.
/// - **Android / autres** : icône cast avec message (Chromecast à brancher en v2).
class CastButton extends StatelessWidget {
  const CastButton({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Le PlatformView gère lui-même le tap + le sélecteur AirPlay système.
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: blackColor.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: const UiKitView(viewType: 'vybzzz/airplay_button'),
      );
    }

    // Fallback (Android / desktop) : icône cast.
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('cast_coming_soon'.tr),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: blackColor.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.cast_rounded, color: whiteColor, size: size),
      ),
    );
  }
}

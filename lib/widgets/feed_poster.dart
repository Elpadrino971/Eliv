import 'package:artist/Global/colors.dart';
import 'package:artist/Global/mux.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Poster affiché INSTANTANÉMENT pendant que la vidéo du feed (Pour toi / Clips)
/// se charge, puis PAR-DESSUS le lecteur tant que sa première image n'est pas
/// rendue. L'URL du feed est déjà une URL Mux
/// (https://stream.mux.com/<playbackId>.m3u8) : on en dérive la première
/// image (https://image.mux.com/<playbackId>/thumbnail.webp?width=720&time=0),
/// décodée au plus à 720 px de large. Jamais d'écran noir : la vidéo semble
/// se lancer tout de suite. Un petit indicateur discret (coin bas-droit)
/// signale le chargement ; repli sur un dégradé sombre si l'URL n'est pas
/// une URL Mux.
class FeedPoster extends StatelessWidget {
  const FeedPoster({super.key, required this.url, this.showIndicator = true});

  final String? url;

  /// Petit rond de chargement discret par-dessus le poster.
  final bool showIndicator;

  /// Largeur max de décodage de la miniature (≤ 720 : mémoire contenue).
  static const int posterCacheWidth = 720;

  /// Miniature Mux dérivée de l'URL HLS, ou null (URL non Mux).
  static String? thumbnailFor(String? url) {
    final id = Mux.playbackIdFromUrl(url);
    return id == null ? null : Mux.feedPoster(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = thumbnailFor(url);
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [midnightSecondary, blackColor],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (t == null)
          fallback
        else
          CachedNetworkImage(
            imageUrl: t,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: posterCacheWidth,
            // Pendant le chargement du poster lui-même, fond sombre (pas de
            // saut visuel).
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          ),
        if (showIndicator)
          const Positioned(
            right: 18,
            bottom: 120,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: goldPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

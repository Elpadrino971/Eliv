import 'package:artist/Global/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Poster affiché INSTANTANÉMENT pendant que la vidéo du feed (Pour toi / Clips)
/// se charge. L'URL du feed est déjà une URL Mux
/// (https://stream.mux.com/<playbackId>.m3u8) : on en dérive l'image
/// (https://image.mux.com/<playbackId>/thumbnail.jpg). Ça enlève l'écran noir
/// + rond de chargement -> la vidéo semble se lancer tout de suite.
/// Repli : dégradé sombre discret si l'URL n'est pas une URL Mux.
class FeedPoster extends StatelessWidget {
  const FeedPoster({super.key, required this.url});

  final String? url;

  String? _thumbUrl() {
    final u = url;
    if (u == null || u.isEmpty) return null;
    final m = RegExp(r'stream\.mux\.com/([^./?]+)').firstMatch(u);
    if (m == null) return null;
    return 'https://image.mux.com/${m.group(1)}/thumbnail.jpg?width=640';
  }

  @override
  Widget build(BuildContext context) {
    final t = _thumbUrl();
    final fallback = Container(
      color: blackColor,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: goldPrimary),
    );
    if (t == null) return fallback;
    return CachedNetworkImage(
      imageUrl: t,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Pendant le chargement du poster lui-même, fond noir (pas de saut visuel).
      placeholder: (_, __) => Container(color: blackColor),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// VybzzZ — Helpers Mux (https://mux.com)
///
/// Mux sert le VOD/replay en HLS adaptatif. Tout part d'un PLAYBACK ID
/// (public, non secret). On ne stocke JAMAIS de token Mux dans l'app : la
/// creation d'assets se fait cote backend, l'app ne fait que LIRE le HLS.
class Mux {
  Mux._();

  /// URL HLS adaptative a passer au lecteur video (video_player lit le .m3u8).
  ///   https://stream.mux.com/<PLAYBACK_ID>.m3u8
  static String hlsUrl(String playbackId) =>
      'https://stream.mux.com/$playbackId.m3u8';

  /// Miniature (poster) generee par Mux.
  ///   https://image.mux.com/<PLAYBACK_ID>/thumbnail.jpg?time=<s>
  static String thumbnail(String playbackId, {int timeSeconds = 0}) =>
      'https://image.mux.com/$playbackId/thumbnail.jpg?time=$timeSeconds';

  /// Apercu anime (gif) — utile pour des cartes de replay.
  static String animatedGif(String playbackId) =>
      'https://image.mux.com/$playbackId/animated.gif';

  /// Pour un playback signe (fenetre d'acces 7/60j), le backend renvoie un
  /// token JWT a coller en query. L'app n'a qu'a l'ajouter.
  static String signedHlsUrl(String playbackId, String token) =>
      'https://stream.mux.com/$playbackId.m3u8?token=$token';

  /// Playback ID extrait d'une URL HLS Mux
  /// (https://stream.mux.com/<PLAYBACK_ID>.m3u8[?...]), ou null si l'URL
  /// n'est pas une URL Mux.
  static String? playbackIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return RegExp(r'stream\.mux\.com/([^./?]+)').firstMatch(url)?.group(1);
  }

  /// Miniature (webp) pour les feeds verticaux : première image du clip,
  /// largeur 720 px (assez pour un écran de téléphone, décodage léger).
  ///   https://image.mux.com/<PLAYBACK_ID>/thumbnail.webp?width=720&time=0
  static String feedPoster(String playbackId) =>
      'https://image.mux.com/$playbackId/thumbnail.webp?width=720&time=0';

  /// URL HLS optimisée pour le mobile : plafonne les renditions à 720p
  /// (modificateur Mux `max_resolution`) -> manifeste plus léger, premier
  /// segment plus petit, démarrage plus rapide. Sans effet sur une URL non
  /// Mux ou déjà paramétrée ; un playback signé (`token=`) est laissé tel
  /// quel car ses paramètres doivent être inclus dans le token.
  static String mobileHls(String url) {
    if (!url.contains('stream.mux.com') || !url.contains('.m3u8')) return url;
    if (url.contains('max_resolution=') || url.contains('token=')) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}max_resolution=720p';
  }
}

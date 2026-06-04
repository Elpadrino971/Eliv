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
}

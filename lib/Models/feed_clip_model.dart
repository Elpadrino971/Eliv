/// Clip d'un feed géré depuis l'admin (GET /api/feed-clips?feed=for_you|clips).
///
/// Champs renvoyés par l'API : `id`, `title`, `video_url` (HLS Mux
/// `https://stream.mux.com/<id>.m3u8` ou URL directe) et `mux_playback_id`
/// (null pour une vidéo hébergée ailleurs).
class FeedClip {
  const FeedClip({
    required this.videoUrl,
    this.id,
    this.title,
    this.muxPlaybackId,
  });

  final int? id;
  final String? title;
  final String videoUrl;
  final String? muxPlaybackId;

  /// Construit un clip à partir d'une entrée de la liste `list` de l'API.
  /// Renvoie null si l'URL vidéo est absente (clip inutilisable).
  static FeedClip? fromJson(dynamic json) {
    if (json is! Map) return null;
    final url = json['video_url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final rawId = json['id'];
    final int? id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
    final rawTitle = json['title'];
    final String? title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : null;
    final rawMux = json['mux_playback_id'];
    String? mux = rawMux is String && rawMux.trim().isNotEmpty
        ? rawMux.trim()
        : null;
    // L'URL HLS Mux suffit à retrouver l'id de lecture quand l'API ne le
    // renvoie pas (anciens enregistrements).
    mux ??= RegExp(r'stream\.mux\.com/([^./?]+)').firstMatch(url)?.group(1);
    return FeedClip(id: id, title: title, videoUrl: url, muxPlaybackId: mux);
  }

  /// Miniature Mux (portrait, cadrage intelligent) ou null si le clip n'est
  /// pas hébergé sur Mux : l'appelant affiche alors un fond dégradé.
  String? get thumbnailUrl {
    final id = muxPlaybackId;
    if (id == null || id.isEmpty) return null;
    return 'https://image.mux.com/$id/thumbnail.webp?width=480&fit_mode=smartcrop';
  }
}

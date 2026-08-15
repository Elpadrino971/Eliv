import 'dart:convert';

/// Modèle léger pour la grille "façon TikTok" de la fiche artiste.
/// Alimenté par GET /api/artist/:id/clips (shorts déjà validés des feeds
/// "Pour toi" et "Clips"). Les concerts restent gérés par EventsModel.
ArtistClipsModel artistClipsModelFromJson(String str) =>
    ArtistClipsModel.fromJson(json.decode(str));

class ArtistClipsModel {
  final String? status;
  final int count;
  final ClipCounts counts;
  final List<ArtistClip> list;

  ArtistClipsModel({
    this.status,
    this.count = 0,
    ClipCounts? counts,
    List<ArtistClip>? list,
  })  : counts = counts ?? ClipCounts(),
        list = list ?? <ArtistClip>[];

  factory ArtistClipsModel.fromJson(Map<String, dynamic> json) =>
      ArtistClipsModel(
        status: json['status'],
        count: json['count'] ?? 0,
        counts: json['counts'] != null
            ? ClipCounts.fromJson(json['counts'])
            : ClipCounts(),
        list: json['list'] != null
            ? List<ArtistClip>.from(
                (json['list'] as List).map((x) => ArtistClip.fromJson(x)))
            : <ArtistClip>[],
      );
}

class ClipCounts {
  final int forYou;
  final int clips;

  ClipCounts({this.forYou = 0, this.clips = 0});

  factory ClipCounts.fromJson(Map<String, dynamic> json) => ClipCounts(
        forYou: json['for_you'] ?? 0,
        clips: json['clips'] ?? 0,
      );
}

class ArtistClip {
  final int? id;
  final String feed; // 'for_you' | 'clips'
  final String? title;
  final String? videoUrl;
  final String? muxPlaybackId;
  final String? thumbnail;
  final String? createdAt;

  ArtistClip({
    this.id,
    this.feed = 'for_you',
    this.title,
    this.videoUrl,
    this.muxPlaybackId,
    this.thumbnail,
    this.createdAt,
  });

  factory ArtistClip.fromJson(Map<String, dynamic> json) => ArtistClip(
        id: json['id'],
        feed: json['feed'] == 'clips' ? 'clips' : 'for_you',
        title: json['title'],
        videoUrl: json['video_url'],
        muxPlaybackId: json['mux_playback_id'],
        thumbnail: json['thumbnail'],
        createdAt: json['created_at'],
      );
}

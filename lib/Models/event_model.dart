// To parse this JSON data, do
//
//     final eventModel = eventModelFromJson(jsonString);

import 'dart:convert';

import 'package:artist/Models/genre_model.dart';
import 'package:artist/Models/user_model.dart';

EventsModel eventModelFromJson(String str, [String? key]) =>
    EventsModel.fromJson(json.decode(str), key);

String eventModelToJson(EventsModel data) => json.encode(data.toJson());

class EventsModel {
  final String? status;
  final List<Event>? data;

  EventsModel({this.status, this.data});

  EventsModel copyWith({String? status, List<Event>? data}) =>
      EventsModel(status: status ?? this.status, data: data ?? this.data);

  factory EventsModel.fromJson(Map<String, dynamic> json, String? key) =>
      EventsModel(
        status: json["status"],
        data: json[key ?? "data"] == null
            ? []
            : List<Event>.from(
                json[key ?? "data"]!.map((x) => Event.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "data": data == null
        ? []
        : List<dynamic>.from(data!.map((x) => x.toJson())),
  };
}

class Event {
  final int? id;
  final int? artistId;
  final String? name;
  final String? coverImage;
  final String? ticketPrice;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final int? genreId;
  final String? description;
  final String? videoReel;
  final int? isPrivate;
  final int? hasLiveChat;
  final int? capacityLimit;
  final String? status;
  final String? link;
  final int? joinedUsersCount;
  final int? likesCount;
  final String? streamKey;
  final String? streamUrl;
  /// Playback id Mux du LIVE (mux_live_playback_id). Nullable : absent tant
  /// que le backend n'a pas créé de flux Mux pour ce concert.
  final String? muxLivePlaybackId;
  /// Mode de diffusion (live_mode) : 'mobile' (défaut, live depuis le
  /// téléphone via ZegoCloud) ou 'pro' (régie vidéo OBS/ATEM -> Mux, les fans
  /// regardent le HLS). Nullable : absent des anciennes réponses = 'mobile'.
  final String? liveMode;
  final DateTime? replayExpiresAt;
  final bool? replayExpired;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<int>? ticketBuyerIds;
  final Genre? genre;
  final User? artist;
  final List<Ticket>? tickets;
  final List<Activity>? activities;
  /// Artistes invités (partage des revenus). Nullable : absent des anciennes
  /// réponses, `[]` quand le concert n'a pas d'invité.
  final List<EventGuest>? guests;

  Event({
    this.id,
    this.artistId,
    this.name,
    this.coverImage,
    this.ticketPrice,
    this.startDateTime,
    this.endDateTime,
    this.genreId,
    this.description,
    this.videoReel,
    this.isPrivate,
    this.hasLiveChat,
    this.capacityLimit,
    this.status,
    this.link,
    this.joinedUsersCount,
    this.likesCount,
    this.streamKey,
    this.streamUrl,
    this.muxLivePlaybackId,
    this.liveMode,
    this.replayExpiresAt,
    this.replayExpired,
    this.createdAt,
    this.updatedAt,
    this.ticketBuyerIds,
    this.genre,
    this.artist,
    this.tickets,
    this.activities,
    this.guests,
  });

  /// Vrai si le concert est diffusé par une régie vidéo (OBS/ATEM -> Mux).
  bool get isProLive => liveMode == 'pro';

  Event copyWith({
    int? id,
    int? artistId,
    String? name,
    String? coverImage,
    String? ticketPrice,
    DateTime? startDateTime,
    DateTime? endDateTime,
    int? genreId,
    String? description,
    String? videoReel,
    int? isPrivate,
    int? hasLiveChat,
    int? capacityLimit,
    String? status,
    String? link,
    int? joinedUsersCount,
    int? likesCount,
    String? streamKey,
    String? streamUrl,
    String? muxLivePlaybackId,
    String? liveMode,
    DateTime? replayExpiresAt,
    bool? replayExpired,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int>? ticketBuyerIds,
    Genre? genre,
    User? artist,
    List<Ticket>? tickets,
    List<Activity>? activities,
    List<EventGuest>? guests,
  }) => Event(
    id: id ?? this.id,
    artistId: artistId ?? this.artistId,
    name: name ?? this.name,
    coverImage: coverImage ?? this.coverImage,
    ticketPrice: ticketPrice ?? this.ticketPrice,
    startDateTime: startDateTime ?? this.startDateTime,
    endDateTime: endDateTime ?? this.endDateTime,
    genreId: genreId ?? this.genreId,
    description: description ?? this.description,
    videoReel: videoReel ?? this.videoReel,
    isPrivate: isPrivate ?? this.isPrivate,
    hasLiveChat: hasLiveChat ?? this.hasLiveChat,
    capacityLimit: capacityLimit ?? this.capacityLimit,
    status: status ?? this.status,
    link: link ?? this.link,
    joinedUsersCount: joinedUsersCount ?? this.joinedUsersCount,
    likesCount: likesCount ?? this.likesCount,
    streamKey: streamKey ?? this.streamKey,
    streamUrl: streamUrl ?? this.streamUrl,
    muxLivePlaybackId: muxLivePlaybackId ?? this.muxLivePlaybackId,
    liveMode: liveMode ?? this.liveMode,
    replayExpiresAt: replayExpiresAt ?? this.replayExpiresAt,
    replayExpired: replayExpired ?? this.replayExpired,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    ticketBuyerIds: ticketBuyerIds ?? this.ticketBuyerIds,
    genre: genre ?? this.genre,
    artist: artist ?? this.artist,
    tickets: tickets ?? this.tickets,
    activities: activities ?? this.activities,
    guests: guests ?? this.guests,
  );

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json["id"],
    artistId: json["artist_id"],
    name: json["name"],
    coverImage: json["cover_image"],
    ticketPrice: json["ticket_price"],
    startDateTime: json["start_date_time"] == null
        ? null
        : DateTime.parse(json["start_date_time"]),
    endDateTime: json["end_date_time"] == null
        ? null
        : DateTime.parse(json["end_date_time"]),
    genreId: json["genre_id"],
    description: json["description"],
    videoReel: json["video_reel"],
    isPrivate: json["is_private"],
    hasLiveChat: json["has_live_chat"],
    capacityLimit: json["capacity_limit"],
    status: json["status"],
    link: json["link"],
    joinedUsersCount: json["joined_users_count"],
    likesCount: json["likes_count"],
    streamKey: json["stream_key"],
    streamUrl: json["stream_url"],
    muxLivePlaybackId: json["mux_live_playback_id"]?.toString(),
    liveMode: json["live_mode"]?.toString(),
    replayExpiresAt: json["replay_expires_at"] == null
        ? null
        : DateTime.parse(json["replay_expires_at"]),
    replayExpired: json["replay_expired"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    ticketBuyerIds: json["ticket_buyer_ids"] == null
        ? []
        : List<int>.from(json["ticket_buyer_ids"]!.map((x) => x)),
    genre: json["genre"] == null ? null : Genre.fromJson(json["genre"]),
    artist: json["artist"] == null ? null : User.fromJson(json["artist"]),
    tickets: json["tickets"] == null
        ? []
        : List<Ticket>.from(json["tickets"]!.map((x) => Ticket.fromJson(x))),
    activities: json["activity"] == null
        ? json["logs"] == null
              ? []
              : List<Activity>.from(
                  json["logs"]!.map((x) => Activity.fromJson(x)),
                )
        : List<Activity>.from(
            json["activity"]!.map((x) => Activity.fromJson(x)),
          ),
    guests: json["guests"] is List
        ? (json["guests"] as List)
              .whereType<Map>()
              .map((x) => EventGuest.fromJson(x))
              .toList()
        : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "artist_id": artistId,
    "name": name,
    "cover_image": coverImage,
    "ticket_price": ticketPrice,
    "start_date_time": startDateTime?.toIso8601String(),
    "end_date_time": endDateTime?.toIso8601String(),
    "genre_id": genreId,
    "description": description,
    "video_reel": videoReel,
    "is_private": isPrivate,
    "has_live_chat": hasLiveChat,
    "capacity_limit": capacityLimit,
    "status": status,
    "link": link,
    "joined_users_count": joinedUsersCount,
    "likes_count": likesCount,
    "stream_key": streamKey,
    "stream_url": streamUrl,
    "mux_live_playback_id": muxLivePlaybackId,
    "live_mode": liveMode,
    "replay_expires_at": replayExpiresAt?.toIso8601String(),
    "replay_expired": replayExpired,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "ticket_buyer_ids": ticketBuyerIds == null
        ? []
        : List<dynamic>.from(ticketBuyerIds!.map((x) => x)),
    "genre": genre?.toJson(),
    "artist": artist?.toJson(),
    "tickets": tickets == null
        ? []
        : List<dynamic>.from(tickets!.map((x) => x.toJson())),
    "activity": activities == null 
        ? []
        : List<dynamic>.from(activities!.map((x) => x.toJson())),
    "guests": guests == null
        ? null
        : List<dynamic>.from(guests!.map((x) => x.toJson())),
  };
}

/// Artiste invité sur un concert, avec sa part (en % de la part de l'artiste
/// principal). `sharePct` vaut 0 tant que l'artiste principal ne l'a pas
/// renseignée (objets publics des events : seul user_id / nom / photo).
class EventGuest {
  final int userId;
  final String artistName;
  final String? fullName;
  final String? profileImage;
  final int sharePct;

  const EventGuest({
    required this.userId,
    required this.artistName,
    this.fullName,
    this.profileImage,
    this.sharePct = 0,
  });

  /// Nom affiché : nom d'artiste, sinon nom complet, sinon « #id ».
  String get displayName {
    if (artistName.trim().isNotEmpty) return artistName;
    final full = (fullName ?? '').trim();
    if (full.isNotEmpty) return full;
    return '#$userId';
  }

  EventGuest copyWith({
    int? userId,
    String? artistName,
    String? fullName,
    String? profileImage,
    int? sharePct,
  }) => EventGuest(
    userId: userId ?? this.userId,
    artistName: artistName ?? this.artistName,
    fullName: fullName ?? this.fullName,
    profileImage: profileImage ?? this.profileImage,
    sharePct: sharePct ?? this.sharePct,
  );

  /// Accepte les objets de `/artists/search` (id) comme ceux de
  /// `/events/:id/guests` (user_id).
  factory EventGuest.fromJson(Map json) {
    final rawId = json["user_id"] ?? json["id"];
    final rawPct = json["share_pct"];
    return EventGuest(
      userId: rawId is int ? rawId : int.tryParse('${rawId ?? ''}') ?? 0,
      artistName: (json["artist_name"] ?? '').toString(),
      fullName: json["full_name"]?.toString(),
      profileImage: json["profile_image"]?.toString(),
      sharePct: rawPct is int
          ? rawPct
          : (double.tryParse('${rawPct ?? ''}') ?? 0).round(),
    );
  }

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "artist_name": artistName,
    "full_name": fullName,
    "profile_image": profileImage,
    "share_pct": sharePct,
  };

  /// Format attendu par POST /events et PUT /events/:id/guests.
  Map<String, dynamic> toShareJson() => {
    "user_id": userId,
    "share_pct": sharePct,
  };
}

class Ticket {
  final int? id;
  final int? eventId;
  final int? userId;
  final String? pricePaid;
  final String? receiptNumber;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Ticket({
    this.id,
    this.eventId,
    this.userId,
    this.pricePaid,
    this.receiptNumber,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  Ticket copyWith({
    int? id,
    int? eventId,
    int? userId,
    String? pricePaid,
    String? receiptNumber,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Ticket(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    userId: userId ?? this.userId,
    pricePaid: pricePaid ?? this.pricePaid,
    receiptNumber: receiptNumber ?? this.receiptNumber,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json["id"],
    eventId: json["event_id"],
    userId: json["user_id"],
    pricePaid: json["price_paid"],
    receiptNumber: json["receipt_number"],
    status: json["status"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "event_id": eventId,
    "user_id": userId,
    "price_paid": pricePaid,
    "receipt_number": receiptNumber,
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

class Activity {
  final int? id;
  final int? userId;
  final int? eventId;
  final String? type;
  final String? description;
  final dynamic points;
  final String? gift;
  final User? userInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Activity({
    this.id,
    this.userId,
    this.eventId,
    this.type,
    this.description,
    this.points,
    this.gift,
    this.userInfo,
    this.createdAt,
    this.updatedAt,
  });

  Activity copyWith({
    int? id,
    int? userId,
    int? eventId,
    String? type,
    String? description,
    dynamic points,
    dynamic gift,
    User? userInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Activity(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    eventId: eventId ?? this.eventId,
    type: type ?? this.type,
    description: description ?? this.description,
    points: points ?? this.points,
    gift: gift ?? this.gift,
    userInfo: userInfo ?? this.userInfo,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json["id"],
    userId: json["user_id"],
    eventId: json["event_id"],
    type: json["type"],
    description: json["description"],
    points: json["points"],
    gift: json["gift"],
    userInfo: json["user_info"] == null
        ? null
        : User.fromJson(json["user_info"]),
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "event_id": eventId,
    "type": type,
    "description": description,
    "points": points,
    "gift": gift,
    "user_info": userInfo?.toJson(),
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

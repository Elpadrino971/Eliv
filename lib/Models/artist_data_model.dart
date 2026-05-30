// To parse this JSON data, do
//
//     final artistDataModel = artistDataModelFromJson(jsonString);

import 'dart:convert';

ArtistDataModel artistDataModelFromJson(String str) =>
    ArtistDataModel.fromJson(json.decode(str));

String artistDataModelToJson(ArtistDataModel data) =>
    json.encode(data.toJson());

class ArtistDataModel {
  final String? status;
  final Data? data;

  ArtistDataModel({this.status, this.data});

  ArtistDataModel copyWith({String? status, Data? data}) =>
      ArtistDataModel(status: status ?? this.status, data: data ?? this.data);

  factory ArtistDataModel.fromJson(Map<String, dynamic> json) =>
      ArtistDataModel(
        status: json["status"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {"status": status, "data": data?.toJson()};
}

class Data {
  final String? artistName;
  final int? totalTicketsSold;
  final String? currentWallet;
  final int? totalRevenue;
  final int? followersCount;
  final int? eventCount;
  final int? upcomingEventsCount;
  final int? pastEventsCount;
  final int? averageRating;
  final List<HourlyVelocity>? hourlyVelocity;

  Data({
    this.artistName,
    this.totalTicketsSold,
    this.currentWallet,
    this.totalRevenue,
    this.followersCount,
    this.eventCount,
    this.upcomingEventsCount,
    this.pastEventsCount,
    this.averageRating,
    this.hourlyVelocity,
  });

  Data copyWith({
    String? artistName,
    int? totalTicketsSold,
    String? currentWallet,
    int? totalRevenue,
    int? followersCount,
    int? eventCount,
    int? upcomingEventsCount,
    int? pastEventsCount,
    int? averageRating,
    List<HourlyVelocity>? hourlyVelocity,
  }) => Data(
    artistName: artistName ?? this.artistName,
    totalTicketsSold: totalTicketsSold ?? this.totalTicketsSold,
    currentWallet: currentWallet ?? this.currentWallet,
    totalRevenue: totalRevenue ?? this.totalRevenue,
    followersCount: followersCount ?? this.followersCount,
    eventCount: eventCount ?? this.eventCount,
    upcomingEventsCount: upcomingEventsCount ?? this.upcomingEventsCount,
    pastEventsCount: pastEventsCount ?? this.pastEventsCount,
    averageRating: averageRating ?? this.averageRating,
    hourlyVelocity: hourlyVelocity ?? this.hourlyVelocity,
  );

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    artistName: json["artist_name"],
    totalTicketsSold: json["total_tickets_sold"],
    currentWallet: json["current_wallet"],
    totalRevenue: json["total_revenue"],
    followersCount: json["followers_count"],
    eventCount: json["event_count"],
    upcomingEventsCount: json["upcoming_events_count"],
    pastEventsCount: json["past_events_count"],
    averageRating: json["average_rating"],
    hourlyVelocity: json["hourly_velocity"] == null
        ? []
        : List<HourlyVelocity>.from(
            json["hourly_velocity"]!.map((x) => HourlyVelocity.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    "artist_name": artistName,
    "total_tickets_sold": totalTicketsSold,
    "current_wallet": currentWallet,
    "total_revenue": totalRevenue,
    "followers_count": followersCount,
    "event_count": eventCount,
    "upcoming_events_count": upcomingEventsCount,
    "past_events_count": pastEventsCount,
    "average_rating": averageRating,
    "hourly_velocity": hourlyVelocity == null
        ? []
        : List<dynamic>.from(hourlyVelocity!.map((x) => x.toJson())),
  };
}

class HourlyVelocity {
  final String? hour;
  final int? ticketsSold;

  HourlyVelocity({this.hour, this.ticketsSold});

  HourlyVelocity copyWith({String? hour, int? ticketsSold}) => HourlyVelocity(
    hour: hour ?? this.hour,
    ticketsSold: ticketsSold ?? this.ticketsSold,
  );

  factory HourlyVelocity.fromJson(Map<String, dynamic> json) =>
      HourlyVelocity(hour: json["hour"], ticketsSold: json["tickets_sold"]);

  Map<String, dynamic> toJson() => {"hour": hour, "tickets_sold": ticketsSold};
}

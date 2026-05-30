// To parse this JSON data, do
//
//     final followModel = followModelFromJson(jsonString);

import 'dart:convert';

FollowModel followModelFromJson(String str, [String? key]) =>
    FollowModel.fromJson(json.decode(str), key);

String followModelToJson(FollowModel data) => json.encode(data.toJson());

class FollowModel {
  final String? status;
  final String? message;
  final Data? data;

  FollowModel({this.status, this.message, this.data});

  FollowModel copyWith({String? status, String? message, Data? data}) =>
      FollowModel(
        status: status ?? this.status,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory FollowModel.fromJson(Map<String, dynamic> json, [String? key]) =>
      FollowModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"], key),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

class Data {
  final int? followersCount;
  final List<Follower>? followers;

  Data({this.followersCount, this.followers});

  Data copyWith({int? followersCount, List<Follower>? followers}) => Data(
    followersCount: followersCount ?? this.followersCount,
    followers: followers ?? this.followers,
  );

  factory Data.fromJson(Map<String, dynamic> json, [String? key]) => Data(
    followersCount: json["followers_count"],
    followers: json[key ?? "followers"] == null
        ? []
        : List<Follower>.from(
            json[key ?? "followers"]!.map((x) => Follower.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    "followers_count": followersCount,
    "followers": followers == null
        ? []
        : List<dynamic>.from(followers!.map((x) => x.toJson())),
  };
}

class Follower {
  final int? id;
  final String? fullName;
  final String? profileImage;
  final String? email;
  final Pivot? pivot;

  Follower({this.id, this.fullName, this.profileImage, this.email, this.pivot});

  Follower copyWith({
    int? id,
    String? fullName,
    String? profileImage,
    String? email,
    Pivot? pivot,
  }) => Follower(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    profileImage: profileImage ?? this.profileImage,
    email: email ?? this.email,
    pivot: pivot ?? this.pivot,
  );

  factory Follower.fromJson(Map<String, dynamic> json) => Follower(
    id: json["id"],
    fullName: json["full_name"],
    profileImage: json["profile_image"],
    email: json["email"],
    pivot: json["pivot"] == null ? null : Pivot.fromJson(json["pivot"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "profile_image": profileImage,
    "email": email,
    "pivot": pivot?.toJson(),
  };
}

class Pivot {
  final int? artistId;
  final int? followerId;

  Pivot({this.artistId, this.followerId});

  Pivot copyWith({int? artistId, int? followerId}) => Pivot(
    artistId: artistId ?? this.artistId,
    followerId: followerId ?? this.followerId,
  );

  factory Pivot.fromJson(Map<String, dynamic> json) =>
      Pivot(artistId: json["artist_id"], followerId: json["follower_id"]);

  Map<String, dynamic> toJson() => {
    "artist_id": artistId,
    "follower_id": followerId,
  };
}

// To parse this JSON data, do
//
//     final userModel = userModelFromJson(jsonString);

import 'dart:convert';

import 'package:artist/Models/genre_model.dart';
import 'package:artist/Models/susbcription_model.dart';

UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));

String userModelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  final String? status;
  final String? message;
  final String? token;
  final User? user;

  UserModel({this.status, this.message, this.user, this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    status: json["status"]?.toString(),
    message: json["message"],
    token: json["token"],
    user: json["data"] == null ? null : User.fromJson(json["data"]),
  );

  UserModel copyWith({
    String? status,
    String? message,
    String? token,
    User? user,
  }) {
    return UserModel(
      status: status ?? this.status,
      message: message ?? this.message,
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "token": token,
    "data": user?.toJson(),
  };
}

class User {
  final int? id;
  final String? email;
  final String? password;
  final String? phoneNumber;
  final String? otpCode;
  final String? role;
  final String? fullName;
  final String? artistName;
  final String? profileImage;
  final String? dob;
  final String? bio;
  final String? address;
  final String? latitude;
  final String? longitude;
  final String? registrationType;
  final String? experience;
  final String? status;
  final String? wallet;
  final String? artistBio;
  final String? artistProfile;
  final String? points;
  final int? isVerified;
  final bool? isFeatured;
  final bool? isArtist;
  final List<Genre>? genres;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<UserSubscription>? userSubscription;

  User({
    this.id,
    this.email,
    this.password,
    this.phoneNumber,
    this.otpCode,
    this.role,
    this.fullName,
    this.artistName,
    this.profileImage,
    this.dob,
    this.bio,
    this.address,
    this.latitude,
    this.longitude,
    this.registrationType,
    this.experience,
    this.status,
    this.wallet,
    this.artistBio,
    this.artistProfile,
    this.points,
    this.isVerified,
    this.isFeatured,
    this.isArtist,
    this.genres,
    this.createdAt,
    this.updatedAt,
    this.userSubscription,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    email: json["email"],
    password: json["password"],
    phoneNumber: json["phone_number"],
    otpCode: json["otp_code"],
    role: json["role"],
    fullName: json["full_name"],
    artistName: json["artist_name"],
    profileImage: json["profile_image"],
    dob: json["dob"],
    bio: json["bio"],
    address: json["address"],
    latitude: json["latitude"],
    longitude: json["longitude"],
    registrationType: json["registration_type"],
    experience: json["experience"],
    status: json["status"],
    wallet: json["wallet"],
    artistBio: json["artist_bio"],
    artistProfile: json["artist_profile"],
    points: json["points"]?.toString(),
    isVerified: json["is_verified"],
    isFeatured: json["is_featured"],
    userSubscription: json["user_subscription"] == null
        ? []
        : List<UserSubscription>.from(
            json["user_subscription"]!.map((x) => UserSubscription.fromJson(x)),
          ),
    isArtist: json["is_artist"],
    genres: json["genres"] == null
        ? []
        : List<Genre>.from(json["genres"].map((x) => Genre.fromJson(x))),
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  User copyWith({User? user}) {
    return User(
      id: user?.id ?? id,
      email: user?.email ?? email,
      password: user?.password ?? password,
      phoneNumber: user?.phoneNumber ?? phoneNumber,
      otpCode: user?.otpCode ?? otpCode,
      role: user?.role ?? role,
      fullName: user?.fullName ?? fullName,
      artistName: user?.artistName ?? artistName,
      profileImage: user?.profileImage ?? profileImage,
      dob: user?.dob ?? dob,
      bio: user?.bio ?? bio,
      address: user?.address ?? address,
      latitude: user?.latitude ?? latitude,
      longitude: user?.longitude ?? longitude,
      registrationType: user?.registrationType ?? registrationType,
      experience: user?.experience ?? experience,
      status: user?.status ?? status,
      wallet: user?.wallet ?? wallet,
      artistBio: user?.artistBio ?? artistBio,
      artistProfile: user?.artistProfile ?? artistProfile,
      points: user?.points ?? points,
      isVerified: user?.isVerified ?? isVerified,
      isFeatured: user?.isFeatured ?? isFeatured,
      isArtist: user?.isArtist ?? isArtist,
      genres: user?.genres ?? genres,
      createdAt: user?.createdAt ?? createdAt,
      updatedAt: user?.updatedAt ?? updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "password": password,
    "phone_number": phoneNumber,
    "otp_code": otpCode,
    "role": role,
    "full_name": fullName,
    "artist_name": artistName,
    "profile_image": profileImage,
    "dob": dob,
    "points": points,
    "bio": bio,
    "address": address,
    "latitude": latitude,
    "longitude": longitude,
    "registration_type": registrationType,
    "experience": experience,
    "status": status,
    "wallet": wallet,
    "artist_bio": artistBio,
    "artist_profile": artistProfile,
    "is_verified": isVerified,
    "is_featured": isFeatured,
    "user_subscription": userSubscription == null
        ? []
        : List<dynamic>.from(userSubscription!.map((x) => x.toJson())),
    "is_artist": isArtist,
    "genres": genres == null
        ? []
        : List<dynamic>.from(genres!.map((x) => x.toJson())),
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

class UserSubscription {
  final int? id;
  final int? userId;
  final int? subscriptionsId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Subscription? subscription;

  UserSubscription({
    this.id,
    this.userId,
    this.subscriptionsId,
    this.startDate,
    this.endDate,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.subscription,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      UserSubscription(
        id: json["id"],
        userId: json["user_id"],
        subscriptionsId: json["subscriptions_id"],
        startDate: json["start_date"] == null
            ? null
            : DateTime.parse(json["start_date"]),
        endDate: json["end_date"] == null
            ? null
            : DateTime.parse(json["end_date"]),
        status: json["status"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        subscription: json["subscription"] == null
            ? null
            : Subscription.fromJson(json["subscription"]),
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "subscriptions_id": subscriptionsId,
    "start_date": startDate?.toIso8601String(),
    "end_date": endDate?.toIso8601String(),
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "subscription": subscription?.toJson(),
  };
}

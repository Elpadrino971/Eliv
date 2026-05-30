// To parse this JSON data, do
//
//     final supportModel = supportModelFromJson(jsonString);

import 'dart:convert';

import 'package:artist/Models/user_model.dart';

SupportModel supportModelFromJson(String str) =>
    SupportModel.fromJson(json.decode(str));

String supportModelToJson(SupportModel data) => json.encode(data.toJson());

class SupportModel {
  final String? status;
  final String? message;
  final int? count;
  final List<Support>? list;

  SupportModel({this.status, this.message, this.count, this.list});

  SupportModel copyWith({
    String? status,
    String? message,
    int? count,
    List<Support>? list,
  }) => SupportModel(
    status: status ?? this.status,
    message: message ?? this.message,
    count: count ?? this.count,
    list: list ?? this.list,
  );

  factory SupportModel.fromJson(Map<String, dynamic> json) => SupportModel(
    status: json["status"],
    message: json["message"],
    count: json["count"],
    list: json["list"] == null
        ? []
        : List<Support>.from(
            json["list"]!.map((x) => Support.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "count": count,
    "list": list == null
        ? []
        : List<dynamic>.from(list!.map((x) => x.toJson())),
  };
}

class Support {
  final int? id;
  final int? userId;
  final String? subject;
  final String? priority;
  final DateTime? resolvedOn;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? rating;
  final String? review;
  final User? userInfo;
  final List<MetaData>? metaData;

  Support({
    this.id,
    this.userId,
    this.subject,
    this.priority,
    this.resolvedOn,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.rating,
    this.review,
    this.userInfo,
    this.metaData,
  });

  Support copyWith({
    int? id,
    int? userId,
    String? subject,
    String? priority,
    DateTime? resolvedOn,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rating,
    String? review,
    User? userInfo,
    List<MetaData>? metaData,
  }) => Support(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    subject: subject ?? this.subject,
    priority: priority ?? this.priority,
    resolvedOn: resolvedOn ?? this.resolvedOn,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rating: rating ?? this.rating,
    review: review ?? this.review,
    userInfo: userInfo ?? this.userInfo,
    metaData: metaData ?? this.metaData,
  );

  factory Support.fromJson(Map<String, dynamic> json) => Support(
    id: json["id"],
    userId: json["user_id"],
    subject: json["subject"],
    priority: json["priority"],
    resolvedOn: json["resolved_on"] == null
        ? null
        : DateTime.parse(json["resolved_on"]),
    status: json["status"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    rating: json["rating"],
    review: json["review"],
    userInfo: json["user_info"] == null
        ? null
        : User.fromJson(json["user_info"]),
    metaData: json["meta_data"] == null
        ? []
        : List<MetaData>.from(
            json["meta_data"]!.map((x) => MetaData.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "subject": subject,
    "priority": priority,
    "resolved_on": resolvedOn?.toIso8601String(),
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "rating": rating,
    "review": review,
    "user_info": userInfo?.toJson(),
    "meta_data": metaData == null
        ? []
        : List<dynamic>.from(metaData!.map((x) => x.toJson())),
  };
}

class MetaData {
  final int? id;
  final int? supportTicketId;
  final int? userId;
  final String? role;
  final String? value;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MetaData({
    this.id,
    this.supportTicketId,
    this.userId,
    this.role,
    this.value,
    this.createdAt,
    this.updatedAt,
  });

  MetaData copyWith({
    int? id,
    int? supportTicketId,
    int? userId,
    String? role,
    String? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MetaData(
    id: id ?? this.id,
    supportTicketId: supportTicketId ?? this.supportTicketId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    value: value ?? this.value,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory MetaData.fromJson(Map<String, dynamic> json) => MetaData(
    id: json["id"],
    supportTicketId: json["support_ticket_id"],
    userId: json["user_id"],
    role: json["role"],
    value: json["value"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "support_ticket_id": supportTicketId,
    "user_id": userId,
    "role": role,
    "value": value,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

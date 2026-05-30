// To parse this JSON data, do
//
//     final managementModel = managementModelFromJson(jsonString);

import 'dart:convert';

ManagementModel managementModelFromJson(String str) =>
    ManagementModel.fromJson(json.decode(str));

String managementModelToJson(ManagementModel data) =>
    json.encode(data.toJson());

class ManagementModel {
  final bool? status;
  final String? message;
  final int? count;
  final List<Management>? list;

  ManagementModel({this.status, this.message, this.count, this.list});

  ManagementModel copyWith({
    bool? status,
    String? message,
    int? count,
    List<Management>? list,
  }) => ManagementModel(
    status: status ?? this.status,
    message: message ?? this.message,
    count: count ?? this.count,
    list: list ?? this.list,
  );

  factory ManagementModel.fromJson(Map<String, dynamic> json) =>
      ManagementModel(
        status: json["status"],
        message: json["message"],
        count: json["count"],
        list: json["list"] == null
            ? []
            : List<Management>.from(
                json["list"]!.map((x) => Management.fromJson(x)),
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

class Management {
  final int? id;
  final dynamic parentId;
  final String? role;
  final String? name;
  final String? description;
  final dynamic image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Management({
    this.id,
    this.parentId,
    this.role,
    this.name,
    this.description,
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  Management copyWith({
    int? id,
    dynamic parentId,
    String? role,
    String? name,
    String? description,
    dynamic image,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Management(
    id: id ?? this.id,
    parentId: parentId ?? this.parentId,
    role: role ?? this.role,
    name: name ?? this.name,
    description: description ?? this.description,
    image: image ?? this.image,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Management.fromJson(Map<String, dynamic> json) => Management(
    id: json["id"],
    parentId: json["parent_id"],
    role: json["role"],
    name: json["name"],
    description: json["description"],
    image: json["image"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "parent_id": parentId,
    "role": role,
    "name": name,
    "description": description,
    "image": image,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

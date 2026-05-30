// To parse this JSON data, do
//
//     final packagesModel = packagesModelFromJson(jsonString);

import 'dart:convert';

PackagesModel packagesModelFromJson(String str) =>
    PackagesModel.fromJson(json.decode(str));

String packagesModelToJson(PackagesModel data) => json.encode(data.toJson());

class PackagesModel {
  final int? count;
  final List<Package>? list;

  PackagesModel({this.count, this.list});

  PackagesModel copyWith({int? count, List<Package>? list}) =>
      PackagesModel(count: count ?? this.count, list: list ?? this.list);

  factory PackagesModel.fromJson(Map<String, dynamic> json) => PackagesModel(
    count: json["count"],
    list: json["list"] == null
        ? []
        : List<Package>.from(json["list"]!.map((x) => Package.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "count": count,
    "list": list == null
        ? []
        : List<dynamic>.from(list!.map((x) => x.toJson())),
  };
}

class Package {
  final int? id;
  final String? title;
  final String? image;
  final String? points;
  final String? price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Package({
    this.id,
    this.title,
    this.image,
    this.points,
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  Package copyWith({
    int? id,
    String? title,
    String? image,
    String? points,
    String? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Package(
    id: id ?? this.id,
    title: title ?? this.title,
    image: image ?? this.image,
    points: points ?? this.points,
    price: price ?? this.price,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Package.fromJson(Map<String, dynamic> json) => Package(
    id: json["id"],
    title: json["title"],
    image: json["image"],
    points: json["points"],
    price: json["price"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "image": image,
    "points": points,
    "price": price,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

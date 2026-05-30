// To parse this JSON data, do
//
//     final giftModel = giftModelFromJson(jsonString);

import 'dart:convert';

GiftModel giftModelFromJson(String str) => GiftModel.fromJson(json.decode(str));

String giftModelToJson(GiftModel data) => json.encode(data.toJson());

class GiftModel {
  final String? status;
  final String? message;
  final int? count;
  final List<Datum>? data;

  GiftModel({this.status, this.message, this.count, this.data});

  GiftModel copyWith({
    String? status,
    String? message,
    int? count,
    List<Datum>? data,
  }) => GiftModel(
    status: status ?? this.status,
    message: message ?? this.message,
    count: count ?? this.count,
    data: data ?? this.data,
  );

  factory GiftModel.fromJson(Map<String, dynamic> json) => GiftModel(
    status: json["status"],
    message: json["message"],
    count: json["count"],
    data: json["data"] == null
        ? []
        : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "count": count,
    "data": data == null
        ? []
        : List<dynamic>.from(data!.map((x) => x.toJson())),
  };
}

class Datum {
  final int? id;
  final String? name;
  final String? image;
  final String? coins;
  final String? price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Datum({
    this.id,
    this.name,
    this.image,
    this.coins,
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  Datum copyWith({
    int? id,
    String? name,
    String? image,
    String? coins,
    String? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Datum(
    id: id ?? this.id,
    name: name ?? this.name,
    image: image ?? this.image,
    coins: coins ?? this.coins,
    price: price ?? this.price,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    name: json["name"],
    image: json["image"],
    coins: json["coins"],
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
    "name": name,
    "image": image,
    "coins": coins,
    "price": price,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

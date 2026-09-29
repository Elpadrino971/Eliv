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
  // Coût en points côté serveur (colonne `points` de la table gifts). Le
  // backend peut aussi renvoyer `coins` : on lit `coins` puis `points`.
  final String? points;
  final String? price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Datum({
    this.id,
    this.name,
    this.image,
    this.coins,
    this.points,
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  /// Coût du cadeau pour le fan (pièces / points), 0 si inconnu.
  /// Tolère une valeur décimale envoyée en texte (« 10.0 »).
  int get cost {
    final raw = (coins != null && coins!.trim().isNotEmpty)
        ? coins!.trim()
        : (points ?? '0').trim();
    return int.tryParse(raw) ?? double.tryParse(raw)?.round() ?? 0;
  }

  Datum copyWith({
    int? id,
    String? name,
    String? image,
    String? coins,
    String? points,
    String? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Datum(
    id: id ?? this.id,
    name: name ?? this.name,
    image: image ?? this.image,
    coins: coins ?? this.coins,
    points: points ?? this.points,
    price: price ?? this.price,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"] is int ? json["id"] : int.tryParse('${json["id"]}'),
    name: json["name"]?.toString(),
    image: json["image"]?.toString(),
    // Le serveur peut envoyer des nombres ou du texte : on normalise en texte.
    coins: json["coins"]?.toString(),
    points: json["points"]?.toString(),
    price: json["price"]?.toString(),
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
    "points": points,
    "price": price,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

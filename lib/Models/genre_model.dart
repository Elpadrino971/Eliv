// To parse this JSON data, do
//
//     final genreModel = genreModelFromJson(jsonString);

import 'dart:convert';

GenreModel genreModelFromJson(String str) =>
    GenreModel.fromJson(json.decode(str));

String genreModelToJson(GenreModel data) => json.encode(data.toJson());

class GenreModel {
  final String? status;
  final List<Genre>? genre;

  GenreModel({this.status, this.genre});

  factory GenreModel.fromJson(Map<String, dynamic> json) => GenreModel(
    status: json["status"],
    genre: json["data"] == null
        ? []
        : List<Genre>.from(json["data"]!.map((x) => Genre.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "data": genre == null
        ? []
        : List<dynamic>.from(genre!.map((x) => x.toJson())),
  };
}

class Genre {
  final int? id;
  final String? genre;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Genre({this.id, this.genre, this.createdAt, this.updatedAt});

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: json["id"],
    genre: json["name"] ?? json["genre"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );
  Genre copyWith({
    int? id,
    String? genre,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Genre(
    id: id ?? this.id,
    genre: genre ?? this.genre,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Map<String, dynamic> toJson() => {
    "id": id,
    "genre": genre,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

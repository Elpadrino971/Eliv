// To parse this JSON data, do
//
//     final abusiveWordsModel = abusiveWordsModelFromJson(jsonString);

import 'dart:convert';

AbusiveWordsModel abusiveWordsModelFromJson(String str) =>
    AbusiveWordsModel.fromJson(json.decode(str));

String abusiveWordsModelToJson(AbusiveWordsModel data) =>
    json.encode(data.toJson());

class AbusiveWordsModel {
  final String? status;
  final String? message;
  final int? count;
  final List<Words>? data;

  AbusiveWordsModel({this.status, this.message, this.count, this.data});

  AbusiveWordsModel copyWith({
    String? status,
    String? message,
    int? count,
    List<Words>? data,
  }) => AbusiveWordsModel(
    status: status ?? this.status,
    message: message ?? this.message,
    count: count ?? this.count,
    data: data ?? this.data,
  );

  factory AbusiveWordsModel.fromJson(Map<String, dynamic> json) =>
      AbusiveWordsModel(
        status: json["status"],
        message: json["message"],
        count: json["count"],
        data: json["data"] == null
            ? []
            : List<Words>.from(json["data"]!.map((x) => Words.fromJson(x))),
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

class Words {
  final int? id;
  final String? word;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Words({this.id, this.word, this.createdAt, this.updatedAt});

  Words copyWith({
    int? id,
    String? word,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Words(
    id: id ?? this.id,
    word: word ?? this.word,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Words.fromJson(Map<String, dynamic> json) => Words(
    id: json["id"],
    word: json["word"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "word": word,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

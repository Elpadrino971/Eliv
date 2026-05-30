// To parse this JSON data, do
//
//     final banksModel = banksModelFromJson(jsonString);

import 'dart:convert';

BanksModel banksModelFromJson(String str) =>
    BanksModel.fromJson(json.decode(str));

String banksModelToJson(BanksModel data) => json.encode(data.toJson());

class BanksModel {
  final bool? status;
  final String? message;
  final int? count;
  final List<ListElement>? list;

  BanksModel({this.status, this.message, this.count, this.list});

  BanksModel copyWith({
    bool? status,
    String? message,
    int? count,
    List<ListElement>? list,
  }) => BanksModel(
    status: status ?? this.status,
    message: message ?? this.message,
    count: count ?? this.count,
    list: list ?? this.list,
  );

  factory BanksModel.fromJson(Map<String, dynamic> json) => BanksModel(
    status: json["status"],
    message: json["message"],
    count: json["count"],
    list: json["list"] == null
        ? []
        : List<ListElement>.from(
            json["list"]!.map((x) => ListElement.fromJson(x)),
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

class ListElement {
  final int? id;
  final int? userId;
  final String? accountName;
  final String? bankName;
  final String? accountNumber;
  final String? swiftCode;
  final String? routingNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ListElement({
    this.id,
    this.userId,
    this.accountName,
    this.bankName,
    this.accountNumber,
    this.swiftCode,
    this.routingNumber,
    this.createdAt,
    this.updatedAt,
  });

  ListElement copyWith({
    int? id,
    int? userId,
    String? accountName,
    String? bankName,
    String? accountNumber,
    String? swiftCode,
    String? routingNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ListElement(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    accountName: accountName ?? this.accountName,
    bankName: bankName ?? this.bankName,
    accountNumber: accountNumber ?? this.accountNumber,
    swiftCode: swiftCode ?? this.swiftCode,
    routingNumber: routingNumber ?? this.routingNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ListElement.fromJson(Map<String, dynamic> json) => ListElement(
    id: json["id"],
    userId: json["user_id"],
    accountName: json["account_name"],
    bankName: json["bank_name"],
    accountNumber: json["account_number"],
    swiftCode: json["swift_code"],
    routingNumber: json["routing_number"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "account_name": accountName,
    "bank_name": bankName,
    "account_number": accountNumber,
    "swift_code": swiftCode,
    "routing_number": routingNumber,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

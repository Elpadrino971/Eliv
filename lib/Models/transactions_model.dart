// To parse this JSON data, do
//
//     final transactionsModel = transactionsModelFromJson(jsonString);

import 'dart:convert';

TransactionsModel transactionsModelFromJson(String str) =>
    TransactionsModel.fromJson(json.decode(str));

String transactionsModelToJson(TransactionsModel data) =>
    json.encode(data.toJson());

class TransactionsModel {
  final String? status;
  final String? message;
  final int? totalDebit;
  final int? totalCredit;
  final List<Transaction>? list;
  final int? count;

  TransactionsModel({
    this.status,
    this.message,
    this.totalDebit,
    this.totalCredit,
    this.list,
    this.count,
  });

  TransactionsModel copyWith({
    String? status,
    String? message,
    int? totalDebit,
    int? totalCredit,
    List<Transaction>? list,
    int? count,
  }) => TransactionsModel(
    status: status ?? this.status,
    message: message ?? this.message,
    totalDebit: totalDebit ?? this.totalDebit,
    totalCredit: totalCredit ?? this.totalCredit,
    list: list ?? this.list,
    count: count ?? this.count,
  );

  factory TransactionsModel.fromJson(Map<String, dynamic> json) =>
      TransactionsModel(
        status: json["status"],
        message: json["message"],
        totalDebit: json["total_debit"],
        totalCredit: json["total_credit"],
        list: json["list"] == null
            ? []
            : List<Transaction>.from(
                json["list"]!.map((x) => Transaction.fromJson(x)),
              ),
        count: json["count"],
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "total_debit": totalDebit,
    "total_credit": totalCredit,
    "list": list == null
        ? []
        : List<dynamic>.from(list!.map((x) => x.toJson())),
    "count": count,
  };
}

class Transaction {
  final int? id;
  final int? userId;
  final String? role;
  final String? type;
  final String? title;
  final String? description;
  final int? amount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Transaction({
    this.id,
    this.userId,
    this.role,
    this.type,
    this.title,
    this.description,
    this.amount,
    this.createdAt,
    this.updatedAt,
  });

  Transaction copyWith({
    int? id,
    int? userId,
    String? role,
    String? type,
    String? title,
    String? description,
    int? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transaction(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json["id"],
    userId: json["user_id"],
    role: json["role"],
    type: json["type"],
    title: json["title"],
    description: json["description"],
    amount: json["amount"],
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
    "role": role,
    "type": type,
    "title": title,
    "description": description,
    "amount": amount,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}

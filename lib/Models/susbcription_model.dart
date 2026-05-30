// To parse this JSON data, do
//
//     final subscriptionModel = subscriptionModelFromJson(jsonString);

import 'dart:convert';

SubscriptionModel subscriptionModelFromJson(String str) => SubscriptionModel.fromJson(json.decode(str));

String subscriptionModelToJson(SubscriptionModel data) => json.encode(data.toJson());

class SubscriptionModel {
    final int? count;
    final List<Subscription>? list;

    SubscriptionModel({
        this.count,
        this.list,
    });

    factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
        count: json["count"],
        list: json["list"] == null ? [] : List<Subscription>.from(json["list"]!.map((x) => Subscription.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "count": count,
        "list": list == null ? [] : List<dynamic>.from(list!.map((x) => x.toJson())),
    };
}

class Subscription {
    final int? id;
    final String? title;
    final String? priceType;
    final String? price;
    final String? commissionType;
    final String? commission;
    final String? artistsCount;
    final String? status;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    Subscription({
        this.id,
        this.title,
        this.priceType,
        this.price,
        this.commissionType,
        this.commission,
        this.artistsCount,
        this.status,
        this.createdAt,
        this.updatedAt,
    });

    factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json["id"],
        title: json["title"],
        priceType: json["price_type"],
        price: json["price"],
        commissionType: json["commission_type"],
        commission: json["commission"],
        artistsCount: json["artists_count"],
        status: json["status"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "price_type": priceType,
        "price": price,
        "commission_type": commissionType,
        "commission": commission,
        "artists_count": artistsCount,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}

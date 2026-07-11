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

    /// Founder launch fields (optional — null until the backend sends them, so
    /// the UI degrades gracefully). See docs/founder_plan_api_spec.md.
    final bool? isFounder;        // marks the limited Founder plan
    final int? seatsTotal;        // e.g. 200
    final int? seatsRemaining;    // live remaining seats
    final String? nextPrice;      // price of the next tier once this one fills
    final int? nextPriceInSeats;  // seats left before the price rises
    final String? publicPrice;    // anchor: public Growth price (e.g. 199)
    final String? badge;          // e.g. "BEST VALUE"
    final String? iapProductId;   // active IAP product (e.g. founder_149)

    /// Annual billing (2 months free = monthly price x10) — see toggle in
    /// AllSubscriptionScreen. Null si le plan n'a pas de version annuelle.
    final String? annualPrice;
    final List<String>? perks;    // bullet points affiches sous le prix annuel

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
        this.isFounder,
        this.seatsTotal,
        this.seatsRemaining,
        this.nextPrice,
        this.nextPriceInSeats,
        this.publicPrice,
        this.badge,
        this.iapProductId,
        this.annualPrice,
        this.perks,
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
        isFounder: json["is_founder"],
        seatsTotal: json["seats_total"],
        seatsRemaining: json["seats_remaining"],
        nextPrice: json["next_price"]?.toString(),
        nextPriceInSeats: json["next_price_in_seats"],
        publicPrice: json["public_price"]?.toString(),
        badge: json["badge"],
        iapProductId: json["iap_product_id"],
        annualPrice: json["annual_price"]?.toString(),
        perks: json["perks"] == null ? [] : List<String>.from(json["perks"].map((x) => x.toString())),
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
        "is_founder": isFounder,
        "seats_total": seatsTotal,
        "seats_remaining": seatsRemaining,
        "next_price": nextPrice,
        "next_price_in_seats": nextPriceInSeats,
        "public_price": publicPrice,
        "badge": badge,
        "iap_product_id": iapProductId,
        "annual_price": annualPrice,
        "perks": perks == null ? [] : List<dynamic>.from(perks!.map((x) => x)),
    };
}

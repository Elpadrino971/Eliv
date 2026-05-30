import 'dart:convert';
import 'dart:io';

import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/susbcription_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/artist_bottom_bar/artist_bottom_bar.dart';
import 'package:artist/services/api_services.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionController extends GetxController {
  final response = ApiResponse();
  Rx<SubscriptionModel> subscriptionModel = SubscriptionModel().obs;

  Future<void> getSubscriptions() async {
    response.typeSetter = "get";
    response.urlSetter = APIs.getSubscriptionsAPI;

    await response.hitAPI().then((value) {
      if (value.split(" ").first != "error") {
        subscriptionModel.value = subscriptionModelFromJson(value);
      } else {
        final data = jsonDecode(value.split("error ").last);

        myPrint(data['message']);
      }
    });
  }

  Future<void> buySubscription({
    required String subscriptionId,
    bool fromArtist = false,
  }) async {
    response.typeSetter = "post";
    response.urlSetter = APIs.buySubscriptionAPI;
    response.bodySetter = {
      "subscriptions_id": subscriptionId,
      "user_id": "${userModel.value.user?.id}",
    };

    myLoadingDialog();

    await response.hitAPI().then((value) {
      if (value.split(" ").first != "error") {
        userModel.value = userModelFromJson(value);
        Get.back();
        mySuccessDialog(
          title: 'Subscription Purchased Successfully!',
          subtitle: 'Now you can avail premium features',
          ontap: () {
            if (fromArtist) {
              Get.offAll(() => ArtistBottomBar());
            } else {
              Get.offAll(() => MyBottomBar(index: 4));
            }
          },
        );
      } else {
        final data = jsonDecode(value.split("error ").last);

        myWarningDialog(title: 'Error', subtitle: data['message']);
      }
    });
  }

  static Future init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    if (Platform.isAndroid) {
      // await Purchases.configure(PurchasesConfiguration(revenueCatGoogleApiKey));
    } else {
      await Purchases.configure(PurchasesConfiguration(revenueCatAppleApiKey));
    }
  }

  Future<List<Offering>> fetchOffers() async {
    try {
      final offerings = await Purchases.getOfferings();

      return offerings.all.values.toList();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      // await Purchases.purchasePackage(package);
      return true;
    } catch (e) {
      return false;
    }
  }
}

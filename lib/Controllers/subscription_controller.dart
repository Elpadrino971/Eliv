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
import 'package:url_launcher/url_launcher.dart';

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
          title: 'sub_purchased_title'.tr,
          subtitle: 'sub_purchased_sub'.tr,
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

        myWarningDialog(title: 'common_error'.tr, subtitle: data['message']);
      }
    });
  }

  /// MODELE HYBRIDE — chemin "web" (Stripe), sans commission Apple/Google.
  /// Ouvre le Stripe Checkout dans le navigateur, en passant l'utilisateur et le
  /// plan pour que le backend relie le paiement. C'est le chemin "marge" : on le
  /// propose EN PLUS de l'IAP (qui reste le chemin instantane).
  ///
  /// [SCAFFOLD] Tant que APIs.webSubscribeUrl est vide (backend pas encore pret),
  /// on informe l'utilisateur au lieu de planter.
  Future<void> subscribeOnWeb({String subscriptionId = ''}) async {
    if (APIs.webSubscribeUrl.isEmpty) {
      myWarningDialog(
        title: 'Bientôt disponible',
        subtitle:
            "Le paiement web arrive très bientôt. En attendant, tu peux t'abonner directement dans l'app.",
      );
      return;
    }

    final params = {'user_id': '${userModel.value.user?.id}'};
    if (subscriptionId.isNotEmpty) params['subscription_id'] = subscriptionId;
    final uri = Uri.parse(APIs.webSubscribeUrl).replace(queryParameters: params);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      myWarningDialog(
        title: 'Error',
        subtitle: "Impossible d'ouvrir la page de paiement. Réessaie.",
      );
    }
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

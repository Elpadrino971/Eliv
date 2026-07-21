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
  /// Demande une session Checkout au backend (liée au user + au palier +
  /// mensuel/annuel), puis l'ouvre dans le navigateur. C'est le chemin
  /// "marge" : on le propose EN PLUS de l'IAP (qui reste le chemin instantané).
  /// N'appeler ce chemin QUE sur Android (anti-steering Apple 3.1.1 : interdit
  /// de proposer un paiement externe dans l'app iOS).
  Future<void> subscribeOnWeb({
    required String subscriptionId,
    bool annual = false,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.subscriptionCheckoutAPI;
    response.bodySetter = {
      'subscriptions_id': subscriptionId,
      'annual': annual.toString(),
    };

    final value = await response.hitAPI();
    Get.back(); // ferme le loader

    if (value.split(' ').first == 'error') {
      final data = jsonDecode(value.split('error ').last);
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle:
            data['message'] ?? "Le paiement web n'est pas encore disponible.",
      );
      return;
    }

    final checkoutUrl = jsonDecode(value)['data']?['checkout_url'] as String?;
    if (checkoutUrl == null) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: "Impossible d'ouvrir la page de paiement. Réessaie.",
      );
      return;
    }

    final ok = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: "Impossible d'ouvrir la page de paiement. Réessaie.",
      );
    }
  }

  /// Aligne l'identité RevenueCat sur notre users.id (au lieu de l'ID anonyme
  /// généré par défaut) : c'est ce qui permet au webhook RevenueCat
  /// (routes/revenuecat.routes.js) de savoir QUEL utilisateur vient d'acheter
  /// et d'écrire dans user_subscriptions. À appeler après chaque connexion
  /// réussie et après restauration de session (voir spalash_screen.dart,
  /// auth_controller.dart). Non bloquant : une erreur ici ne doit jamais
  /// empêcher l'utilisateur d'utiliser l'app.
  static Future<void> syncIdentity(int userId) async {
    try {
      await Purchases.logIn(userId.toString());
    } catch (e) {
      myPrint('⚠️ RevenueCat logIn échoué (app continue): $e');
    }
  }

  /// À appeler à la déconnexion pour ne pas laisser l'identité RevenueCat
  /// d'un utilisateur "collée" au prochain qui se connecte sur l'appareil.
  static Future<void> clearIdentity() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      myPrint('⚠️ RevenueCat logOut échoué (app continue): $e');
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

  /// Achète un pack de POINTS via son identifiant produit RevenueCat/App Store
  /// (recharge du portefeuille, conforme Apple). Cherche le package
  /// correspondant dans les offerings, l'achète, et laisse le webhook
  /// RevenueCat créditer les points côté serveur (source de vérité). Retourne
  /// false si le produit n'est pas trouvé (pas encore configuré dans RevenueCat
  /// / App Store Connect) ou si l'achat échoue/est annulé.
  Future<bool> purchasePointPack(String productId) async {
    if (productId.isEmpty) return false;
    try {
      final offerings = await Purchases.getOfferings();
      for (final offering in offerings.all.values) {
        for (final pack in offering.availablePackages) {
          if (pack.storeProduct.identifier == productId) {
            await Purchases.purchase(PurchaseParams.package(pack));
            return true;
          }
        }
      }
      myPrint('purchasePointPack: produit "$productId" introuvable dans les offerings RevenueCat');
      return false;
    } catch (e) {
      myPrint('purchasePointPack: $e');
      return false;
    }
  }
}

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
      await Purchases.configure(PurchasesConfiguration(revenueCatGoogleApiKey));
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

  /// Achète un produit IAP par son identifiant (App Store / Play), via son
  /// package dans les offerings RevenueCat. Utilisé pour les PACKS DE POINTS
  /// (recharge) ET les BILLETS de concert (achat direct). Conforme Apple.
  /// Le webhook RevenueCat notifie ensuite le backend (crédit points / ticket).
  /// Retourne false si le produit est introuvable dans les offerings (pas
  /// encore configuré) ou si l'achat échoue/est annulé.
  Future<bool> purchaseByProductId(String productId) async {
    if (productId.isEmpty) return false;
    try {
      // 1. Si le produit est dans un offering (ex. abonnements artistes),
      //    on l'achète via son package. ISOLÉ dans son propre try/catch : si
      //    les offerings sont mal configurés (produits d'abonnement non dispo
      //    sur l'App Store), getOfferings() lève une CONFIGURATION_ERROR — elle
      //    ne doit PAS bloquer l'achat direct des consommables (billets / packs
      //    de points) qui, lui, n'a pas besoin des offerings (étape 2).
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
      } catch (e) {
        myPrint('purchaseByProductId: offerings indisponibles ($e) -> fallback getProducts');
      }
      // 2. Sinon (consommables : billets, packs de points), on récupère le
      //    produit DIRECTEMENT par son ID -> pas besoin de le mettre dans un
      //    offering RevenueCat. Le webhook notifie ensuite le backend.
      final products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isNotEmpty) {
        await Purchases.purchase(PurchaseParams.storeProduct(products.first));
        return true;
      }
      myPrint('purchaseByProductId: produit "$productId" introuvable (App Store)');
      return false;
    } catch (e) {
      myPrint('purchaseByProductId: $e');
      return false;
    }
  }

  /// Alias historique (packs de points).
  Future<bool> purchasePointPack(String productId) =>
      purchaseByProductId(productId);

  /// Achète un ABONNEMENT par son identifiant produit App Store (ex. annuel
  /// vybzz_199_1y), via getProducts en catégorie subscription -> pas besoin
  /// qu'il soit dans un offering RevenueCat. Utilisé pour l'annuel ; le mensuel
  /// continue de passer par les offerings (fetchOffers). Conforme Apple IAP.
  /// Retourne false si le produit est introuvable (pas encore approuvé/
  /// propagé sur l'App Store) ou si l'achat échoue/est annulé.
  Future<bool> purchaseSubscriptionByProductId(String productId) async {
    if (productId.isEmpty) return false;
    try {
      final products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.subscription,
      );
      if (products.isNotEmpty) {
        await Purchases.purchase(PurchaseParams.storeProduct(products.first));
        return true;
      }
      myPrint(
        'purchaseSubscriptionByProductId: produit "$productId" introuvable (App Store)',
      );
      return false;
    } catch (e) {
      myPrint('purchaseSubscriptionByProductId: $e');
      return false;
    }
  }

  /// Achète un ABONNEMENT sur ANDROID. Sur Google Play, les 4 paliers sont des
  /// « base plans » d'un même produit d'abonnement (`vybzzz`) — leurs IDs
  /// (`vybzzz:starter-plan`, `vybzzz:elite-plan`, …) ne correspondent PAS aux
  /// IDs App Store (`vybzz_99_1m`). On ne peut donc pas réutiliser l'ID iOS ici.
  /// On sélectionne le bon palier par mot-clé (founder/starter/growth/elite),
  /// d'abord via les offerings RevenueCat (mapping le plus propre), sinon en
  /// interrogeant directement le produit d'abonnement Play et ses base plans.
  /// [tierOrTitle] = le titre du palier (ex. "Founder 79", "Growth").
  Future<bool> purchaseAndroidSubscription(String tierOrTitle) async {
    const tiers = ['founder', 'starter', 'growth', 'elite'];
    final key = tierOrTitle.toLowerCase();
    final tier = tiers.firstWhere((t) => key.contains(t), orElse: () => '');
    if (tier.isEmpty) {
      myPrint('purchaseAndroidSubscription: palier introuvable dans "$tierOrTitle"');
      return false;
    }
    try {
      // 1) Via les offerings RevenueCat (si configurés) : on cherche le package
      //    dont le produit/base plan contient le mot-clé du palier.
      try {
        final offerings = await Purchases.getOfferings();
        for (final offering in offerings.all.values) {
          for (final pack in offering.availablePackages) {
            final hay =
                '${pack.identifier} ${pack.storeProduct.identifier} ${pack.storeProduct.title}'
                    .toLowerCase();
            if (hay.contains(tier)) {
              await Purchases.purchase(PurchaseParams.package(pack));
              return true;
            }
          }
        }
      } catch (e) {
        myPrint('purchaseAndroidSubscription: offerings indisponibles ($e) -> fallback produit direct');
      }
      // 2) Repli : produit d'abonnement Play direct + ses base plans.
      final products = await Purchases.getProducts(
        ['vybzzz'],
        productCategory: ProductCategory.subscription,
      );
      for (final p in products) {
        if (p.identifier.toLowerCase().contains(tier)) {
          await Purchases.purchase(PurchaseParams.storeProduct(p));
          return true;
        }
      }
      myPrint('purchaseAndroidSubscription: aucun base plan pour "$tier"');
      return false;
    } catch (e) {
      myPrint('purchaseAndroidSubscription: $e');
      return false;
    }
  }
}

import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/global.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Packs de points réellement achetables sur le store de l'appareil.
///
/// Le serveur liste les packs, mais un pack n'est achetable que si son produit
/// existe (et est validé) sur l'App Store / Play Store. Sans cette vérification
/// on affichait « Recharger » vers des packs qui répondaient « introuvable » :
/// une fonction qui ne mène nulle part, motif de refus Apple (2.1). Tant qu'aucun
/// pack n'est disponible, la recharge et les cadeaux sans solde sont masqués ;
/// ils réapparaissent seuls dès que les produits sont en ligne, sans nouvelle
/// version de l'application.
final RxSet<String> purchasablePointPacks = <String>{}.obs;

Future<void>? _pending;

Future<void> refreshPurchasablePointPacks() =>
    _pending ??= _refresh().whenComplete(() => _pending = null);

Future<void> _refresh() async {
  try {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    if (auth == null) return;
    if ((auth.packages.value.list ?? []).isEmpty) await auth.getPackages();
    final ids = (auth.packages.value.list ?? [])
        .map((p) => (p.revenuecatProductId ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      purchasablePointPacks.clear();
      return;
    }
    final products = await Purchases.getProducts(
      ids,
      productCategory: ProductCategory.nonSubscription,
    );
    purchasablePointPacks
      ..clear()
      ..addAll(products.map((p) => p.identifier));
  } catch (e) {
    myPrint('refreshPurchasablePointPacks: $e');
  }
}

/// Vrai si au moins un pack de points peut être acheté sur ce store.
bool get canTopUpPoints => purchasablePointPacks.isNotEmpty;

/// Solde de points du compte connecté.
int get currentPointsBalance {
  final raw = (userModel.value.user?.points ?? '0').trim();
  return int.tryParse(raw) ?? double.tryParse(raw)?.round() ?? 0;
}

/// Le bouton cadeau n'a de sens que si le fan peut en offrir un : il a déjà
/// des points, ou il peut en acheter.
bool get canSendGifts => canTopUpPoints || currentPointsBalance > 0;

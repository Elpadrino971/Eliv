// import 'dart:io'; // plus utilise depuis le retrait de la banniere boutique

// Ecran de boutique de points : conserve pour reactivation future.
// import 'package:artist/BottomBar/screens/profile/points_store.dart';
import 'package:artist/BottomBar/screens/profile/topup_history.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_withdraw.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserWallet extends StatefulWidget {
  const UserWallet({super.key});

  @override
  State<UserWallet> createState() => _UserWalletState();
}

class _UserWalletState extends State<UserWallet> {
  final authController = Get.find<AuthController>();

  Future<void> myInitMethod() async {
    await authController.getPackages();
  }

  @override
  void initState() {
    myInitMethod();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? darkmodeColor : whiteColor,
      appBar: MyAppbar(title: 'Wallet'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  boxShadow: [
                    BoxShadow(
                      color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: whiteColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          size: 20,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'wallet_arena_points'.tr,
                          style: TextStyle(
                            color: whiteColor.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            fontSize: 12,
                          ),
                        ),
                        height(0.01),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Obx(
                              () => Text(
                                userModel.value.user?.points ?? '0',
                                style: TextStyle(
                                  color: whiteColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 44,
                                ),
                              ),
                            ),
                            width(0.02),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'PTS',
                                style: TextStyle(
                                  color: whiteColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        height(0.01),
                        MyButton(
                          label: 'points_withdraw'.tr,
                          onTap: () {
                            Get.to(() => ArtistWithdraw());
                          },
                          buttonColor: whiteColor,
                          labelColor: Get.isDarkMode
                              ? goldPrimary
                              : mainThemeColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              height(0.03),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'points_top_up'.tr,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() => const TopupHistory()),
                    child: Text(
                      'common_view_history'.tr,
                      style: TextStyle(
                        color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              height(0.02),

              // Grid
              Obx(() {
                final packages = authController.packages.value.list ?? [];
                if (packages.isEmpty) {
                  return Center(child: Text('empty_no_packages'.tr));
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: packages.length > 4 ? 4 : packages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final bundle = packages[index];
                    // Badges marketing selon le pack (cf. tarifs optimisés).
                    String? badge;
                    final pts = bundle.points ?? '';
                    if (pts == '1100') {
                      badge = 'Populaire';
                    } else if (pts == '6500') {
                      badge = 'Meilleure valeur';
                    }
                    return PointsCard(
                      badge: badge,
                      onTap: () async {
                        final productId = bundle.revenuecatProductId ?? '';
                        if (productId.isEmpty) {
                          myWarningDialog(
                            subtitle: 'wallet_pack_unavailable'.tr,
                          );
                          return;
                        }
                        await myAlertDialog(
                          title: 'pay_buy_package'.tr,
                          content: 'pay_buy_package_confirm'.tr,
                          onTap: () async {
                            Get.back();
                            myLoadingDialog();
                            final sub =
                                Get.isRegistered<SubscriptionController>()
                                ? Get.find<SubscriptionController>()
                                : Get.put(SubscriptionController());
                            final success = await sub.purchasePointPack(
                              productId,
                            );
                            Get.back(); // ferme le loader
                            if (success) {
                              // Le webhook RevenueCat crédite les points côté
                              // serveur : on rafraîchit le solde.
                              await authController.getUserModel();
                              mySuccessDialog(
                                subtitle: 'wallet_topup_success'.tr,
                              );
                            } else if (sub.lastPurchaseCancelled) {
                              myWarningDialog(
                                title: 'common_info'.tr,
                                subtitle: 'pay_cancelled'.tr,
                              );
                            } else {
                              myWarningDialog(
                                subtitle: 'wallet_purchase_incomplete'.tr,
                              );
                            }
                          },
                        );
                      },
                      points: bundle.points ?? 'N/A',
                      price: bundle.price ?? 'N/A',
                      isHighlighted: badge == 'Populaire',
                    );
                  },
                );
              }),
              height(0.01),

              // Bannière « Boutique de points » retirée. Elle menait à
              // PointsStore, qui appelait /api/packages/buy — un endpoint qui
              // ne crédite aucun point mais répondait « succès » : sur Android
              // on confirmait un achat, on lisait « achat réussi » et on ne
              // recevait rien. La recharge conforme (achat intégré) est juste
              // au-dessus. L'écran reste dans le dépôt, réactivable une fois
              // branché sur un vrai paiement.
              height(0.03),
            ],
          ),
        ),
      ),
    );
  }
}

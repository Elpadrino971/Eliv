import 'dart:io';

import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AllSubscriptionScreen extends StatefulWidget {
  final bool fromArtist;
  const AllSubscriptionScreen({super.key, this.fromArtist = false});

  @override
  State<AllSubscriptionScreen> createState() => _AllSubscriptionScreenState();
}

class _AllSubscriptionScreenState extends State<AllSubscriptionScreen> {
  final subscriptionController = Get.put(SubscriptionController());
  bool _isAnnual = false;

  /// Switch "Monthly / Annual" — 2 mois offerts sur l'annuel (prix x10, pas x12).
  Widget _billingToggle() {
    Widget segment(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: selected ? kGoldGradient : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? midnightPrimary : textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: midnightSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          segment('MONTHLY', !_isAnnual, () => setState(() => _isAnnual = false)),
          segment(
            'ANNUAL 🔥 SAVE 2 MO.',
            _isAnnual,
            () => setState(() => _isAnnual = true),
          ),
        ],
      ),
    );
  }

  /// [SCAFFOLD HYBRIDE] Bannière non-bloquante "s'abonner sur le web".
  /// L'IAP reste le bouton principal (instantané) ; ceci est l'option marge.
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await subscriptionController.getSubscriptions();
  }

  Future fetchOffers({required String id, required String title}) async {
    if (Platform.isAndroid) {
      await subscriptionController.buySubscription(subscriptionId: id);
      return;
    }
    final offerings = await subscriptionController.fetchOffers();

    if (offerings.isEmpty) {
      myWarningDialog(subtitle: "Something went wrong, try again later.");
      // Get.snackbar(
      //   'No Plans',
      //   'No plans available',
      //   backgroundColor: mainThemeColor,
      // );
    } else {
      final packages = offerings
          .map((e) => e.availablePackages)
          .expand((pair) => pair)
          .toList();

      final filteredPackages = packages
          .where((package) => package.storeProduct.title == title)
          .toList();

      //Paywall Widget

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Get.isDarkMode ? darkmodeColor : whiteColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                height(0.02),
                Text(
                  'sub_tap_confirm'.tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                Text(
                  'pay_confirm_continue'.tr,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
                height(0.02),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  // itemCount: packages.length,
                  itemCount: filteredPackages.length,
                  itemBuilder: (context, index) {
                    // final package = packages[index];
                    // final product = package.storeProduct;

                    final product = filteredPackages[index].storeProduct;

                    return GestureDetector(
                      onTap: () async {
                        // myPrint(package);

                        Get.back();
                        bool value = await subscriptionController
                            .purchasePackage(filteredPackages[index]);
                        value
                            ? await subscriptionController.buySubscription(
                                subscriptionId: id,
                              )
                            : myWarningDialog(
                                title: 'pay_purchasing_failed'.tr,
                                subtitle: 'pay_subscribe_failed'.tr,
                                btnTitle: 'common_continue'.tr,
                              );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          borderRadius: BorderRadius.circular(20),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: Get.isDarkMode
                          //         ? whiteColor
                          //         : mainThemeColor.withValues(alpha: 0.3),
                          //     blurRadius: 10,
                          //     offset: const Offset(0, 4),
                          //   ),
                          // ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: whiteColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.diamond_outlined,
                                color: whiteColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    style: TextStyle(
                                      color: whiteColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  height(0.005),
                                  Text(
                                    product.subscriptionPeriod == 'P1M'
                                        ? 'sub_monthly_plan'.tr
                                        : 'sub_yearly_plan'.tr,
                                    style: TextStyle(
                                      color: whiteColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            width(0.02),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  product.priceString,
                                  style: TextStyle(
                                    color: whiteColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  product.subscriptionPeriod == 'P1M'
                                      ? '/mo'
                                      : '/yr',
                                  style: TextStyle(
                                    // color: blackColor.withValues(alpha: 0.7),
                                    color: whiteColor.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                height(0.02),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: midnightPrimary,
      appBar: MyAppbar(title: 'subs_title'.tr),
      body: Obx(() {
        final list = subscriptionController.subscriptionModel.value.list;

        if (list == null) {
          return Center(
            child: CircularProgressIndicator(color: goldPrimary),
          );
        }

        if (list.isEmpty) {
          return Center(
            child: Text(
              'empty_no_subscriptions'.tr,
              style: TextStyle(
                color: whiteColor.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(),
            _billingToggle(),
            const SizedBox(height: 18),
            ...list.map(
              (sub) => SubscriptionCard(
                subscription: sub,
                // Bouton d'achat visible partout : sur iOS l'achat passe par
                // Apple IAP (produits vybzz_XX_1m approuvés) via fetchOffers().
                // Le lien "payer par carte" (web/Stripe) reste masqué sur iOS
                // plus bas (onWebPurchaseTap) -> respect de l'anti-steering.
                showButton: true,
                isAnnual: _isAnnual,
                onPurchaseTap: () async {
                  await fetchOffers(id: sub.id.toString(), title: sub.title!);
                },
                // Lien "Payer par carte" masqué sur iOS (anti-steering Apple
                // 3.1.1 = risque de rejet). Proposé uniquement sur Android.
                onWebPurchaseTap: Platform.isIOS
                    ? null
                    : () => subscriptionController.subscribeOnWeb(
                        subscriptionId: sub.id.toString(),
                        annual: _isAnnual,
                      ),
              ),
            ),
            const SizedBox(height: 18),
            _footer(),
          ],
        );
      }),
    );
  }

  /// En-tête "CHOOSE YOUR PLAN" (style mockup VYBZZZ).
  Widget _header() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: AppFonts.logo,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
            children: [
              TextSpan(text: 'VYBZZZ', style: TextStyle(color: goldPrimary)),
              TextSpan(text: '  LIVE', style: TextStyle(color: ivory)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
            children: [
              TextSpan(text: 'CHOOSE ', style: TextStyle(color: ivory)),
              TextSpan(text: 'YOUR ', style: TextStyle(color: goldPrimary)),
              TextSpan(text: 'PLAN', style: TextStyle(color: ivory)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'UNLOCK MORE · EARN MORE · LIVE MORE',
          style: TextStyle(
            color: textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Pied "Secure checkout · Cancel anytime".
  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: midnightSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _footerItem(
              Icons.lock_outline_rounded,
              'Secure checkout',
              'Your data is encrypted',
            ),
          ),
          Container(width: 1, height: 34, color: goldSecondary.withValues(alpha: 0.2)),
          Expanded(
            child: _footerItem(
              Icons.autorenew_rounded,
              'Cancel anytime',
              'No contracts',
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerItem(IconData icon, String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: goldPrimary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ivory,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: textMuted, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

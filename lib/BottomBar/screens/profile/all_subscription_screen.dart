import 'dart:io';

import 'package:artist/Controllers/subscription_controller.dart';
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

  /// [SCAFFOLD HYBRIDE] Bannière non-bloquante "s'abonner sur le web".
  /// L'IAP reste le bouton principal (instantané) ; ceci est l'option marge.
  Widget _webSaveBanner() {
    return GestureDetector(
      onTap: () => subscriptionController.subscribeOnWeb(),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: goldPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldPrimary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.savings_outlined, color: goldPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "S'abonner sur le web",
                    style: TextStyle(
                      color: ivory,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Meilleur prix, paiement sécurisé',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: goldPrimary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

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
                  'Tap To Confirm Subscription',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                Text(
                  'By continuing, you agree to pay for the following plan',
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
                                title: 'Purchasing failed',
                                subtitle: 'Subscribing a new package failed',
                                btnTitle: 'Continue',
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
                                        ? 'Monthly Plan'
                                        : 'Yearly Plan',
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
    final bool isDark = Get.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? darkmodeColor : const Color(0xffF8F8F8),
      appBar: MyAppbar(title: 'Subscriptions'),
      body: Obx(() {
        final list = subscriptionController.subscriptionModel.value.list;

        if (list == null) {
          return Center(
            child: CircularProgressIndicator(color: mainThemeColor),
          );
        }

        if (list.isEmpty) {
          return Center(
            child: Text(
              'No Subscriptions Available',
              style: TextStyle(
                color: isDark
                    ? whiteColor.withValues(alpha: 0.6)
                    : const Color(0xff888888),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: list.length + 1,
          itemBuilder: (context, index) {
            if (index == list.length) return _webSaveBanner();
            final sub = list[index];
            return SubscriptionCard(
              subscription: sub,
              showButton: true,
              onPurchaseTap: () async {
                await fetchOffers(id: sub.id.toString(), title: sub.title!);
                // await myAlertDialog(
                //   title: 'Purchase Subscription',
                //   content: 'Are you sure you want to purchase "${sub.title}"?',
                //   onTap: () async {
                //     Get.back();

                //     await fetchOffers(id: sub.id.toString(), title: sub.title!);

                //     // await subscriptionController.buySubscription(
                //     //   fromArtist: widget.fromArtist,
                //     //   subscriptionId: '${sub.id}',
                //     // );
                //   },
                // );
              },
            );
          },
        );
      }),
    );
  }
}

import 'package:artist/BottomBar/screens/profile/points_store.dart';
import 'package:artist/BottomBar/screens/profile/topup_history.dart';
import 'package:artist/Controllers/auth_controller.dart';
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
                          'ARENA POINTS BALANCE',
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
                                userModel.value.user?.points ?? 'N/A',
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
                          label: 'Withdraw Points',
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
                  const Text(
                    'TOP UP POINTS',
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
                    return PointsCard(
                      onTap: () async {
                        await myAlertDialog(
                          title: 'Buy Package',
                          content: 'Are you sure you want to buy this package?',
                          onTap: () async {
                            Get.back();
                            await authController.purchasePackage(
                              packageId: bundle.id.toString(),
                            );
                          },
                        );
                      },
                      points: bundle.points ?? 'N/A',
                      price: bundle.price ?? 'N/A',
                      isHighlighted: index == 0,
                    );
                  },
                );
              }),
              height(0.01),

              // Store Banner
              GestureDetector(
                onTap: () => Get.to(
                  () => PointsStore(
                    packages: authController.packages.value.list ?? [],
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: Get.isDarkMode
                        ? LinearGradient(
                            colors: [goldPrimary.withValues(alpha: 0.8), goldPrimary],
                          )
                        : LinearGradient(
                            colors: [
                              mainThemeColor.withValues(alpha: 0.8),
                              mainThemeColor,
                            ],
                          ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Points Store',
                              style: TextStyle(
                                color: whiteColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            height(0.005),
                            Text(
                              'Unlock special bundles, limited-time multipliers, and more.',
                              style: TextStyle(
                                color: whiteColor.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      width(0.02),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: whiteColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'VIEW ALL\nOFFERS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Get.isDarkMode
                                    ? goldPrimary
                                    : mainThemeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            width(0.02),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              height(0.03),
            ],
          ),
        ),
      ),
    );
  }
}

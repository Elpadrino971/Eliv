import 'dart:math' as math;

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/BottomBar/screens/profile/all_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/artist_onboarding_screen.dart';
import 'package:artist/BottomBar/screens/profile/contant_page.dart';
import 'package:artist/BottomBar/screens/profile/following_artists.dart';
import 'package:artist/BottomBar/screens/profile/history.dart';
import 'package:artist/BottomBar/screens/profile/manage_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/user_wallet.dart';
import 'package:artist/Controllers/controller.dart';
// import 'package:artist/BottomBar/screens/profile/my_tickets.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/settings.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/artist_bottom_bar/artist_bottom_bar.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.fromArtist = false});
  final bool fromArtist;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final authController = Get.find<AuthController>();

  List<UserSubscription> userActiveSubscriptions = [];

  Future myInitMethod() async {
    final data = userModel.value.user?.userSubscription;
    if (data != null && data.isNotEmpty) {
      userActiveSubscriptions = data
          .where((e) => e.status == 'active')
          .toList();
    }
    await authController.getSettings();
    if (mounted) setState(() {});
  }

  List<Map> get acountList => [
      widget.fromArtist
          ? {
              'icon': Icons.swap_horiz_rounded,
              'title': 'prof_switch_user'.tr,
              'subTitle': 'prof_switch_user_sub'.tr,
              'onTap': () {
                Get.offAll(() => MyBottomBar());
              },
            }
          : {
              'icon': Icons.mic_none_rounded,
              'title': 'prof_become_artist'.tr,
              'subTitle': 'prof_do_live'.tr,
              'onTap': () {
                if (userActiveSubscriptions.isEmpty) {
                  myWarningDialog(
                    title: 'common_warning'.tr,
                    subtitle:
                        'prof_no_sub_become_artist'.tr,
                    ontap: () {
                      Get.back();
                      Get.to(
                        () => AllSubscriptionScreen(
                          fromArtist: widget.fromArtist,
                        ),
                      );
                    },
                  );
                } else {
                  if (userModel.value.user?.isArtist == true) {
                    Get.to(() => ArtistBottomBar());
                  } else {
                    Get.to(() => ArtistOnboardingScreen());
                  }
                }
              },
            },
      {
        'icon': Icons.favorite_border_rounded,
        'title': 'prof_following_artists'.tr,
        'subTitle': 'prof_following_artists_sub'.tr,
        'onTap': () => Get.to(() => FollowingArtists()),
      },
      {
        'icon': Icons.history_rounded,
        'title': 'prof_stream_history'.tr,
        'subTitle': 'prof_stream_history'.tr,
        'onTap': () => Get.to(() => History()),
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'prof_wallet'.tr,
        'subTitle': 'prof_wallet_sub'.tr,
        'onTap': () => Get.to(() => const UserWallet()),
      },
      {
        'icon': Icons.workspace_premium_outlined,
        'title': 'prof_purchase_sub'.tr,
        'subTitle': 'prof_become_artist_sub'.tr,
        'onTap': () => Get.to(() => const AllSubscriptionScreen()),
      },
      {
        'icon': Icons.card_membership_outlined,
        'title': 'prof_manage_sub'.tr,
        'subTitle': 'prof_manage_sub_sub'.tr,
        'onTap': () => Get.to(() => const ManageSubscriptionScreen()),
      },
      {
        'icon': Icons.shield_outlined,
        'title': 'prof_privacy'.tr,
        'subTitle': 'prof_privacy_sub'.tr,
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'prof_privacy'.tr,
            content: authController.settings['privacy_policy'],
          ),
        ),
      },
      {
        'icon': Icons.description_outlined,
        'title': 'prof_terms'.tr,
        'subTitle': 'prof_terms_sub'.tr,
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'prof_terms'.tr,
            content: authController.settings['terms_and_conditions'],
          ),
        ),
      },
  ];

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.04),
            Row(
              children: [
                Text(
                  'nav_profile'.tr,
                  style: TextStyle(
                    color: goldPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),

                GestureDetector(
                  onTap: () async {
                    await Get.to(() => Settings());
                    setState(() {});
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: goldSecondary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: goldPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            height(0.01),

            Container(
              width: Get.width,
              padding: myPadding,
              decoration: BoxDecoration(
                gradient: kCardGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: goldSecondary.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Traînée de paillettes dorées (forte opacite)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CustomPaint(
                        painter: _SparkleTrailPainter(),
                      ),
                    ),
                  ),
                  Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldSecondary.withValues(alpha: 0.6),
                            width: 1.4,
                          ),
                        ),
                        child: ClipOval(
                          child: ImageWidget(
                            url: widget.fromArtist
                                ? '${userModel.value.user?.artistProfile}'
                                : '${userModel.value.user?.profileImage}',
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),

                      width(0.03),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Container(
                          //   width: Get.width * 0.35,
                          //   padding: EdgeInsets.all(6),
                          //   decoration: BoxDecoration(
                          //     color: whiteColor,
                          //     borderRadius: BorderRadius.circular(25),
                          //   ),
                          //   child: Text(
                          //     textAlign: TextAlign.center,
                          //     'Platinum Member',
                          //     style: TextStyle(
                          //       color: Get.isDarkMode
                          //           ? blackColor
                          //           : mainThemeColor,
                          //       fontWeight: FontWeight.w500,
                          //       fontSize: 14,
                          //     ),
                          //   ),
                          // ),
                          SizedBox(
                            width: Get.width * 0.5,
                            child: Text(
                              widget.fromArtist
                                  ? userModel.value.user?.artistName ?? 'N/A'
                                  : userModel.value.user?.fullName ?? 'N/A',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ivory,
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: Get.width * 0.5,
                            child: Text(
                              userModel.value.user?.email ?? 'N/A',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  height(0.02),

                  Divider(color: goldSecondary.withValues(alpha: 0.25)),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'prof_total_points'.tr,
                            style: TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                          height(0.005),
                          Text(
                            userModel.value.user?.points.toString() ?? 'N/A',
                            style: TextStyle(
                              color: goldPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                ],
              ),
                ],
              ),
            ),
            height(0.02),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'prof_account_experience'.tr,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    height(0.015),

                    ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (widget.fromArtist && index == 1) {
                          return SizedBox();
                        }
                        return GestureDetector(
                          onTap: acountList[index]['onTap'] as VoidCallback,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            leading: Icon(
                              acountList[index]['icon'] as IconData,
                              color: goldPrimary,
                              size: 28,
                            ),
                            horizontalTitleGap: 14,
                            title: Text(
                              acountList[index]['title'],
                              style: TextStyle(
                                color: ivory,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              acountList[index]['subTitle'],
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_sharp,
                              size: 14,
                              color: goldSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) {
                        if (widget.fromArtist && index == 0) {
                          return SizedBox();
                        }
                        return Divider(
                          height: 1,
                          color: goldSecondary.withValues(alpha: 0.12),
                        );
                      },
                      itemCount: acountList.length,
                    ),
                    height(0.02),
                    GestureDetector(
                      onTap: () async {
                        await myAlertDialog(
                          title: 'prof_logout'.tr,
                          content: 'prof_logout_confirm'.tr,
                          onTap: () async {
                            myLoadingDialog();
                            await unSub('00${userModel.value.user?.id}');
                            await unSub('users');
                            await unSub('artist');
                            if (userModel.value.user?.registrationType ==
                                'social') {
                              await GoogleSignIn.instance.signOut();
                            }
                            await box.remove('user');
                            await Future.delayed(Duration(seconds: 1));
                            Get.offAll(() => LoginScreen());
                          },
                        );
                      },
                      child: Container(
                        padding: myPadding,
                        decoration: BoxDecoration(
                          color: Color(0xffFFF1F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/logout.png'),
                            width(0.02),
                            Text(
                              ' Logout Securely',
                              style: TextStyle(
                                color: Color(0xffFF2056),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    height(0.02),

                    Center(
                      child: Text(
                        textAlign: TextAlign.center,
                        'VybzzZ Mobile App ',
                        style: TextStyle(
                          color: Color(0xffA1A1A1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future unSub(String topic) async =>
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

/// Traînée de paillettes dorées en diagonale, à forte opacité,
/// pour habiller la carte profil (style comète).
class _SparkleTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final paint = Paint()
      ..color = goldPrimary
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);

    const count = 70;
    for (int i = 0; i < count; i++) {
      final t = i / count;
      // Axe diagonal : du centre-haut vers le bas-droite
      final baseX = size.width * (0.40 + t * 0.62);
      final baseY = size.height * (0.02 + t * 1.0);
      final jitterX = (rnd.nextDouble() - 0.5) * size.width * 0.28;
      final jitterY = (rnd.nextDouble() - 0.5) * size.height * 0.32;
      final x = baseX + jitterX;
      final y = baseY + jitterY;

      // Plus dense / opaque vers la fin de la traînée
      final r = 0.6 + rnd.nextDouble() * 2.4;
      final op = (0.25 + rnd.nextDouble() * 0.45 + t * 0.25).clamp(0.0, 0.85);
      paint.color = goldPrimary.withValues(alpha: op);
      canvas.drawCircle(Offset(x, y), r, paint);

      // Quelques éclats en étoile à 4 branches
      if (rnd.nextDouble() > 0.82) {
        final s = 3.0 + rnd.nextDouble() * 3.0;
        final star = Paint()
          ..color = goldPrimary.withValues(alpha: op.clamp(0.0, 0.8))
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), star);
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), star);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkleTrailPainter oldDelegate) => false;
}

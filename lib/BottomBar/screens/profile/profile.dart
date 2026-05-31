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
import 'package:get/get_core/get_core.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
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

  late List<Map> acountList = [];
  Future myInitMethod() async {
    final data = userModel.value.user?.userSubscription;
    if (data != null && data.isNotEmpty) {
      userActiveSubscriptions = data
          .where((e) => e.status == 'active')
          .toList();
    }

    acountList = [
      widget.fromArtist
          ? {
              'icon': Icons.swap_horiz_rounded,
              'title': 'Switch to User',
              'subTitle': 'Switch to user mode',
              'onTap': () {
                Get.offAll(() => MyBottomBar());
              },
            }
          : {
              'icon': Icons.mic_none_rounded,
              'title': 'Become An Artist',
              'subTitle': 'Do live performances',
              'onTap': () {
                if (userActiveSubscriptions.isEmpty) {
                  myWarningDialog(
                    title: 'Warning',
                    subtitle:
                        'You have no active subscription, subscribe to become an artist',
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
        'title': 'Following Artists',
        'subTitle': 'Artists you love',
        'onTap': () => Get.to(() => FollowingArtists()),
      },
      {
        'icon': Icons.history_rounded,
        'title': 'Stream History',
        'subTitle': 'Stream History',
        'onTap': () => Get.to(() => History()),
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Wallet',
        'subTitle': 'View your wallet balance',
        'onTap': () => Get.to(() => const UserWallet()),
      },
      {
        'icon': Icons.workspace_premium_outlined,
        'title': 'Purchase Subscription',
        'subTitle': 'Unlock artist features with a subscription plan',
        'onTap': () => Get.to(() => const AllSubscriptionScreen()),
      },
      {
        'icon': Icons.card_membership_outlined,
        'title': 'Manage Subscription',
        'subTitle': 'View & manage your active subscription',
        'onTap': () => Get.to(() => const ManageSubscriptionScreen()),
      },
      {
        'icon': Icons.shield_outlined,
        'title': 'Privacy Policy',
        'subTitle': 'View privacy policy',
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'Privacy Policy',
            content: authController.settings['privacy_policy'],
          ),
        ),
      },
      {
        'icon': Icons.description_outlined,
        'title': 'Terms & Conditions',
        'subTitle': 'View terms & conditions',
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'Terms & Conditions',
            content: authController.settings['terms_and_conditions'],
          ),
        ),
      },
    ];
    await authController.getSettings();
  }

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
                  'Profile',
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
                  // Filigrane "V" discret
                  Positioned(
                    right: 4,
                    bottom: -8,
                    child: Text(
                      'V',
                      style: TextStyle(
                        fontSize: 90,
                        fontWeight: FontWeight.bold,
                        color: goldPrimary.withValues(alpha: 0.05),
                        height: 1,
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
                            'TOTAL POINTS',
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
                      'ACCOUNT EXPERIENCE',
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
                          title: 'Logout',
                          content: 'Are you sure you want to logout?',
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
                        'VyBzzZ Mobile App ',
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

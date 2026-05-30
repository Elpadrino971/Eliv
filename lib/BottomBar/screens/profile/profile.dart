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
              'image': 'assets/image2.png',
              'title': 'Switch to User',
              'subTitle': 'Switch to user mode',
              'onTap': () {
                Get.offAll(() => MyBottomBar());
              },
            }
          : {
              'image': 'assets/image2.png',
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
        'image': 'assets/image3.png',
        'title': 'Following Artists',
        'subTitle': 'Artists you love',
        'onTap': () => Get.to(() => FollowingArtists()),
      },
      {
        'image': 'assets/image4.png',
        'title': 'Stream History',
        'subTitle': 'Stream History',
        'onTap': () => Get.to(() => History()),
      },
      {
        'image': 'assets/wallet.png',
        'title': 'Wallet',
        'subTitle': 'View your wallet balance',
        'onTap': () => Get.to(() => const UserWallet()),
      },
      {
        'image': 'assets/wallet.png',
        'title': 'Purchase Subscription',
        'subTitle': 'Unlock artist features with a subscription plan',
        'onTap': () => Get.to(() => const AllSubscriptionScreen()),
      },
      {
        'image': 'assets/wallet.png',
        'title': 'Manage Subscription',
        'subTitle': 'View & manage your active subscription',
        'onTap': () => Get.to(() => const ManageSubscriptionScreen()),
      },
      {
        'image': 'assets/icon10.png',
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
        'image': 'assets/warning.png',
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
                    color: blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Spacer(),

                GestureDetector(
                  onTap: () async {
                    await Get.to(() => Settings());
                    setState(() {});
                  },
                  child: Image.asset('assets/setting4.png', width: 40),
                ),
              ],
            ),
            height(0.01),

            Container(
              width: Get.width,
              padding: myPadding,
              decoration: BoxDecoration(
                color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: ImageWidget(
                          url: widget.fromArtist
                              ? '${userModel.value.user?.artistProfile}'
                              : '${userModel.value.user?.profileImage}',
                          width: 50,
                          height: 50,
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
                                color: whiteColor,
                                fontWeight: FontWeight.w500,
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
                              style: TextStyle(color: whiteColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  height(0.02),

                  Divider(color: whiteColor.withValues(alpha: 0.2)),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Points',
                            style: TextStyle(
                              color: whiteColor.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            userModel.value.user?.points.toString() ?? 'N/A',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
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
                      'Account Experience',
                      style: TextStyle(
                        color: Color(0xffA1A1A1),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    height(0.01),

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
                            contentPadding: EdgeInsets.all(0),
                            leading: Image.asset(
                              acountList[index]['image'],
                              height: 45,
                            ),
                            title: Text(acountList[index]['title']),
                            subtitle: Text(
                              acountList[index]['subTitle'],
                              style: TextStyle(color: Color(0xffA1A1A1)),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_sharp,
                              size: 15,
                              color: greyColor,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) {
                        return height(0.0);
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

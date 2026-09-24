import 'package:artist/BottomBar/screens/profile/about_screen.dart';
import 'package:artist/BottomBar/screens/profile/faq_screen.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/alerts_screen.dart';
import 'package:artist/BottomBar/screens/profile/language_screen.dart';
import 'package:artist/Global/locale_service.dart';
import 'package:artist/BottomBar/screens/profile/personal_screen.dart';
import 'package:artist/BottomBar/screens/profile/security_screen.dart';
import 'package:artist/BottomBar/screens/profile/following_artists.dart';
import 'package:artist/BottomBar/screens/profile/my_list_screen.dart';
import 'package:artist/BottomBar/screens/profile/history.dart';
import 'package:artist/BottomBar/screens/profile/user_wallet.dart';
import 'package:artist/BottomBar/screens/profile/all_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/manage_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/idea_box_screen.dart';
import 'package:artist/BottomBar/screens/profile/contant_page.dart';
import 'package:artist/BottomBar/screens/profile/Support/all_support_chats.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/BottomBar/screens/profile/blocked_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final authController = Get.find<AuthController>();
  List<Map> get acountList => [
    {
      'title': 'prof_personal_info'.tr,
      'subTitle': 'prof_personal_info_sub'.tr,
      'image': 'assets/icon8.png',
      'screen': PersonalScreen(),
    },
    {
      'title': 'prof_password_security'.tr,
      'subTitle': 'prof_password_security_sub'.tr,
      'image': 'assets/icon9.png',
      'screen': SecurityScreen(),
    },
    {
      'title': 'language'.tr,
      'subTitle': LocaleService.supported
          .firstWhere(
            (l) => l.code == LocaleService.currentCode,
            orElse: () => LocaleService.supported.first,
          )
          .name,
      'image': 'assets/icon10.png',

      'screen': LanguageScreen(),
    },
  ];

  List<Map> get preferencesList => [
    {
      'title': 'prof_notifications'.tr,
      'subTitle': 'prof_notifications_sub'.tr,
      'image': 'assets/icon11.png',
      'screen': AlertsScreen(),
    },
  ];

  List<Map> get supportList => [
    {
      'title': 'prof_help_center'.tr,
      'subTitle': 'prof_help_center_sub'.tr,
      'image': 'assets/icon12.png',
      'screen': AllSupportChats(),
    },
    {
      'title': 'prof_faq'.tr,
      'subTitle': 'prof_faq_sub'.tr,
      'image': 'assets/icon12.png',
      'screen': FaqScreen(),
    },
  ];

  // Éléments "compte VYBZZZ" migrés depuis l'écran Profil (le profil ne garde
  // que le hero). Icônes + navigation identiques à l'ancienne liste du profil.
  List<Map> get vybzzzAccountList => [
    {
      'icon': Icons.playlist_add_check_rounded,
      'title': 'Ma liste',
      'subTitle': 'Les artistes que tu as enregistrés',
      'onTap': () => Get.to(() => const MyListScreen()),
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
      // Exigence App Store 1.2 : le blocage doit pouvoir être annulé par
      // l'utilisateur lui-même, sans passer par le support.
      'icon': Icons.block_rounded,
      'title': 'mod_blocked_title'.tr,
      'subTitle': 'mod_blocked_sub'.tr,
      'onTap': () => Get.to(() => const BlockedAccountsScreen()),
    },
    {
      'icon': Icons.lightbulb_outline_rounded,
      'title': 'idea_box_title'.tr,
      'subTitle': 'idea_box_subtitle'.tr,
      'onTap': () => Get.to(() => const IdeaBoxScreen()),
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
    {
      'icon': Icons.info_outline_rounded,
      'title': 'about_title'.tr,
      'subTitle': 'about_subtitle'.tr,
      'onTap': () => Get.to(() => const AboutScreen()),
    },
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'common_settings'.tr),

      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'section_account'.tr,
                style: TextStyle(
                  color: Color(0xff737373),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              height(0.01),

              MyContainer(
                widget: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () {
                        Get.to(() => acountList[index]['screen'] as Widget);
                      },
                      minTileHeight: 40,
                      contentPadding: EdgeInsets.all(0),

                      leading: Image.asset(
                        acountList[index]['image'],
                        width: 40,
                        height: 40,
                      ),

                      title: Text(
                        acountList[index]['title'],
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        acountList[index]['subTitle'],
                        style: TextStyle(
                          color: Color(0xff737373),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: greyColor,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(color: greyColor.withValues(alpha: 0.2));
                  },
                  itemCount: acountList.length,
                ),
              ),

              height(0.02),
              Text(
                'prof_account_experience'.tr,
                style: TextStyle(
                  color: Color(0xff737373),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              height(0.01),
              MyContainer(
                widget: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: vybzzzAccountList[index]['onTap'] as VoidCallback,
                      minTileHeight: 40,
                      contentPadding: EdgeInsets.all(0),
                      leading: Icon(
                        vybzzzAccountList[index]['icon'] as IconData,
                        color: goldPrimary,
                        size: 26,
                      ),
                      title: Text(
                        vybzzzAccountList[index]['title'],
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        vybzzzAccountList[index]['subTitle'],
                        style: TextStyle(
                          color: Color(0xff737373),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: greyColor,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(color: greyColor.withValues(alpha: 0.2));
                  },
                  itemCount: vybzzzAccountList.length,
                ),
              ),

              // height(0.01),
              // Text(
              //   'Preferences',
              //   style: TextStyle(
              //     color: Color(0xff737373),
              //     fontWeight: FontWeight.w600,
              //     fontSize: 16,
              //   ),
              // ),

              // height(0.01),

              // MyContainer(
              //   widget: ListView.separated(
              //     shrinkWrap: true,
              //     padding: EdgeInsets.all(0),
              //     physics: NeverScrollableScrollPhysics(),
              //     itemBuilder: (context, index) {
              //       return ListTile(
              //         onTap: () {
              //           Get.to(
              //             () => preferencesList[index]['screen'] as Widget,
              //           );
              //         },
              //         minTileHeight: 40,
              //         contentPadding: EdgeInsets.all(0),

              //         leading: Image.asset(
              //           preferencesList[index]['image'],
              //           width: 40,
              //           height: 40,
              //         ),

              //         title: Text(
              //           preferencesList[index]['title'],
              //           style: TextStyle(
              //             color: Get.isDarkMode ? whiteColor : blackColor,
              //             fontWeight: FontWeight.bold,
              //             fontSize: 16,
              //           ),
              //         ),
              //         subtitle: Text(
              //           preferencesList[index]['subTitle'],
              //           style: TextStyle(
              //             color: Color(0xff737373),
              //             fontWeight: FontWeight.w600,
              //             fontSize: 14,
              //           ),
              //         ),
              //         trailing: Icon(
              //           Icons.arrow_forward_ios_rounded,
              //           size: 12,
              //           color: greyColor,
              //         ),
              //       );
              //     },
              //     separatorBuilder: (context, index) {
              //       return Divider(color: greyColor.withValues(alpha: 0.2));
              //     },
              //     itemCount: preferencesList.length,
              //   ),
              // ),
              height(0.01),
              Text(
                'section_support'.tr,
                style: TextStyle(
                  color: Color(0xff737373),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),

              height(0.01),

              MyContainer(
                widget: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () {
                        Get.to(() => supportList[index]['screen'] as Widget);
                      },
                      minTileHeight: 40,
                      contentPadding: EdgeInsets.all(0),

                      leading: Image.asset(
                        supportList[index]['image'],
                        width: 40,
                        height: 40,
                      ),

                      title: Text(
                        supportList[index]['title'],
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        supportList[index]['subTitle'],
                        style: TextStyle(
                          color: Color(0xff737373),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: greyColor,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(color: greyColor.withValues(alpha: 0.2));
                  },
                  itemCount: supportList.length,
                ),
              ),

              height(0.01),

              GestureDetector(
                onTap: () async {
                  await myAlertDialog(
                    title: 'prof_logout'.tr,
                    content: 'prof_logout_confirm'.tr,
                    onTap: () => authController.logout(),
                  );
                },
                child: MyContainer(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  widget: ListTile(
                    minTileHeight: 40,
                    contentPadding: EdgeInsets.all(0),
                    leading: Icon(Icons.logout_rounded,
                        color: Color(0xffFF2056), size: 30),
                    title: Text(
                      'prof_logout'.tr,
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'prof_logout_confirm'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: greyColor,
                    ),
                  ),
                ),
              ),

              height(0.01),

              GestureDetector(
                onTap: () async {
                  await myWarningDialog(
                    title: 'prof_delete_account'.tr,
                    subtitle:
                        'prof_delete_warning'.tr,
                    image: 'assets/warning.png',
                    btnTitle: 'common_back'.tr,
                    secondBtnTitle: 'prof_delete_account'.tr,
                    secondOnTap: () async {
                      await authController.deleteAccount();
                    },
                  );
                },
                child: MyContainer(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  widget: ListTile(
                    minTileHeight: 40,
                    contentPadding: EdgeInsets.all(0),

                    leading: Image.asset(
                      'assets/icon13.png',
                      width: 40,
                      height: 40,
                    ),

                    title: Text(
                      'prof_delete_account'.tr,
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'prof_delete_account_sub'.tr,
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: greyColor,
                    ),
                  ),
                ),
              ),

              height(0.08),
            ],
          ),
        ),
      ),
    );
  }
}

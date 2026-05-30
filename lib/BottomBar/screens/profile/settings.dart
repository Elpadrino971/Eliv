import 'package:artist/BottomBar/screens/profile/faq_screen.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Controllers/theme_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/alerts_screen.dart';
import 'package:artist/BottomBar/screens/profile/language_screen.dart';
import 'package:artist/BottomBar/screens/profile/personal_screen.dart';
import 'package:artist/BottomBar/screens/profile/security_screen.dart';
import 'package:artist/BottomBar/screens/profile/Support/all_support_chats.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final authController = Get.find<AuthController>();
  List<Map> acountList = [
    {
      'title': 'Personal Information',
      'subTitle': 'Email, Phone, Birthday',
      'image': 'assets/icon8.png',
      'screen': PersonalScreen(),
    },
    {
      'title': 'Password & Security',
      'subTitle': 'Change password',
      'image': 'assets/icon9.png',
      'screen': SecurityScreen(),
    },
    {
      'title': 'Language',
      'subTitle': 'English (US)',
      'image': 'assets/icon10.png',

      'screen': LanguageScreen(),
    },
  ];

  List<Map> preferencesList = [
    {
      'title': 'Notifications',
      'subTitle': 'Push, Email, SMS',
      'image': 'assets/icon11.png',
      'screen': AlertsScreen(),
    },
  ];

  List<Map> supportList = [
    {
      'title': 'Help Center',
      'subTitle': 'Contact support',
      'image': 'assets/icon12.png',
      'screen': AllSupportChats(),
    },
    {
      'title': 'FAQ',
      'subTitle': 'Frequently Asked Questions',
      'image': 'assets/icon12.png',
      'screen': FaqScreen(),
    },
  ];

  var swichValue = true;
  @override
  void initState() {
    super.initState();
    swichValue = box.read(themeKey) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Settings'),

      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Acount',
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
                'Support',
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
                  await myWarningDialog(
                    title: 'Delete Account',
                    subtitle:
                        'This action is permanent. All your ticket history, points, and following data will be lost forever.',
                    image: 'assets/warning.png',
                    btnTitle: 'Back',
                    secondBtnTitle: 'Delete Account',
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
                      'Delete Acount',
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently remove your data',
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

              height(0.01),
              MyContainer(
                widget: ListTile(
                  minTileHeight: 50,
                  contentPadding: EdgeInsets.all(0),

                  leading: Image.asset(
                    'assets/icon14.png',
                    width: 40,
                    height: 40,
                  ),

                  title: Text(
                    'Switch to Dark Mode',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  trailing: Switch(
                    value: swichValue,
                    onChanged: (value) async {
                      await box.write(themeKey, value);
                      Get.find<ThemeController>().toggleTheme(value);
                      swichValue = value;
                      await Future.delayed(Duration(milliseconds: 100));
                      setState(() {});
                    },
                    inactiveThumbColor: whiteColor,
                    inactiveTrackColor: greyColor,
                    activeTrackColor: goldPrimary,
                    activeThumbColor: whiteColor,
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

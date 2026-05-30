import 'package:artist/BottomBar/screens/profile/profile.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_events_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Status/artist_histroy_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/studio_screen.dart';

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class ArtistBottomBar extends StatefulWidget {
  const ArtistBottomBar({super.key});

  @override
  State<ArtistBottomBar> createState() => _ArtistBottomBarState();
}

class _ArtistBottomBarState extends State<ArtistBottomBar> {
  var currentIndex = 0;
  List screenList = [
    StudioScreen(),
    ArtistEventsScreen(),
    ArtistHistroyScreen(),
    Profile(fromArtist: true),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: screenList[currentIndex],
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        margin: EdgeInsets.fromLTRB(15, 0, 15, 5),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? midnightSecondary : whiteColor,
          borderRadius: BorderRadius.circular(35),

          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: Theme(
          data: ThemeData(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            currentIndex: currentIndex,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400),
            selectedItemColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
            unselectedItemColor: Color(0xff737373),
            elevation: 0,

            onTap: (value) {
              setState(() {
                currentIndex = value;
              });
            },

            items: [
              /// STUDIO
              BottomNavigationBarItem(
                label: 'Studio',
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: currentIndex == 0
                      ? BoxDecoration(
                          color: Get.isDarkMode
                              ? goldPrimary.withValues(alpha: 0.2)
                              : mainThemeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          ),
                        )
                      : null,
                  child: Image.asset(
                    'assets/bottom1.png',
                    width: 18,
                    height: 18,
                    color: currentIndex == 0
                        ? (Get.isDarkMode ? goldPrimary : mainThemeColor)
                        : Color(0xff737373),
                  ),
                ),
              ),

              /// EVENTS
              BottomNavigationBarItem(
                label: 'Events',
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: currentIndex == 1
                      ? BoxDecoration(
                          color: Get.isDarkMode
                              ? goldPrimary.withValues(alpha: 0.2)
                              : mainThemeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          ),
                        )
                      : null,
                  child: Image.asset(
                    'assets/bottom2.png',
                    width: 18,
                    height: 18,
                    color: currentIndex == 1
                        ? (Get.isDarkMode ? goldPrimary : mainThemeColor)
                        : Color(0xff737373),
                  ),
                ),
              ),

              /// STATUS
              BottomNavigationBarItem(
                label: 'Status',
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: currentIndex == 2
                      ? BoxDecoration(
                          color: Get.isDarkMode
                              ? goldPrimary.withValues(alpha: 0.2)
                              : mainThemeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          ),
                        )
                      : null,
                  child: Image.asset(
                    'assets/bottom3.png',
                    width: 18,
                    height: 18,
                    color: currentIndex == 2
                        ? (Get.isDarkMode ? goldPrimary : mainThemeColor)
                        : Color(0xff737373),
                  ),
                ),
              ),

              /// PROFILE
              BottomNavigationBarItem(
                label: 'Profile',
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: currentIndex == 3
                      ? BoxDecoration(
                          color: Get.isDarkMode
                              ? goldPrimary.withValues(alpha: 0.2)
                              : mainThemeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          ),
                        )
                      : null,
                  child: Image.asset(
                    'assets/bottom4.png',
                    width: 18,
                    height: 18,
                    color: currentIndex == 3
                        ? (Get.isDarkMode ? goldPrimary : mainThemeColor)
                        : Color(0xff737373),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

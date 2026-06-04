import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class MyAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const MyAppbar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: Get.isDarkMode ? ivory : blackColor,
        ),
      ),
      backgroundColor: Get.isDarkMode ? midnightPrimary : whiteColor,
      surfaceTintColor: Get.isDarkMode ? midnightPrimary : whiteColor,
      foregroundColor: Get.isDarkMode ? goldPrimary : blackColor,
      iconTheme: IconThemeData(color: Get.isDarkMode ? goldPrimary : blackColor),
      elevation: 0,
      centerTitle: true,
    );
  }
}

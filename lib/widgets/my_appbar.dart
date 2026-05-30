import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/my_default_text.dart';

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
      title: MyDefaultText(
        text: title,
        fontSize: 16,
        color: Get.isDarkMode ? whiteColor : blackColor,
      ),
      backgroundColor: Get.isDarkMode ? cardDeep : whiteColor,
      surfaceTintColor: whiteColor,
      elevation: 2,
      centerTitle: true,
      shadowColor: blackColor,
    );
  }
}

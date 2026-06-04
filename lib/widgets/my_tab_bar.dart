import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class MyTabBar extends StatefulWidget {
  final TabController tabController;
  final Color? backgroundColor;
  final String tabOne;
  final String tabTwo;
  final String? tabThree;
  final String? tabFour;
  final Color? indicatorColor;
  final double? selectedSize;
  final double? unselectedSize;

  final void Function(int)? onTap;

  const MyTabBar({
    super.key,
    required this.tabController,
    this.backgroundColor,
    required this.tabOne,
    required this.tabTwo,
    this.tabThree,
    this.tabFour,
    this.indicatorColor,
    this.selectedSize,
    this.unselectedSize,

    this.onTap,
  });

  @override
  State<MyTabBar> createState() => _MyTabBarState();
}

class _MyTabBarState extends State<MyTabBar> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: Get.height * 0.05,
        decoration: BoxDecoration(
          color: Get.isDarkMode ? cardDeep : Color(0xffF8F9FA),
          border: Border.all(
            color: Get.isDarkMode
                ? goldSecondary.withValues(alpha: 0.25)
                : blackColor.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TabBar(
          physics: NeverScrollableScrollPhysics(),

          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: kGoldGradient,
          ),
          dividerHeight: 0,
          labelStyle: TextStyle(
            fontFamily: AppFonts.ui,
            fontWeight: FontWeight.w700,
            fontSize: widget.selectedSize ?? 14,
            letterSpacing: 0.8,
          ),
          controller: widget.tabController,
          labelColor: midnightPrimary,
          unselectedLabelStyle: TextStyle(
            fontFamily: AppFonts.ui,
            fontWeight: FontWeight.w500,
            fontSize: widget.unselectedSize ?? 14,
            letterSpacing: 0.8,
          ),
          unselectedLabelColor: Get.isDarkMode ? textMuted : blackColor,
          indicatorColor: Colors.transparent,
          indicatorWeight: 0.1,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: widget.tabOne),
            Tab(text: widget.tabTwo),
            if (widget.tabThree != null) Tab(text: widget.tabThree),
            if (widget.tabFour != null) Tab(text: widget.tabFour),
          ],
        ),
      ),
    );
  }
}

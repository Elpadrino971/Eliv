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
          color: Color(0xffF8F9FA),
          border: Border.all(color: blackColor.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TabBar(
          physics: NeverScrollableScrollPhysics(),

          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          indicator: BoxDecoration(
            // Dynamic border radius based on selected tab
            borderRadius: BorderRadius.circular(15),
            color: Get.isDarkMode ? redColor : mainThemeColor,
            border: Border.all(
              color: Get.isDarkMode ? redColor : mainThemeColor,
            ),
          ),
          dividerHeight: 1,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: widget.selectedSize ?? 15,
          ),
          controller: widget.tabController,
          labelColor: whiteColor,
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: widget.unselectedSize ?? 15,
          ),
          unselectedLabelColor: blackColor,
          indicatorColor: widget.indicatorColor ?? mainThemeColor,
          indicatorWeight: 3,
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

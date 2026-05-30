import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/state_manager.dart';

class MyContainer extends StatelessWidget {
  const MyContainer({
    super.key,
    required this.widget,
    this.padding,
    this.color,
    this.border,
    this.noWidth = false,
    this.height,
  });
  final Widget widget;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BoxBorder? border;
  final bool noWidth;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: noWidth ? null : Get.width,
      padding: padding ?? myPadding,
      decoration: BoxDecoration(
        // color: color ?? Color(0xffFAFAFA),
        color:
            color ?? (Get.isDarkMode ? Color(0xff141821) : Color(0xffFAFAFA)),
        borderRadius: BorderRadius.circular(15),
        border: border ?? Border.all(color: greyColor.withValues(alpha: 0.2)),
      ),
      child: widget,
    );
  }
}

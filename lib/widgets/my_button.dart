import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Global/global.dart';

class MyButton extends StatelessWidget {
  final double? buttonWidth;
  final double? buttonHeight;
  final String label;
  final VoidCallback onTap;
  final String? image;

  final Color? borderColor;
  final Color? labelColor;
  final double? borderRadius;
  final double? labelSize;
  final Color? buttonColor;

  final FontWeight? fontWeight;
  final Color? imageColor;
  final double? imageHeight;
  final double? imageWidth;
  final double? elevation;
  final List<BoxShadow>? boxShadow;

  const MyButton({
    super.key,

    this.buttonWidth,
    this.buttonHeight,
    required this.label,
    required this.onTap,
    this.image,

    this.borderColor,
    this.labelColor,
    this.borderRadius,
    this.labelSize,

    this.buttonColor,
    this.fontWeight,
    this.imageColor,
    this.imageHeight,
    this.imageWidth,
    this.boxShadow,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(borderRadius ?? 30),
      elevation: elevation ?? 0,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? 30),
        child: Ink(
          decoration: BoxDecoration(
            // gradient:

            // buttonColor!=null? null:

            //  LinearGradient(
            //   colors: [Color(0xff9910F9), Color(0xffE50177)],

            //   begin: Alignment.centerLeft,
            //   end: Alignment.centerRight,
            // ),
            boxShadow: boxShadow,
            border: Border.all(color: borderColor ?? Colors.transparent),
            color:
                buttonColor ??
                (Get.isDarkMode ? Color(0xff7A0709) : mainThemeColor),
            borderRadius: BorderRadius.circular(borderRadius ?? 30),
          ),
          child: SizedBox(
            width: buttonWidth ?? Get.width,
            height: buttonHeight ?? Get.height * 0.055,

            child: image != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: labelColor ?? whiteColor,
                          fontWeight: fontWeight ?? FontWeight.w600,
                          fontSize: labelSize ?? 14,
                        ),
                      ),
                      width(0.02),
                      Image.asset(
                        image!,
                        height: imageHeight ?? 18,
                        width: imageWidth ?? 18,
                        color: imageColor,
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor ?? whiteColor,
                        fontWeight: fontWeight ?? FontWeight.w600,
                        fontSize: labelSize ?? 14,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

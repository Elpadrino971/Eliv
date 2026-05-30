import 'package:artist/Global/app_fonts.dart';
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
            // Par defaut : degrade or premium. Si buttonColor est fourni,
            // on utilise une couleur pleine (boutons secondaires/outline).
            gradient: buttonColor == null ? kGoldGradient : null,
            boxShadow: boxShadow,
            border: Border.all(color: borderColor ?? Colors.transparent),
            color: buttonColor,
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
                          fontFamily: AppFonts.ui,
                          color: labelColor ?? midnightPrimary,
                          fontWeight: fontWeight ?? FontWeight.w700,
                          fontSize: labelSize ?? 14,
                          letterSpacing: 1,
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
                        fontFamily: AppFonts.ui,
                        color: labelColor ?? midnightPrimary,
                        fontWeight: fontWeight ?? FontWeight.w700,
                        fontSize: labelSize ?? 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

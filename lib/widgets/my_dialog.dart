import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_default_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SuccessDialog extends StatelessWidget {
  const SuccessDialog({
    super.key,
    required this.ontap,
    required this.title,
    required this.subtitle,
    this.btnTitle,
    this.image,
    this.secondButtonLabel,
    this.secondButtonOnTap,
    this.isTwoButton = false,
    this.secondButtonWidth,
    this.firstButtonWidth,
    this.showIcon = false,
    this.showSecondIcon = false,
    this.secondButtonColor,
    this.buttonColor,
    this.secondLabelColor,
    this.labelColor,
  });

  final String title;
  final String subtitle;
  final String? btnTitle;
  final String? image;
  final String? secondButtonLabel;
  final VoidCallback? secondButtonOnTap;
  final bool isTwoButton;
  final double? secondButtonWidth;
  final double? firstButtonWidth;
  final void Function() ontap;
  final Color? secondButtonColor;
  final Color? buttonColor;
  final Color? secondLabelColor;
  final Color? labelColor;
  final bool showIcon;
  final bool showSecondIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Get.isDarkMode ? midnightSecondary : whiteColor,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.grey),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Image.asset(image ?? 'assets/success.png', height: 60, width: 60),
            const SizedBox(height: 15),
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            height(0.01),
            Center(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: greyColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            isTwoButton
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      MyButton(
                        buttonColor: Get.isDarkMode ? whiteColor : blackColor,
                        buttonWidth: firstButtonWidth,
                        labelSize: 13,
                        // buttonColor: buttonColor,
                        labelColor: labelColor,
                        label: btnTitle ?? 'Continue',
                        onTap: ontap,
                      ),
                      MyButton(
                        labelSize: 13,
                        // buttonColor: secondButtonColor,
                        buttonWidth: secondButtonWidth,
                        labelColor: secondLabelColor,
                        label: secondButtonLabel ?? 'Continue',
                        onTap: secondButtonOnTap!,
                      ),
                    ],
                  )
                : MyButton(
                    label: btnTitle ?? 'Continue',
                    onTap: ontap,

                    // buttonColor: buttonColor ?? mainThemeColor,
                  ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

class WarningDialog extends StatelessWidget {
  const WarningDialog({
    super.key,
    required this.ontap,
    required this.title,
    required this.subtitle,
    this.btnTitle,

    this.image,
    this.secondButtonTitle,
    this.secondOnTap,
  });

  final String title;
  final String subtitle;
  final String? btnTitle;
  final String? secondButtonTitle;

  final String? image;

  final void Function() ontap;
  final void Function()? secondOnTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Get.isDarkMode ? midnightSecondary : whiteColor,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: greyColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 15),
          Image.asset(image ?? 'assets/warning.png', height: 65, width: 65),
          const SizedBox(height: 15),
          Center(
            child: Text(
              title,
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : blackColor,
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Get.isDarkMode
                    ? whiteColor.withValues(alpha: 0.5)
                    : blackColor.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          height(0.01),

          Divider(thickness: 0.5, color: greyColor),

          height(0.01),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: ontap,
                  child: MyDefaultText(
                    text: btnTitle ?? 'Continue',
                    color: Get.isDarkMode ? whiteColor : blackColor,
                  ),
                ),
                if (secondButtonTitle != null)
                  SizedBox(
                    height: 25,
                    child: VerticalDivider(thickness: 0.5, color: greyColor),
                  ),

                if (secondButtonTitle != null)
                  GestureDetector(
                    onTap: secondOnTap ?? Get.back,
                    child: Text(
                      secondButtonTitle!,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xffCF0000),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

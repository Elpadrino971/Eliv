import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PointsCard extends StatelessWidget {
  const PointsCard({
    super.key,
    required this.points,
    required this.price,
    this.isHighlighted = false,
    this.onTap,
  });

  final String points;
  final String price;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Get.isDarkMode ? darkmodeColor : whiteColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Get.isDarkMode
                ? goldPrimary
                : mainThemeColor.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                ),
              ),
              child: Icon(
                Icons.stars_rounded,
                color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                size: 24,
              ),
            ),
            height(0.01),
            Text(
              points,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'ARENA POINTS',
              style: TextStyle(
                color: greyColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            height(0.015),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? (Get.isDarkMode
                          ? goldPrimary.withValues(alpha: 0.7)
                          : mainThemeColor.withValues(alpha: 0.7))
                    : boxColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$$price',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isHighlighted
                      ? (Get.isDarkMode ? whiteColor : mainThemeColor)
                      : (Get.isDarkMode ? goldPrimary : mainThemeColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:artist/Global/api.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GiftAnimationManager {
  static void showGiftAnimation({
    required BuildContext context,
    required String giftImagePath,
    required String giftName,
    required String userName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(Get.context!)) {
            Navigator.pop(Get.context!);
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              giftImagePath.isNotEmpty
                  ? ImageWidget(
                      url: '${APIs.giftImageIP}/$giftImagePath',
                      width: 80,
                      height: 80,
                    )
                  : Image.asset('assets/gift_icon.png', width: 80, height: 80),
              const SizedBox(height: 8),
              Text(
                '$giftName Gift!',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'from $userName',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

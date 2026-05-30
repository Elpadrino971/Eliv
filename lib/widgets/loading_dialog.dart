import 'package:artist/Global/colors.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key, this.message, this.color});
  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // backgroundColor: Colors.black54,
      child: Container(
        // margin: const EdgeInsets.all(10.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const SizedBox(width: 6.0),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? (Get.isDarkMode ? redColor : mainThemeColor),
                ),
              ),
              const SizedBox(width: 26.0),
              Flexible(
                child: Text(
                  '$message',
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

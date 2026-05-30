import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/services/push_notification.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class SpalashScreen extends StatefulWidget {
  const SpalashScreen({super.key});

  @override
  State<SpalashScreen> createState() => _SpalashScreenState();
}

class _SpalashScreenState extends State<SpalashScreen> {
  @override
  void initState() {
    try {
      PushNotificationSystem().getAccessToken();
    } catch (e) {
      myPrint(e);
    }
    if (box.read('user') != null) {
      userModel.value = UserModel.fromJson(box.read('user'));
      Future.delayed(Duration(seconds: 3), () {
        Get.offAll(() => MyBottomBar());
      });
    } else {
      Future.delayed(Duration(seconds: 3), () {
        Get.offAll(() => LoginScreen());
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width,
      height: Get.height,
      decoration: BoxDecoration(color: whiteColor),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            // Image.asset('assets/logo.png', width: 150),
            height(0.02),

            Image.asset('assets/text_img.png', width: 150),
          ],
        ),
      ),
    );
  }
}

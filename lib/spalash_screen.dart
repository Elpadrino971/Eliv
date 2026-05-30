import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [midnightSecondary, midnightPrimary],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Wordmark VYBZZZ — serif premium dore
            const Text(
              'VYBZZZ',
              style: TextStyle(
                fontFamily: AppFonts.logo,
                color: goldPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w600,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 14),
            // Filet dore
            Container(
              width: 60,
              height: 1.5,
              color: goldSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              'LIVE CONCERTS. ANYWHERE.',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

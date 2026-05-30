import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class Onboarding3 extends StatefulWidget {
  const Onboarding3({super.key});

  @override
  State<Onboarding3> createState() => _Onboarding3State();
}

class _Onboarding3State extends State<Onboarding3> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        width: Get.width,
        height: Get.height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background3.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            height(0.03),
            MyHeader(activeIndex: 2),

            Spacer(),

            MyButton(
              label: 'Continue ',
              onTap: () {
                Get.to(() => LoginScreen());
              },
              image: 'assets/arrow.png',
              imageColor: whiteColor,
            ),
          ],
        ),
      ),
    );
  }
}

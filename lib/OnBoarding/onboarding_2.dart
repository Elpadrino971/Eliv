import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/OnBoarding/onboarding_3.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class Onboarding2 extends StatefulWidget {
  const Onboarding2({super.key});

  @override
  State<Onboarding2> createState() => _Onboarding2State();
}

class _Onboarding2State extends State<Onboarding2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        width: Get.width,
        height: Get.height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background2.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            height(0.03),
            MyHeader(activeIndex: 1),

            Spacer(),

            MyButton(
              label: 'Continue ',
              onTap: () {
                Get.to(() => Onboarding3());
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

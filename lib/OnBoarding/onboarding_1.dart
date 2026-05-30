import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/OnBoarding/onboarding_2.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Onboarding1 extends StatefulWidget {
  const Onboarding1({super.key});

  @override
  State<Onboarding1> createState() => _Onboarding1State();
}

class _Onboarding1State extends State<Onboarding1> {
  @override
  void initState() {
    super.initState();
    box.write('init', 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        width: Get.width,
        height: Get.height,
        decoration: BoxDecoration(
          color: whiteColor,
          image: DecorationImage(
            image: AssetImage('assets/background1.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            height(0.03),
            MyHeader(activeIndex: 0),

            Spacer(),

            MyButton(
              label: 'Begin ',
              onTap: () {
                Get.to(() => Onboarding2());
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

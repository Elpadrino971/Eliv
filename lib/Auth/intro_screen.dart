import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        width: Get.width,
        height: Get.height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/init4.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            height(0.03),
            Align(
              alignment: .topRight,
              child: GestureDetector(
                onTap: () {},
                child: MyContainer(
                  noWidth: true,
                  color: Colors.black,
                  border: BoxBorder.all(color: Colors.black),
                  widget: Text(
                    'Dark',
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Spacer(),
            MyButton(
              label: 'Enter the Experience',
              onTap: () {
                Get.to(() => MyBottomBar());
              },
              labelColor: midnightPrimary,
            ),
            height(0.01),
            Text(
              'Est. 2026 • Global Stream',
              style: TextStyle(
                color: whiteColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

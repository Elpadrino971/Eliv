import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/get_core.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class ChoiceScreen extends StatefulWidget {
  const ChoiceScreen({super.key});

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  String selected = 'Artist';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? blackColor : scaffoldBackgroundColor,
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            height(0.06),

            // Image.asset('assets/logo2.png'),
            Text(
              textAlign: TextAlign.center,
              'Welcome',
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),

            // height(0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  textAlign: TextAlign.center,
                  'To VYB',
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  textAlign: TextAlign.center,
                  'ZZZ',
                  style: TextStyle(
                    color: yellowColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            height(0.01),

            SizedBox(
              width: Get.width * 0.7,
              child: Text(
                textAlign: TextAlign.center,
                'Please Select Your Account Type',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
            ),
            Spacer(),

            GestureDetector(
              onTap: () {
                setState(() {
                  selected = 'Artist';
                });
              },
              child: MyContainer(
                color: Get.isDarkMode
                    ? selected == 'Artist'
                          ? redColor
                          : Color(0xffFAFAFA)
                    : selected == 'Artist'
                    ? mainThemeColor
                    : Color(0xffFAFAFA),
                widget: Text(
                  textAlign: TextAlign.center,
                  'Artist',
                  style: TextStyle(
                    color: Get.isDarkMode
                        ? selected == 'Artist'
                              ? whiteColor
                              : blackColor
                        : selected == 'Artist'
                        ? whiteColor
                        : mainThemeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            height(0.01),
            GestureDetector(
              onTap: () {
                setState(() {
                  selected = 'User';
                });
              },
              child: MyContainer(
                color: Get.isDarkMode
                    ? selected == 'User'
                          ? redColor
                          : Color(0xffFAFAFA)
                    : selected == 'User'
                    ? mainThemeColor
                    : Color(0xffFAFAFA),
                widget: Text(
                  textAlign: TextAlign.center,
                  'User',
                  style: TextStyle(
                    color: Get.isDarkMode
                        ? selected == 'User'
                              ? whiteColor
                              : blackColor
                        : selected == 'User'
                        ? whiteColor
                        : mainThemeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Spacer(),
            MyButton(
              label: 'Continue',
              onTap: () {
                Get.to(() => LoginScreen());
              },
              labelColor: whiteColor,
            ),
          ],
        ),
      ),
    );
  }
}

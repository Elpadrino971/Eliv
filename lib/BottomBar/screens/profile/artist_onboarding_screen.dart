import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/basic_info.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class ArtistOnboardingScreen extends StatefulWidget {
  const ArtistOnboardingScreen({super.key});

  @override
  State<ArtistOnboardingScreen> createState() => _ArtistOnboardingScreenState();
}

class _ArtistOnboardingScreenState extends State<ArtistOnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/init5.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            Spacer(),

            MyButton(
              label: 'Continue',
              onTap: () {
                Get.to(() => BasicInfo());
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

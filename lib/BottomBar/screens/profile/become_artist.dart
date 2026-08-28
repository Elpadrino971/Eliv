import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/artist_onboarding_screen.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BecomeArtist extends StatefulWidget {
  const BecomeArtist({super.key});

  @override
  State<BecomeArtist> createState() => _BecomeArtistState();
}

class _BecomeArtistState extends State<BecomeArtist> {
  var nameController = TextEditingController();
  var emailController = TextEditingController();
  var phoneContrller = TextEditingController();
  var primaryController = TextEditingController();
  var performanceController = TextEditingController();
  var socialController = TextEditingController();
  var aboutController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'prof_become_artist'.tr),

      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/icon7.png'),
                width(0.02),
                Text(
                  'ba_apply_now'.tr,
                  style: TextStyle(
                    color: ivory,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            height(0.01),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    height(0.01),
                    Text(
                      'Artist/Band Name *',
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: 'ba_stage_hint'.tr,
                      controller: nameController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                    ),

                    Text(
                      'Email *',
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: 'your@email.com',
                      controller: emailController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                      leading: Icon(
                        Icons.mail,
                        color: Color(0xff99A1AF),
                        size: 20,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    Text(
                      'Phone Number *',
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    MyTextField(
                      hintText: '+1 (555) 000-0000',
                      controller: phoneContrller,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                      leading: Icon(
                        Icons.phone,
                        color: Color(0xff99A1AF),
                        size: 20,
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    Text(
                      'Primary Genre *',
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: '',
                      controller: primaryController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                    ),
                    Text(
                      'Performance Experience *',
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: '',
                      controller: performanceController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                    ),

                    Text(
                      'ba_social'.tr,
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: 'Instagram, Spotify, or website *',
                      controller: socialController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                      leading: Image.asset(
                        'assets/social.png',
                        color: Color(0xff99A1AF),
                        width: 10,
                        height: 10,
                      ),
                    ),

                    Text(
                      'ba_tell_about'.tr,
                      style: TextStyle(
                        color: Color(0xffF4EFE6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    MyTextField(
                      hintText: '',
                      controller: aboutController,
                      hintColor: Get.isDarkMode ? whiteColor : blackColor,
                      maxLines: 5,
                    ),
                    height(0.01),

                    MyButton(
                      label: 'ba_submit_app'.tr,
                      onTap: () {
                        // Pas de faux "chargement" de 3s (friction inutile) :
                        // on enchaîne directement sur l'onboarding artiste.
                        Get.to(() => ArtistOnboardingScreen());
                      },

                      image: 'assets/icon7.png',
                      imageColor: whiteColor,
                      labelColor: whiteColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

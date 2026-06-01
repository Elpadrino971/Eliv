import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
// import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/weating_screen.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? midnightPrimary : scaffoldBackgroundColor,
      body: Column(
        children: [
          MyPage(
            image: 'assets/entry_image.png',

            title: 'home_entry'.tr,
            subTitle: 'home_granted'.tr,
            description: 'home_entry_description'.tr,
            widget: Column(
              children: [
                height(0.03),

                MyContainer(
                  widget: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'home_seat_no'.tr,
                            style: TextStyle(
                              color: Color(0xffA0A0A0),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),

                          Text(
                            'ARENA-V42',
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      height(0.01),

                      Divider(
                        color: greyColor.withValues(alpha: 0.1),
                        thickness: 2,
                      ),

                      height(0.01),
                      Row(
                        children: [
                          Text(
                            'home_pass_type'.tr,
                            style: TextStyle(
                              color: Color(0xffA0A0A0),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          Spacer(),

                          Container(
                            padding: EdgeInsets.all(5),
                            width: Get.width * 0.25,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              textAlign: TextAlign.center,
                              'home_standard'.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: whiteColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                height(0.03),

                MyButton(
                  label: 'home_return_to_home'.tr,
                  onTap: () {
                    Get.to(() => WeatingScreen());
                  },
                  labelColor: whiteColor,

                  image: 'assets/arrow.png',
                  imageHeight: 15,
                  imageWidth: 15,
                  imageColor: whiteColor,
                ),
                height(0.02),

                GestureDetector(
                  onTap: () {
                    // Get.to(() => FutureScreen());
                  },
                  child: Text(
                    'home_return_to_discovery'.tr,
                    style: TextStyle(
                      color: Color(0xffA0A0A0),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

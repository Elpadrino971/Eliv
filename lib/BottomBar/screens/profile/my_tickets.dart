import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class MyTickets extends StatefulWidget {
  const MyTickets({super.key});

  @override
  State<MyTickets> createState() => _MyTicketsState();
}

class _MyTicketsState extends State<MyTickets> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'My Tickets'),

      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            MyContainer(
              widget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            width: Get.width * 0.3,
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Get.isDarkMode ? redColor : mainThemeColor,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              textAlign: TextAlign.center,
                              'ACTIVE PASS',
                              style: TextStyle(
                                color: whiteColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          Text(
                            'Global Stream #2',
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Premium Access',
                            style: TextStyle(
                              color: Color(0xff737373),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Image.asset('assets/image5.png'),
                    ],
                  ),
                  height(0.01),
                  Divider(color: greyColor),

                  Row(
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/date_icon.png',
                            width: 12,
                            color: Color(0xffFF2056),
                          ),
                          width(0.02),
                          Text(
                            'Feb 18, 2026',
                            style: TextStyle(
                              color: Color(0xff737373),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Text(
                            'Watch Now ',
                            style: TextStyle(
                              color: Get.isDarkMode ? redColor : mainThemeColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          width(0.02),
                          Image.asset(
                            'assets/play_icon.png',
                            color: Get.isDarkMode ? redColor : mainThemeColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

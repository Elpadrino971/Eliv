import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.artist});
  final User artist;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height(0.02),

          MyContainer(
            widget: Column(
              children: [
                Text(
                  widget.artist.bio ?? '',
                  style: TextStyle(
                    color: Color(0xff737373),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                height(0.01),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hometown',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          widget.artist.address ?? 'N/A',
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    width(0.04),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Genre',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        (widget.artist.genres ?? []).isEmpty
                            ? Text(
                                'N/A',
                                style: TextStyle(
                                  color: Color(0xff737373),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text(
                                widget.artist.genres?.first.genre ?? 'N/A',
                                style: TextStyle(
                                  color: Color(0xff737373),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          height(0.01),

          Text(
            'Digital Links',
            style: TextStyle(
              color: Get.isDarkMode ? whiteColor : blackColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),

          height(0.01),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: Get.width * 0.15,
                child: MyContainer(
                  widget: Image.asset(
                    'assets/web.png',
                    width: 20,
                    height: 20,
                    color: Get.isDarkMode ? whiteColor : null,
                  ),
                ),
              ),

              SizedBox(
                width: Get.width * 0.15,

                child: MyContainer(
                  widget: Image.asset(
                    'assets/insta.png',
                    width: 20,
                    height: 20,
                    color: Get.isDarkMode ? whiteColor : null,
                  ),
                ),
              ),

              SizedBox(
                width: Get.width * 0.15,
                child: MyContainer(
                  widget: Image.asset(
                    'assets/twiter.png',
                    width: 20,
                    height: 20,
                    color: Get.isDarkMode ? whiteColor : null,
                  ),
                ),
              ),

              SizedBox(
                width: Get.width * 0.15,
                child: MyContainer(
                  widget: Image.asset(
                    'assets/youTube.png',
                    width: 20,
                    height: 20,
                    color: Get.isDarkMode ? whiteColor : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

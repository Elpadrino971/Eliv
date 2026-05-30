import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.image,
    required this.title,
    required this.subTitle,
    required this.description,
    required this.widget,
  });
  final String image;
  final String title;
  final String subTitle;
  final String description;
  final Widget widget;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: myPadding,
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            height(0.08),
            Image.asset(widget.image, width: 60, height: 60),

            height(0.01),

            Text(
              widget.title,
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),

            Text(
              widget.subTitle,
              style: TextStyle(
                color: Color(0xffA0A0A0),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            height(0.01),

            SizedBox(
              width: Get.width * 0.8,
              child: Text(
                textAlign: TextAlign.center,
                widget.description,
                style: TextStyle(
                  color: Color(0xffA0A0A0),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            widget.widget,
          ],
        ),
      ),
    );
  }
}

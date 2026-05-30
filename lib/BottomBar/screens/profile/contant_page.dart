import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContantPage extends StatelessWidget {
  const ContantPage({super.key, required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: title),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),
            if (content.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Text(
                    'No content available.',
                    style: TextStyle(color: greyColor, fontSize: 16),
                  ),
                ),
              )
            else
              Text(
                content,
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontSize: 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w300,
                ),
              ),
            height(0.05),
          ],
        ),
      ),
    );
  }
}

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MyHeader extends StatefulWidget {
  const MyHeader({super.key, this.activeIndex});

  final int? activeIndex;
  @override
  State<MyHeader> createState() => _MyHeaderState();
}

class _MyHeaderState extends State<MyHeader> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              height: Get.height * 0.006,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),

                itemBuilder: (context, index) {
                  return Container(
                    width: 50,
                    height: 3,
                    decoration: BoxDecoration(
                      // color: Color(0xff737373)
                      color: widget.activeIndex == index
                          ? mainThemeColor
                          : Color(0xff737373),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return width(0.02);
                },
                itemCount: 3,
              ),
            ),

            Spacer(),

            GestureDetector(
              onTap: () async {
                await box.write('init', 1);
                Get.to(() => LoginScreen());
              },
              child: Text(
                'Skip',
                style: TextStyle(
                  color: whiteColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

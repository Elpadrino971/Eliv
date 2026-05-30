import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map> notificationList = [
    {
      'image': 'assets/notification1.png',
      'title': 'NeonFan92',
      'date': '2m ago',
      'subTitle': 'sent a \$50 tip during your live stream!',
    },

    {
      'image': 'assets/notification2.png',
      'title': 'Sarah_X',
      'date': '15m ago',
      'subTitle': 'liked your latest tour announcement.',
    },

    {
      'image': 'assets/notification3.png',
      'title': 'The Weeknd',
      'date': '15m ago',
      'subTitle': 'liked your latest tour announcement.',
    },

    {
      'image': 'assets/notification4.png',
      'title': 'System',
      'date': '30m ago',
      'subTitle': 'Your ticket for Utopia Live is now available.',
    },
    {
      'image': 'assets/notification5.png',
      'title': 'RhythmMaster',
      'date': '5h ago',
      'subTitle': 'replied to your comment: "See you there!"',
    },
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Alerts'),

      body: Padding(
        padding: EdgeInsetsGeometry.all(10),
        child: Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.all(0),
              physics: NeverScrollableScrollPhysics(),

              itemBuilder: (context, index) {
                return MyContainer(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  widget: ListTile(
                    contentPadding: EdgeInsets.all(0),
                    leading: Image.asset(
                      notificationList[index]['image'],
                      width: 40,
                      height: 40,
                    ),
                    title: Row(
                      children: [
                        Text(
                          notificationList[index]['title'],
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),

                        Text(
                          notificationList[index]['date'],
                          style: TextStyle(
                            color: greyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      notificationList[index]['subTitle'],
                      style: TextStyle(
                        color: greyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return height(0.01);
              },
              itemCount: notificationList.length,
            ),
          ],
        ),
      ),
    );
  }
}

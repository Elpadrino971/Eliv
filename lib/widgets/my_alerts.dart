import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class MyAlerts extends StatefulWidget {
  const MyAlerts({super.key, required this.text, required this.widget});

  final String text;
  final Widget widget;

  @override
  State<MyAlerts> createState() => _MyAlertsState();
}

class _MyAlertsState extends State<MyAlerts> {
  @override
  Widget build(BuildContext context) {
    return MyContainer(
      widget: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Row(
              children: [
                Text(
                  widget.text,
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                widget.widget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

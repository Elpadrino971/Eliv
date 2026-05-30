import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_alerts.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/state_manager.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool liveStream = false;
  bool announcements = false;
  bool updates = false;
  bool confirmations = false;
  bool payment = false;
  bool earned = false;
  bool followers = false;
  bool comments = false;
  bool mentioned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Alerts'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.02),
              Text(
                'Broadcasting',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              height(0.01),

              MyAlerts(
                text: 'Live Stream Starts',
                widget: Switch(
                  value: liveStream,
                  onChanged: (value) {
                    setState(() {
                      liveStream = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),
              height(0.01),

              MyAlerts(
                text: 'New Tour Announcements',
                widget: Switch(
                  value: announcements,
                  onChanged: (value) {
                    setState(() {
                      announcements = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),

              height(0.01),

              MyAlerts(
                text: 'Artist Updates',
                widget: Switch(
                  value: updates,
                  onChanged: (value) {
                    setState(() {
                      updates = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),

              height(0.02),
              Text(
                'Transactions',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),

              height(0.01),

              MyAlerts(
                text: 'Ticket Confirmations',
                widget: Switch(
                  value: confirmations,
                  onChanged: (value) {
                    setState(() {
                      confirmations = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),

              height(0.01),

              MyAlerts(
                text: 'Payment Success',
                widget: Switch(
                  value: payment,
                  onChanged: (value) {
                    setState(() {
                      payment = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),
              height(0.01),

              MyAlerts(
                text: 'Points Earned',
                widget: Switch(
                  value: earned,
                  onChanged: (value) {
                    setState(() {
                      earned = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),

              height(0.02),

              Text(
                'Social',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),

              height(0.01),

              MyAlerts(
                text: 'New Followers',
                widget: Switch(
                  value: followers,
                  onChanged: (value) {
                    setState(() {
                      followers = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),
              height(0.01),

              MyAlerts(
                text: 'Replies to Comments',
                widget: Switch(
                  value: comments,
                  onChanged: (value) {
                    setState(() {
                      comments = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),
              height(0.01),

              MyAlerts(
                text: 'Mentioned in Clips',
                widget: Switch(
                  value: mentioned,
                  onChanged: (value) {
                    setState(() {
                      mentioned = value;
                    });
                  },

                  inactiveThumbColor: whiteColor,
                  inactiveTrackColor: greyColor,
                  activeTrackColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  activeThumbColor: whiteColor,
                ),
              ),
              height(0.01),
            ],
          ),
        ),
      ),
    );
  }
}

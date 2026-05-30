// import 'package:artist/BottomBar/screens/homeScreen/notification_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: myPadding,
      width: Get.width,
      height: Get.height * 0.47,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background4.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height(0.02),

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: whiteColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: whiteColor.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/location_icon.png',
                    width: 20,
                    height: 20,
                    color: yellowColor,
                  ),
                ),
              ),
              width(0.02),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.artist?.address ?? 'N/A',
                    style: TextStyle(
                      color: whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              Spacer(),

              // GestureDetector(
              //   onTap: () {
              //     Get.to(() => NotificationScreen());
              //   },
              //   child: Container(
              //     padding: EdgeInsets.all(8),
              //     decoration: BoxDecoration(
              //       color: whiteColor.withValues(alpha: 0.1),
              //       borderRadius: BorderRadius.circular(50),
              //       border: Border.all(
              //         color: whiteColor.withValues(alpha: 0.2),
              //       ),
              //     ),
              //     child: Center(
              //       child: Image.asset(
              //         'assets/bell.png',
              //         width: 20,
              //         height: 20,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
          height(0.02),
          (DateTime.now().isAfter(event.startDateTime!) &&
                  DateTime.now().isBefore(event.endDateTime!))
              ? Container(
                  width: Get.width * 0.3,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xffFB2C36),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    textAlign: TextAlign.center,
                    'Live Now',
                    style: TextStyle(
                      color: whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                )
              : height(0.05),
          height(0.01),
          SizedBox(
            width: Get.width * 0.7,
            child: Text(
              event.artist?.fullName ?? 'N/A',
              style: TextStyle(
                color: whiteColor,
                fontWeight: FontWeight.bold,
                fontSize: 23,
                fontFamily: 'Google_Sans',
              ),
            ),
          ),

          Text(
            event.name ?? 'N/A',
            style: TextStyle(
              color: yellowColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          height(0.01),

          Text(
            event.description ?? 'N/A',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textXolor,
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),

          height(0.02),

          SizedBox(
            width: Get.width,
            child: MyButton(
              label: 'Join Now',
              onTap: () {
                // Get.to(() => Future_screen());
                Get.to(() => CheckOutScreen(event: event));
              },
              image: 'assets/play_icon.png',
              imageColor: whiteColor,

              imageWidth: 10,
            ),
          ),
        ],
      ),
    );
  }
}

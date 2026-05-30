import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveEventsCards extends StatelessWidget {
  const LiveEventsCards({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(() => FutureScreen(event: event));
      },
      child: Container(
        width: Get.width * 0.8,
        padding: myPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: NetworkImage('${APIs.eventImageIP}/${event.coverImage}'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: [
                    Container(
                      width: Get.width * 0.23,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xffDD0000),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/dots.png'),
                          width(0.02),
                          Text(
                            textAlign: TextAlign.center,
                            'Live',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    width(0.02),
                    Container(
                      // width: Get.width * 0.16,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: whiteColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        textAlign: TextAlign.center,
                        event.genre?.genre?.capitalize ?? 'N/A',
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(),

                Text(
                  '\$${event.ticketPrice}',
                  style: TextStyle(
                    color: whiteColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            height(0.042),

            Row(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipOval(
                      child: ImageWidget(
                        url: '${event.artist?.profileImage}',
                        height: 30,
                        width: 30,
                      ),
                    ),
                    width(0.02),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: Get.width * 0.38,
                          child: Text(
                            event.name?.capitalize ?? 'N/A',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        height(0.001),
                        Text(
                          event.artist?.artistName ?? 'N/A',
                          style: TextStyle(
                            color: Color(0xffFFCCD3),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Spacer(),

                GestureDetector(
                  onTap: () {
                    Get.to(() => CheckOutScreen(event: event));
                  },
                  child: Container(
                    width: Get.width * 0.23,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: mainThemeColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      textAlign: TextAlign.center,
                      'Join live',
                      style: TextStyle(
                        color: blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

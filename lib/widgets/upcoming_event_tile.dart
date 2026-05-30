import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class UpcomingEventTile extends StatelessWidget {
  const UpcomingEventTile({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return MyContainer(
      padding: EdgeInsets.only(left: 10, right: 10),
      widget: ListTile(
        onTap: () {
          Get.to(() => FutureScreen(event: event));
        },
        contentPadding: EdgeInsets.all(0),
        titleAlignment: ListTileTitleAlignment.top,
        leading: ClipRRect(
          borderRadius: BorderRadiusGeometry.circular(10),
          child: ImageWidget(
            url: '${APIs.eventImageIP}/${event.coverImage}',
            height: 60,
            width: 60,
            fit: BoxFit.cover,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.artist?.artistName?.capitalize ?? 'N/A',
              style: TextStyle(
                color: Color(0xff626262),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              width: Get.width * 0.5,
              child: Text(
                event.name?.capitalize ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xff626262),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Row(
              children: [
                Row(
                  children: [
                    Image.asset('assets/date_icon.png', width: 12),
                    width(0.01),
                    Text(
                      DateFormat(
                        'MMM dd',
                      ).format(event.startDateTime ?? DateTime.now()),
                      style: TextStyle(
                        color: textXolor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                width(0.02),

                Row(
                  children: [
                    Image.asset('assets/clock_icon.png', width: 12),
                    width(0.01),
                    Text(
                      DateFormat(
                        'hh:mm a',
                      ).format(event.startDateTime ?? DateTime.now()),
                      style: TextStyle(
                        color: textXolor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          // width: Get.width * 0.12,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Get.isDarkMode ? Color(0xff7A0709) : mainThemeColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            textAlign: TextAlign.center,
            '\$${event.ticketPrice}',
            style: TextStyle(
              color: Get.isDarkMode ? whiteColor : blackColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

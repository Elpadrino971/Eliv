import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class MyCard extends StatefulWidget {
  const MyCard({
    super.key,
    this.inPurchased = false,
    this.isNothing = false,
    required this.event,
  });

  final bool inPurchased;
  final bool isNothing;
  final Event event;

  @override
  State<MyCard> createState() => _MyCardState();
}

class _MyCardState extends State<MyCard> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: Get.width,
          height: Get.height * 0.25,
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                '${APIs.eventImageIP}/${widget.event.coverImage}',
              ),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(20),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.isNothing
                      ? SizedBox.shrink()
                      : widget.inPurchased
                      ? Container(
                          padding: EdgeInsets.only(
                            top: 5,
                            bottom: 5,
                            left: 9,
                            right: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xff00C950),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            'PURCHASED',
                            style: TextStyle(
                              color: whiteColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : widget.event.status == 'live'
                      ? Container(
                          padding: EdgeInsets.only(
                            top: 5,
                            bottom: 5,
                            left: 9,
                            right: 9,
                          ),
                          decoration: BoxDecoration(
                            color: liveRed,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            'LIVE NOW',
                            style: TextStyle(
                              color: whiteColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : SizedBox.shrink(),

                  height(0.01),
                ],
              ),
              Spacer(),
              Row(
                children: [
                  ClipOval(
                    child: ImageWidget(
                      url:
                          widget.event.artist?.artistProfile ??
                          '${APIs.profileIP}/default.png',
                      width: 40,
                      height: 40,
                    ),
                  ),

                  width(0.01),
                  Text(
                    widget.event.artist?.artistName ?? 'N/A',
                    style: TextStyle(fontSize: 13, color: whiteColor),
                  ),
                  width(0.01),

                  Image.asset('assets/check.png'),
                ],
              ),

              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: Get.width * 0.6,
                        child: Text(
                          widget.event.name ?? 'N/A',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      Row(
                        children: [
                          Text(
                            'Today',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),

                          width(0.02),

                          Row(
                            children: [
                              Image.asset(
                                'assets/clock_icon.png',
                                width: 12,
                                color: whiteColor,
                              ),
                              width(0.02),
                              Text(
                                DateFormat(
                                  'hh:mm a',
                                ).format(widget.event.startDateTime!),
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

                  Spacer(),

                  widget.isNothing
                      ? SizedBox.shrink()
                      : widget.inPurchased
                      ? Container(
                          padding: EdgeInsets.only(
                            top: 7,
                            bottom: 7,
                            left: 10,
                            right: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mainThemeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Image.asset('assets/play.png'),
                              width(0.01),
                              Text(
                                'Join Arena',
                                style: TextStyle(
                                  color: midnightPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: EdgeInsets.only(
                            top: 7,
                            bottom: 7,
                            left: 10,
                            right: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '\$${widget.event.ticketPrice}',
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

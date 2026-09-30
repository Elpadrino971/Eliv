import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/live_router.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LivePerformanceScreen extends StatefulWidget {
  const LivePerformanceScreen({super.key, required this.events});
  final List<Event> events;

  @override
  State<LivePerformanceScreen> createState() => _LivePerformanceScreenState();
}

class _LivePerformanceScreenState extends State<LivePerformanceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'home_live_performance_title'.tr),

      body: widget.events.isEmpty
          ? Center(child: Text('no_live_events'.tr))
          : SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            children: [
              height(0.01),
              ListView.separated(
                      separatorBuilder: (context, index) => height(0.01),
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: widget.events.length,
                      itemBuilder: (context, index) {
                        final event = widget.events[index];
                        return GestureDetector(
                          onTap: () {
                            Get.to(() => FutureScreen(event: event));
                          },
                          child: Container(
                            padding: myPadding,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(
                                  '${APIs.eventImageIP}/${event.coverImage}',
                                ),
                                fit: BoxFit.fill,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.only(
                                            top: 5,
                                            bottom: 5,
                                            left: 9,
                                            right: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: liveRed,
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: Text(
                                            'live_now'.tr,
                                            style: TextStyle(
                                              color: whiteColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),

                                        height(0.01),

                                        Container(
                                          padding: EdgeInsets.only(
                                            top: 5,
                                            bottom: 5,
                                            left: 9,
                                            right: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: whiteColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: Text(
                                            event.genre?.genre?.capitalize ??
                                                'N/A',
                                            style: TextStyle(
                                              color: whiteColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Spacer(),

                                    Container(
                                      padding: EdgeInsets.only(
                                        top: 5,
                                        bottom: 5,
                                        left: 9,
                                        right: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: mainThemeColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        priceLabel(event.ticketPrice),
                                        style: TextStyle(
                                          color: ivory,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                height(0.01),
                                Row(
                                  children: [
                                    ClipOval(
                                      child: ImageWidget(
                                        url: '${event.artist?.artistProfile}',
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),

                                    width(0.015),
                                    Text(
                                      event.artist?.artistName ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: greyColor,
                                      ),
                                    ),
                                    width(0.01),

                                    event.artist?.isVerified == 1
                                        ? Image.asset('assets/check.png')
                                        : SizedBox.shrink(),
                                  ],
                                ),
                                height(0.01),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: Get.width * 0.6,
                                          child: Text(
                                            event.name?.capitalize ?? 'N/A',
                                            maxLines: 1,
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
                                              'home_today'.tr,
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
                                                  AppDate.format(
                                                    event.startDateTime,
                                                    'hh:mm a',
                                                  ),
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

                                    GestureDetector(
                                      onTap: () {
                                        joinLive(event);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.only(
                                          top: 7,
                                          bottom: 7,
                                          left: 10,
                                          right: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mainThemeColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Image.asset('assets/play.png'),
                                            width(0.01),
                                            Text(
                                              'join_live'.tr,
                                              style: TextStyle(
                                                color: ivory,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

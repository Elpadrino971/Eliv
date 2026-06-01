import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/shimmer_loaders.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final eventController = Get.find<EventController>();

  Future myInitMethod() async {
    await eventController.getEventHistory();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'History'),
      body: Padding(
        padding: myPadding,
        child: GetBuilder<EventController>(
          builder: (controller) {
            final eventHistory = controller.eventHistory.value.data;
            if (eventHistory == null) {
              return Center(child: EventTileShimmer());
            }
            if (eventHistory.isEmpty) {
              return Center(child: Text('empty_no_history'.tr));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height(0.01),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calculateTotalWatchTime(eventHistory),
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Hours Watched',
                          style: TextStyle(
                            color: greyColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Image.asset('assets/icon6.png', width: 45, height: 45),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        height(0.02),
                        Text(
                          'Recent Streams',
                          style: TextStyle(
                            color: greyColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),

                        height(0.02),
                        ListView.separated(
                          separatorBuilder: (context, index) {
                            return height(0.01);
                          },
                          itemCount: eventHistory.length,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.all(0),
                          itemBuilder: (context, index) {
                            final event = eventHistory[index];
                            return GestureDetector(
                              onTap: () {
                                // Get.to(() => PaymentScreen());
                              },
                              child: MyContainer(
                                widget: ListTile(
                                  contentPadding: EdgeInsets.all(0),
                                  leading: ClipOval(
                                    child: ImageWidget(
                                      url:
                                          '${APIs.eventImageIP}/${event.coverImage}',
                                      width: 50,
                                      height: 50,
                                    ),
                                  ),
                                  title: Text(
                                    event.name ?? 'N/A',
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Row(
                                        children: [
                                          Image.asset(
                                            'assets/profile.png',
                                            width: 15,
                                            height: 15,
                                            color: greyColor,
                                          ),
                                          width(0.01),

                                          SizedBox(
                                            width: Get.width * 0.25,
                                            child: Text(
                                              event.artist?.artistName ?? 'N/A',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: greyColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      width(0.02),

                                      Row(
                                        children: [
                                          Image.asset(
                                            'assets/clock.png',
                                            width: 15,
                                            height: 15,
                                            color: greyColor,
                                          ),
                                          width(0.01),

                                          Text(
                                            calculateEventDuration(
                                              event.startDateTime ??
                                                  DateTime.now(),
                                              event.endDateTime ??
                                                  DateTime.now(),
                                            ),
                                            style: TextStyle(
                                              color: greyColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Color(0xffEDEDED),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'MMM dd',
                                          ).format(event.startDateTime!),
                                        ),
                                      ),
                                      height(0.01),
                                      // Container(
                                      //   // width: 23,
                                      //   // height: 23,
                                      //   padding: EdgeInsets.all(4.5),
                                      //   decoration: BoxDecoration(
                                      //     color: whiteColor,
                                      //     borderRadius: BorderRadius.circular(
                                      //       50,
                                      //     ),
                                      //     border: Border.all(color: greyColor),
                                      //   ),
                                      //   child: Image.asset('assets/play.png'),
                                      // ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

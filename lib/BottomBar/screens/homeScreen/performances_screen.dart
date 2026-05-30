import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
// import 'package:artist/BottomBar/screens/homeScreen/live_performance_screen.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class PerformancesScreen extends StatefulWidget {
  const PerformancesScreen({
    super.key,
    required this.events,
    required this.title,
  });
  final List<Event> events;
  final String title;

  @override
  State<PerformancesScreen> createState() => _PerformancesScreenState();
}

class _PerformancesScreenState extends State<PerformancesScreen> {
  var like2 = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: widget.title),
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            widget.events.isEmpty
                ? Center(child: Text('No Next Events Available'))
                : Expanded(
                    child: ListView.separated(
                      separatorBuilder: (context, index) => height(0.01),
                      itemCount: widget.events.length,
                      itemBuilder: (context, index) {
                        final event = widget.events[index];
                        return GestureDetector(
                          onTap: () {
                            Get.to(() => FutureScreen(event: event));
                          },
                          child: MyContainer(
                            widget: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ImageWidget(
                                        url:
                                            '${APIs.eventImageIP}/${event.coverImage}',
                                        width: 60,
                                        height: 60,
                                      ),
                                    ),

                                    width(0.03),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MyContainer(
                                          padding: EdgeInsets.only(
                                            top: 5,
                                            bottom: 5,
                                            right: 8,
                                            left: 8,
                                          ),
                                          noWidth: true,
                                          widget: Text(
                                            event.genre?.genre?.capitalize ??
                                                'No Genre',
                                            style: TextStyle(
                                              color: greyColor,
                                              fontWeight: FontWeight.w400,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),

                                        SizedBox(
                                          width: Get.width * 0.5,
                                          child: Text(
                                            event.name?.capitalize ?? 'No Name',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: ivory,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),

                                        Text(
                                          event
                                                  .artist
                                                  ?.artistName
                                                  ?.capitalize ??
                                              'No Artist',
                                          style: TextStyle(
                                            color: greyColor,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Image.asset(
                                              'assets/clock_icon.png',
                                              width: 12,
                                            ),
                                            width(0.01),
                                            Text(
                                              DateFormat(
                                                'hh:mm a',
                                              ).format(event.startDateTime!),
                                              style: TextStyle(
                                                color: textXolor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        height(0.01),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Image.asset(
                                              'assets/location_icon.png',
                                              width: 12,
                                              color: greyColor,
                                            ),
                                            width(0.01),
                                            Text(
                                              event.artist?.address ??
                                                  'No Address',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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

                                    Spacer(),
                                    Image.asset(
                                      like2
                                          ? 'assets/fill_icon.png'
                                          : 'assets/heart.png',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ],
                                ),
                                height(0.01),
                                Row(
                                  children: [
                                    Image.asset('assets/image6.png'),
                                    width(0.02),

                                    Text(
                                      '\$${event.ticketPrice ?? '0.0'}',
                                      style: TextStyle(
                                        color: ivory,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    Spacer(),

                                    SizedBox(
                                      width: Get.width * 0.4,
                                      child: MyButton(
                                        label: 'Get Tickets',
                                        onTap: () {
                                          Get.to(
                                            () => CheckOutScreen(event: event),
                                          );
                                        },
                                        image: 'assets/arrow3.png',
                                        imageHeight: 12,
                                        imageWidth: 12,

                                        imageColor: whiteColor,
                                        labelColor: whiteColor,
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
                  ),
          ],
        ),
      ),
    );
  }
}

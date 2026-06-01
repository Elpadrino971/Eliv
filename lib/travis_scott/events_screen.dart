import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/Models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:artist/Global/app_date.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.events});
  final List<Event> events;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height(0.01),

          // Row(
          //   children: [
          //     Text(
          //       'Live Experience',
          //       style: TextStyle(
          //         color: ivory,
          //         fontSize: 15,
          //         fontWeight: FontWeight.bold,
          //       ),
          //     ),

          //     Spacer(),

          //     SizedBox(
          //       width: Get.width * 0.4,
          //       child: Container(
          //         padding: EdgeInsets.all(5),
          //         decoration: BoxDecoration(
          //           color: Color(0xffEC001E),
          //           borderRadius: BorderRadius.circular(10),
          //         ),
          //         child: Text(
          //           'Live Broadcast',
          //           textAlign: TextAlign.center,
          //           style: TextStyle(
          //             color: whiteColor,
          //             fontWeight: FontWeight.bold,
          //             fontSize: 15,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          // height(0.01),
          // ListTile(
          //   contentPadding: EdgeInsets.all(0),
          //   leading: ClipOval(
          //     child: Image.asset(
          //       'assets/artist_image2.png',
          //       width: 50,
          //       height: 50,
          //     ),
          //   ),

          //   title: Text(
          //     'Private Arena Access',

          //     style: TextStyle(
          //       color: mainThemeColor,
          //       fontWeight: FontWeight.bold,
          //       fontSize: 13,
          //     ),
          //   ),
          //   subtitle: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(
          //         'The After Hours Tour',

          //         style: TextStyle(
          //           color: ivory,
          //           fontWeight: FontWeight.bold,
          //           fontSize: 15,
          //         ),
          //       ),
          //       Text(
          //         '\$29.99',

          //         style: TextStyle(
          //           color: mainThemeColor,
          //           fontWeight: FontWeight.bold,
          //           fontSize: 13,
          //         ),
          //       ),
          //     ],
          //   ),
          //   trailing: Image.asset('assets/stop.png', width: 30, height: 30),
          // ),
          Text(
            'Events Schedule',
            style: TextStyle(
              color: ivory,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          height(0.01),

          widget.events.isEmpty
              ? Center(child: Text('No Events Found'))
              : Expanded(
                  child: ListView.separated(
                    separatorBuilder: (context, index) => height(0.01),
                    padding: EdgeInsets.zero,
                    itemCount: widget.events.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final event = widget.events[index];
                      return MyContainer(
                        padding: EdgeInsets.all(10),
                        widget: ListTile(
                          minTileHeight: 0,
                          contentPadding: EdgeInsets.all(0),
                          leading: Container(
                            width: 45,
                            height: 50,
                            decoration: BoxDecoration(
                              color: whiteColor,
                              border: Border.all(color: greyColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppDate.format(
                                    event.startDateTime ?? DateTime.now(),
                                    'MMM',
                                  ),
                                  style: TextStyle(
                                    color: goldPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  AppDate.format(
                                    event.startDateTime ?? DateTime.now(),
                                    'dd',
                                  ),
                                  style: TextStyle(
                                    color: blackColor.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name ?? 'N/A',

                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : blackColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                event.artist?.artistName ?? 'N/A',

                                style: TextStyle(
                                  color: Color(0xff737373),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                          trailing: GestureDetector(
                            onTap: () {
                              Get.to(() => FutureScreen(event: event));
                            },
                            child: Container(
                              width: Get.width * 0.3,
                              padding: myPadding,
                              decoration: BoxDecoration(
                                color: Get.isDarkMode
                                    ? goldPrimary
                                    : mainThemeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Tickets',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: whiteColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

          height(0.01),
        ],
      ),
    );
  }
}

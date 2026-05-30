import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
// import 'package:artist/BottomBar/screens/my_tIckets/live_tickets_video_screen.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen>
    with SingleTickerProviderStateMixin {
  final eventController = Get.find<EventController>();

  late TabController tabController;

  Future myInitMethod() async {
    tabController = TabController(length: 2, vsync: this);
    await eventController.getUserJoinedEvents();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Tickets'),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),

            Text(
              'MY TICKETS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Get.isDarkMode ? whiteColor : blackColor,
              ),
            ),

            height(0.01),

            MyTabBar(
              tabController: tabController,
              tabOne: 'UPCOMING',
              tabTwo: 'PAST EVENTS',
            ),

            height(0.01),

            GetBuilder<EventController>(
              builder: (controller) {
                final events = controller.userJoinedEvents.value.data;
                if (events == null) {
                  return const EventTileShimmer();
                }
                final upcomingEvents = events
                    .where((e) => e.status == 'published' || e.status == 'live')
                    .toList();
                final pastEvents = events
                    .where(
                      (e) => e.status == 'completed' || e.status == 'cancelled',
                    )
                    .toList();
                return Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      /// Upcoming Events
                      upcomingEvents.isEmpty
                          ? Center(child: Text('No Upcoming Events'))
                          : ListView.separated(
                              separatorBuilder: (context, index) {
                                return height(0.01);
                              },
                              itemCount: upcomingEvents.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.all(0),

                              itemBuilder: (context, index) {
                                final event = upcomingEvents[index];
                                return GestureDetector(
                                  onTap: () {
                                    // if (event.status == 'live') {
                                    //   Get.to(() => JoinStream(event: event));
                                    // } else {
                                    Get.to(() => FutureScreen(event: event));
                                    // }
                                    // Get.to(() => ArtistBasicInfo());
                                  },
                                  child: MyCard(event: event),
                                );
                              },
                            ),

                      /// Past Events
                      pastEvents.isEmpty
                          ? Center(child: Text('No Past Events'))
                          : ListView.separated(
                              separatorBuilder: (context, index) {
                                return height(0.01);
                              },
                              itemCount: pastEvents.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.all(0),

                              itemBuilder: (context, index) {
                                final event = pastEvents[index];
                                return MyCard(isNothing: true, event: event);
                              },
                            ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
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
                          ? EmptyState(
                              icon: Icons.confirmation_number_outlined,
                              title: 'No upcoming tickets yet',
                              subtitle:
                                  'Your next concert pass will appear here. '
                                  'Discover live shows and grab your seat.',
                              actionLabel: 'Explore Concerts',
                              onAction: () =>
                                  Get.offAll(() => const MyBottomBar(index: 1)),
                            )
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
                          ? const EmptyState(
                              icon: Icons.history_rounded,
                              title: 'No past events',
                              subtitle:
                                  'Concerts you\'ve attended will be kept here '
                                  'so you can relive every moment.',
                            )
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

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
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
      appBar: MyAppbar(title: 'tk_tickets'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),

            Text(
              'my_tickets_title'.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Get.isDarkMode ? whiteColor : blackColor,
              ),
            ),

            height(0.01),

            MyTabBar(
              tabController: tabController,
              tabOne: 'tk_upcoming'.tr,
              tabTwo: 'tk_past_events'.tr,
            ),

            height(0.01),

            GetBuilder<EventController>(
              builder: (controller) {
                final events = controller.userJoinedEvents.value.data;
                if (events == null) {
                  return const EventTileShimmer();
                }
                // « postponed » reste à venir ; « ended » (live terminé) va
                // dans l'historique — avant, ces billets disparaissaient.
                final upcomingEvents = events
                    .where(
                      (e) =>
                          e.status == 'published' ||
                          e.status == 'live' ||
                          e.status == 'postponed',
                    )
                    .toList();
                final pastEvents = events
                    .where(
                      (e) =>
                          e.status == 'completed' ||
                          e.status == 'cancelled' ||
                          e.status == 'ended',
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
                              title: 'empty_no_tickets_t'.tr,
                              subtitle: 'empty_no_tickets_s'.tr,
                              actionLabel: 'empty_explore_concerts'.tr,
                              onAction: () => Get.offAll(
                                () => const MyBottomBar(index: 1),
                              ),
                            )
                          : ListView.separated(
                              separatorBuilder: (context, index) {
                                return height(0.018);
                              },
                              itemCount: upcomingEvents.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.all(0),

                              itemBuilder: (context, index) {
                                final event = upcomingEvents[index];
                                return GestureDetector(
                                  onTap: () {
                                    Get.to(() => FutureScreen(event: event));
                                  },
                                  child: TicketPassCard(event: event),
                                );
                              },
                            ),

                      /// Past Events
                      pastEvents.isEmpty
                          ? EmptyState(
                              icon: Icons.history_rounded,
                              title: 'empty_no_past_t'.tr,
                              subtitle: 'empty_no_past_s'.tr,
                            )
                          : ListView.separated(
                              separatorBuilder: (context, index) {
                                return height(0.018);
                              },
                              itemCount: pastEvents.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.all(0),

                              itemBuilder: (context, index) {
                                final event = pastEvents[index];
                                return TicketPassCard(
                                  event: event,
                                  isPast: true,
                                );
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

import 'dart:async';

import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_chat_tab.dart';
import 'package:artist/artist_bottom_bar/screen/Events/artist_tips_tab.dart';
import 'package:artist/widgets/my_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ArtistLiveEventChat extends StatefulWidget {
  const ArtistLiveEventChat({super.key, required this.event});
  final Event event;

  @override
  State<ArtistLiveEventChat> createState() => _ArtistLiveEventChatState();
}

class _ArtistLiveEventChatState extends State<ArtistLiveEventChat>
    with SingleTickerProviderStateMixin {
  final eventController = Get.find<EventController>();
  late TabController tabController;
  late Event currentEvent;
  Timer? _timer;

  Future myInitMethod() async {
    currentEvent = widget.event;
    final data = await eventController.getEventLogs(
      eventId: widget.event.id.toString(),
    );
    if (mounted) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: data);
      });
    }
    await eventController.getGifts();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        final data = await eventController.getEventLogs(
          eventId: widget.event.id.toString(),
        );
        setState(() {
          currentEvent = currentEvent.copyWith(activities: data);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    myInitMethod();
  }

  @override
  void dispose() {
    tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: ListTile(
          contentPadding: EdgeInsets.all(0),
          leading: GestureDetector(
            onTap: Get.back,
            child: Image.asset('assets/cros_icon.png', width: 20),
          ),
          title: Text(
            currentEvent.name?.capitalize ?? 'Live Event',
            style: TextStyle(
              color: Get.isDarkMode ? whiteColor : blackColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Row(
            children: [
              Image.asset('assets/dots.png', color: Color(0xffB80000)),
              width(0.02),
              Text(
                'Live',
                style: TextStyle(
                  color: Color(0xffB80000),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // trailing: GestureDetector(
          //   onTap: () {
          //     Get.back();
          //   },
          //   child: Image.asset('assets/end_image.png', width: 60, height: 60),
          // ),
        ),
      ),

      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MyTabBar(
              tabController: tabController,
              tabOne: 'Chat',
              tabTwo: 'Gift',
            ),

            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  ArtistChatScreen(
                    activities: currentEvent.activities ?? [],
                    eventId: currentEvent.id.toString(),
                  ),
                  ArtistTipsScreen(activities: currentEvent.activities ?? []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

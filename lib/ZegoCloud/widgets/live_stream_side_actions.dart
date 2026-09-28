import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/artist_bottom_bar/screen/Events/artist_live_event_chat.dart';
import 'package:artist/artist_bottom_bar/screen/Events/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveStreamSideActions extends StatelessWidget {
  const LiveStreamSideActions({
    super.key,
    required this.onGiftTap,
    required this.onHeartTap,
    required this.event,
    required this.activities,
    this.fromArtist = false,
  });

  final VoidCallback onGiftTap;
  final VoidCallback onHeartTap;
  final Event event;
  final bool fromArtist;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        fromArtist
            ? SizedBox()
            : GestureDetector(
                onTap: onHeartTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.pink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
        height(0.02),
        GestureDetector(
          onTap: () {
            Get.to(() => ArtistLiveEventChat(event: event));
          },
          child: Image.asset('assets/chat_icon.png', width: 50),
        ),
        height(0.02),
        fromArtist
            ? SizedBox()
            : GestureDetector(
                onTap: onGiftTap,
                child: Image.asset('assets/gift_icon.png', width: 50),
              ),
        fromArtist ? SizedBox() : height(0.02),

        !fromArtist
            ? SizedBox()
            : GestureDetector(
                onTap: () {
                  Get.to(
                    () => StatsScreen(event: event, activities: activities),
                  );
                },
                child: Image.asset('assets/chart_icon1.png', width: 50),
              ),
        !fromArtist ? SizedBox() : height(0.02),
        GestureDetector(
          onTap: () => myShare(
            message: 'share_live_message'.trParams({
              'name': event.name?.capitalize ?? 'VybzzZ',
            }),
          ),
          child: Image.asset('assets/share_icon.png', width: 50),
        ),
        height(0.02),
        // Image.asset('assets/show_icon.png', width: 50),
      ],
    );
  }
}

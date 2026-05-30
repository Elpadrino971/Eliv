import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class VybzLiveScreen extends StatefulWidget {
  const VybzLiveScreen({super.key});

  @override
  State<VybzLiveScreen> createState() => _VybzLiveScreenState();
}

class _VybzLiveScreenState extends State<VybzLiveScreen> {
  final eventController = Get.find<EventController>();

  @override
  void initState() {
    super.initState();
    final events = eventController.allEvents.value.data ?? [];
    if (events.isNotEmpty &&
        events[0].videoReel != null &&
        events[0].videoReel!.isNotEmpty) {
      eventController.initVideoPlayer(events[0].videoReel!);
    }
  }

  @override
  void dispose() {
    eventController.disposeVideoController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final events = eventController.allEvents.value.data ?? [];
        return events.isEmpty
            ? Center(child: Text('No Reel Available'))
            : PageView.builder(
                scrollDirection: Axis.vertical,
                onPageChanged: eventController.onPageChanged,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return GetBuilder<EventController>(
                    builder: (controller) {
                      final videoController =
                          controller.currentController.value;

                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: controller.toggleVideoControls,
                            child: Container(
                              width: Get.width,
                              height: Get.height,
                              color: blackColor,
                              child:
                                  videoController != null &&
                                      videoController.value.isInitialized
                                  ? Center(
                                      child: AspectRatio(
                                        aspectRatio:
                                            videoController.value.aspectRatio,
                                        child: VideoPlayer(videoController),
                                      ),
                                    )
                                  : Center(
                                      child: CircularProgressIndicator(
                                        color: mainThemeColor,
                                      ),
                                    ),
                            ),
                          ),
                          if (controller.showVideoControls.value &&
                              videoController != null)
                            Positioned.fill(
                              child: Container(
                                color: blackColor.withValues(alpha: 0.3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.replay_5,
                                        color: whiteColor,
                                        size: 40,
                                      ),
                                      onPressed: () => controller.seekVideo(-5),
                                    ),
                                    width(0.05),
                                    IconButton(
                                      icon: Icon(
                                        videoController.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled,
                                        color: whiteColor,
                                        size: 60,
                                      ),
                                      onPressed: () =>
                                          controller.playPauseVideo(),
                                    ),
                                    width(0.05),
                                    IconButton(
                                      icon: Icon(
                                        Icons.forward_5,
                                        color: whiteColor,
                                        size: 40,
                                      ),
                                      onPressed: () => controller.seekVideo(5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            padding: myPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                height(0.03),
                                Row(
                                  children: [
                                    Text(
                                      'VYBZ',
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    width(0.01),
                                    Text(
                                      'Originals',
                                      style: TextStyle(
                                        color: greyColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Spacer(),
                                    GestureDetector(
                                      onTap: controller.toggleMute,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: whiteColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                        ),
                                        child: Icon(
                                          controller.isMuted.value
                                              ? Icons.volume_off
                                              : Icons.volume_up,
                                          color: whiteColor,
                                          size: 25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                height(0.01),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Padding(
                              padding: myPadding,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Get.to(
                                            () => ArtistDetailScreen(
                                              artist: event.artist!,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          '@${event.artist?.artistName?.capitalize ?? 'N/A'}',
                                          style: TextStyle(
                                            color: whiteColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      width(0.01),
                                      ((event.artist?.isVerified ?? 0) == 1)
                                          ? Image.asset(
                                              'assets/check_icon2.png',
                                              width: 15,
                                            )
                                          : SizedBox(),
                                    ],
                                  ),
                                  height(0.01),
                                  SizedBox(
                                    width: Get.width * 0.5,
                                    child: Text(
                                      event.name?.capitalize ?? 'N/A',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  height(0.01),
                                  SizedBox(
                                    width: Get.width * 0.6,
                                    child: MyButton(
                                      label: 'Join Live ',
                                      onTap: () {
                                        Get.to(
                                          () => FutureScreen(event: event),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
      }),
    );
  }
}

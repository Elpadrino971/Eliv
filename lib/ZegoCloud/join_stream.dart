// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/Animation/heart_animation.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_side_actions.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_top_bar.dart';
import 'package:artist/ZegoCloud/zego_cloud_keys.dart';
import 'package:artist/ZegoCloud/zego_controller.dart';
import 'package:artist/ZegoCloud/zego_gifts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class JoinStream extends StatefulWidget {
  const JoinStream({super.key, required this.event});
  final Event event;

  @override
  State<JoinStream> createState() => _JoinStreamState();
}

class _JoinStreamState extends State<JoinStream> {
  final ZegoController zegoController = Get.put(ZegoController());
  final EventController eventController = Get.put(EventController());
  late Event currentEvent;
  final TextEditingController commentController = TextEditingController();
  StreamSubscription? _commandSubscription;

  Future myInitMethod() async {
    await eventController.getAbusiveWords();
    currentEvent = widget.event;
    final data = await eventController.getEventLogs(
      eventId: widget.event.id.toString(),
    );
    currentEvent = currentEvent.copyWith(activities: data);
    setState(() {});
    await eventController.getGifts();
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        final data = await eventController.getEventLogs(
          eventId: widget.event.id.toString(),
        );
        currentEvent = currentEvent.copyWith(activities: data);
        setState(() {});
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();

    // Listen for in-room commands (likes, gifts, etc.)
    _commandSubscription = ZegoUIKit().getInRoomCommandReceivedStream().listen(
      _onInRoomCommandReceived,
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    _commandSubscription?.cancel();
    super.dispose();
  }

  final GlobalKey<HeartAnimationOverlayState> _heartKey =
      GlobalKey<HeartAnimationOverlayState>();

  Future<void> _sendComment({String? text}) async {
    final String comment = text ?? commentController.text.trim();
    if (comment.isEmpty) return;

    if (eventController.hasAbusiveWords(comment)) {
      myWarningDialog(subtitle: 'Your comment contains restricted words.');
      return;
    }

    if (text == null) {
      commentController.clear();
      // 1. Send via Zego for real-time display to other live users
      zegoController.sendMessage(comment);
    }

    // 2. Also persist comment on server and update local event state
    final updatedEvent = await eventController.getEventComments(
      eventId: currentEvent.id.toString(),
      comment: comment,
    );

    if (updatedEvent != null && mounted) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: updatedEvent);
      });
    }
  }

  void _onInRoomCommandReceived(ZegoInRoomCommandReceivedData data) {
    if (data.command == 'like') {
      _heartKey.currentState?.addHeart();
    } else if (data.command.startsWith('gift:')) {
      final parts = data.command.split(':');
      if (parts.length >= 3) {
        final giftName = parts[1];
        final giftImage = parts[2];
        GiftAnimationManager.showGiftAnimation(
          context: context,
          giftImagePath: giftImage,
          giftName: giftName,
          userName: data.fromUser.name,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Zego Live Streaming Background ──────────────────────────
          ZegoUIKitPrebuiltLiveStreaming(
            appID: ZegoCloudKeys.appId,
            appSign: ZegoCloudKeys.appSign,
            userID: zegoController.userId,
            userName: zegoController.userName,
            liveID: currentEvent.id.toString(),
            config: _buildZegoConfig(),
            events: ZegoUIKitPrebuiltLiveStreamingEvents(
              inRoomMessage: ZegoLiveStreamingInRoomMessageEvents(
                onLocalSend: (ZegoInRoomMessage message) {
                  _sendComment(text: message.message);
                },
              ),
            ),
          ),

          // ── Animations Layer ─────────────────────────────────────────
          IgnorePointer(child: HeartAnimationOverlay(key: _heartKey)),

          // ── Custom Overlay UI ────────────────────────────────────────
          _buildOverlayUI(),
        ],
      ),
    );
  }

  ZegoUIKitPrebuiltLiveStreamingConfig _buildZegoConfig() {
    return ZegoUIKitPrebuiltLiveStreamingConfig.audience()
      ..inRoomMessage.visible = false
      ..audioVideoViewConfig.useVideoViewAspectFill = true
      ..inRoomMessageConfig = ZegoInRoomMessageConfig(visible: false)
      ..topMenuBarConfig = ZegoTopMenuBarConfig(buttons: []);
  }

  Widget _buildOverlayUI() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Bar
          Padding(
            padding: myPadding,
            child: LiveStreamTopBar(event: currentEvent),
          ),

          const Spacer(),

          // Bottom Chat + Actions
          Padding(
            padding: myPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Live chat feed (Zego real-time messages)
                    Expanded(
                      child: LiveStreamChatPreview(
                        messages: currentEvent.activities ?? [],
                      ),
                    ),

                    const SizedBox(width: 8),
                    // Right action buttons
                    LiveStreamSideActions(
                      event: currentEvent,
                      activities: currentEvent.activities ?? [],
                      onGiftTap: () {
                        Get.bottomSheet(
                          ZegoGifts(
                            eventId: currentEvent.id.toString(),
                            onGiftSent: (activities) {
                              setState(() {
                                currentEvent = currentEvent.copyWith(
                                  activities: activities,
                                );
                              });
                            },
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onHeartTap: () async {
                        _heartKey.currentState?.addHeart();
                        await ZegoUIKit().sendInRoomCommand('like', []);
                      },
                    ),
                  ],
                ),
                height(0.025),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

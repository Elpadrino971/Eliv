// ignore_for_file: deprecated_member_use

import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/Animation/heart_animation.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
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

import 'dart:async';

class StartStream extends StatefulWidget {
  const StartStream({super.key, required this.event});
  final Event event;

  @override
  State<StartStream> createState() => _StartStreamState();
}

class _StartStreamState extends State<StartStream> {
  final ZegoController zegoController = Get.put(ZegoController());
  final EventController eventController = Get.find<EventController>();
  late Event currentEvent;
  final GlobalKey<HeartAnimationOverlayState> _heartKey =
      GlobalKey<HeartAnimationOverlayState>();
  StreamSubscription? _commandSubscription;
  Timer? _logTimer;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _initData();

    // Listen for in-room commands (likes, gifts, etc.)
    _commandSubscription = ZegoUIKit().getInRoomCommandReceivedStream().listen(
      _onInRoomCommandReceived,
    );
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await eventController.getAbusiveWords();
    currentEvent = widget.event;
    final activities = await eventController.getEventLogs(
      eventId: widget.event.id.toString(),
    );
    if (activities != null && mounted) {
      setState(() {
        currentEvent = currentEvent.copyWith(activities: activities);
      });
    }
    await eventController.updateEventStatus(
      eventId: widget.event.id.toString(),
      status: 'live',
    );
    await eventController.getGifts();

    _logTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
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

  Future<void> _sendComment({String? text}) async {
    final String comment = text ?? "";
    if (comment.isEmpty) return;

    if (eventController.hasAbusiveWords(comment)) {
      myWarningDialog(subtitle: 'live_restricted_words'.tr);
      return;
    }

    // Persist comment on server and update local event state
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

  void _launchPromo() {
    int percent = 20;
    int minutes = 10;
    Get.dialog(
      AlertDialog(
        backgroundColor: midnightSecondary,
        title: const Text(
          'Lancer une promo',
          style: TextStyle(
            color: ivory,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Réduction', style: TextStyle(color: textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [10, 20, 30, 50]
                    .map(
                      (p) => ChoiceChip(
                        label: Text('-$p%'),
                        selected: percent == p,
                        onSelected: (_) => setS(() => percent = p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text('Durée', style: TextStyle(color: textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 15]
                    .map(
                      (m) => ChoiceChip(
                        label: Text('$m min'),
                        selected: minutes == m,
                        onSelected: (_) => setS(() => minutes = m),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Annuler', style: TextStyle(color: greyColor)),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await ZegoUIKit().sendInRoomCommand(
                'promo:$percent:${minutes * 60}',
                [],
              );
              Get.snackbar(
                'Promo lancée 🎟️',
                '-$percent% pendant $minutes min',
                colorText: ivory,
                backgroundColor: midnightSecondary,
              );
            },
            child: const Text(
              'Lancer',
              style: TextStyle(color: goldPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
            config: ZegoUIKitPrebuiltLiveStreamingConfig.host()
              ..audioVideoViewConfig.useVideoViewAspectFill = true
              ..inRoomMessage.visible = false
              ..bottomMenuBarConfig.hostButtons = [
                ZegoLiveStreamingMenuBarButtonName.toggleCameraButton,
                ZegoLiveStreamingMenuBarButtonName.switchAudioOutputButton,
                ZegoLiveStreamingMenuBarButtonName.switchCameraButton,
                ZegoLiveStreamingMenuBarButtonName.toggleMicrophoneButton,
              ],
            events: ZegoUIKitPrebuiltLiveStreamingEvents(
              onStateUpdated: (ZegoLiveStreamingState state) {
                if (state == ZegoLiveStreamingState.living) {
                  setState(() {
                    _isLive = true;
                  });
                } else if (state == ZegoLiveStreamingState.idle) {
                  setState(() {
                    _isLive = false;
                  });
                }
              },
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
          if (_isLive) _buildOverlayUI(),
        ],
      ),
    );
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

          // Bouton "Lancer une promo" (hote)
          Padding(
            padding: myPadding,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _launchPromo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: goldPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        color: midnightPrimary,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lancer une promo',
                        style: TextStyle(
                          color: midnightPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                    // Live chat feed
                    Expanded(
                      child: LiveStreamChatPreview(
                        messages: currentEvent.activities ?? [],
                      ),
                    ),

                    const SizedBox(width: 8),
                    // Right action buttons
                    LiveStreamSideActions(
                      fromArtist: true,
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
                height(0.04),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

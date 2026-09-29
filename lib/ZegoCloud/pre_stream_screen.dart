// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/Animation/heart_animation.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
// import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_side_actions.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_top_bar.dart';
import 'package:artist/ZegoCloud/zego_controller.dart';
import 'package:artist/ZegoCloud/zego_gifts.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class PreStreamScreen extends StatefulWidget {
  const PreStreamScreen({super.key, required this.event});
  final Event event;

  @override
  State<PreStreamScreen> createState() => _PreStreamScreenState();
}

class _PreStreamScreenState extends State<PreStreamScreen> {
  final ZegoController zegoController = Get.put(ZegoController());
  final EventController eventController = Get.put(EventController());
  late Event currentEvent;
  final TextEditingController commentController = TextEditingController();
  StreamSubscription? _commandSubscription;
  Timer? _countdownTimer;
  Timer? _logTimer;
  String _formattedWaitTime = "00:00:00";
  // Vrai dès que l'heure du concert est atteinte (ou dépassée à l'ouverture) :
  // on retire simplement l'overlay du compte à rebours et on laisse le fan
  // dans la salle Zego (audience) déjà connectée. Avant, on affichait un
  // dialogue puis Get.back() x2 -> le fan était ÉJECTÉ pile au démarrage.
  bool _started = false;

  Future myInitMethod() async {
    final zegoTokenOk = await zegoController.fetchZegoToken();
    if (!zegoTokenOk && mounted) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: "Connexion au live impossible. Réessaie.",
      );
    }
    await eventController.getAbusiveWords();
    currentEvent = widget.event;
    final data = await eventController.getEventLogs(
      eventId: widget.event.id.toString(),
    );
    if (!mounted) return;
    currentEvent = currentEvent.copyWith(activities: data);
    setState(() {});
    await eventController.getGifts();
    if (!mounted) return;

    _startCountdown();

    // Rafraîchit le fil (commentaires / cadeaux). 15 s : suffisant, et évite
    // de marteler l'API pendant un live. getEventLogs n'ouvre plus de
    // dialogue d'erreur ; en cas d'échec réseau, on garde le fil actuel.
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final data = await eventController.getEventLogs(
        eventId: widget.event.id.toString(),
      );
      if (!mounted || data == null) return;
      setState(() {
        currentEvent = currentEvent.copyWith(activities: data);
      });
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final start = currentEvent.startDateTime;
    if (start == null || !start.isAfter(DateTime.now())) {
      // Déjà commencé : pas de compte à rebours du tout.
      _started = true;
      _formattedWaitTime = "00:00:00";
      if (mounted) setState(() {});
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final startTime = currentEvent.startDateTime;

      if (startTime == null) {
        timer.cancel();
        return;
      }

      final diff = startTime.difference(now);

      if (diff.isNegative || diff.inSeconds <= 0) {
        timer.cancel();
        _formattedWaitTime = "00:00:00";
        setState(() {});
        _onTimeUp();
      } else {
        setState(() {
          _formattedWaitTime = _formatDuration(diff);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _onTimeUp() {
    // Heure H : le fan RESTE dans la salle (la vue Zego audience tourne déjà
    // derrière l'overlay) ; on enlève juste le compte à rebours. Plus jamais
    // de dialogue ni de Get.back() ici.
    if (!mounted) return;
    setState(() {
      _started = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // Assigné en synchrone AVANT tout appel async (fetchZegoToken attend un
    // aller-retour réseau) : sinon build() s'exécute avec currentEvent
    // encore non initialisé -> LateInitializationError au premier rendu.
    currentEvent = widget.event;
    final start = currentEvent.startDateTime;
    _started = start == null || !start.isAfter(DateTime.now());
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
    _countdownTimer?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }

  final GlobalKey<HeartAnimationOverlayState> _heartKey =
      GlobalKey<HeartAnimationOverlayState>();

  Future<void> _sendComment({String? text}) async {
    final String comment = text ?? commentController.text.trim();
    if (comment.isEmpty) return;

    if (eventController.hasAbusiveWords(comment)) {
      myWarningDialog(subtitle: 'live_restricted_words'.tr);
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
      // Le clavier ne doit pas redimensionner le fond (vidéo Zego plein écran)
      // sinon l'overlay du live déborde (overflow) quand on ouvre le chat.
      resizeToAvoidBottomInset: false,
      body: Obx(() {
        final zegoToken = zegoController.zegoToken.value;
        if (zegoToken == null) {
          return const Center(
            child: CircularProgressIndicator(color: goldPrimary),
          );
        }
        return Stack(
        children: [
          // ── Zego Live Streaming Background ──────────────────────────
          ZegoUIKitPrebuiltLiveStreaming(
            appID: zegoController.zegoAppId.value,
            token: zegoToken,
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

          // ── Countdown Overlay (Obscures Streamer) ───────────────────
          if (!_started) _buildCountdownOverlay(),

          // ── Custom Overlay UI ────────────────────────────────────────
          _buildOverlayUI(),
        ],
        );
      }),
    );
  }

  Widget _buildCountdownOverlay() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: Get.height * .45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'live_stream_starts_in'.tr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _formattedWaitTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier', // Monospace for stable character widths
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: mainThemeColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'live_waiting_room'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
          // Décalage sous la barre du haut de Zego (avatar de l'hôte,
          // spectateurs, fermer), sinon notre en-tête la chevauche.
          const SizedBox(height: 54),

          // En-tête compact (artiste · LIVE · titre) ; « LIVE » seulement
          // une fois l'heure du concert atteinte.
          Padding(
            padding: myPadding,
            child: LiveStreamTopBar(event: currentEvent, isLive: _started),
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
                          backgroundColor: Colors.transparent,
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

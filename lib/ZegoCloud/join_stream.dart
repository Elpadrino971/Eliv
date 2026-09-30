// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/Animation/heart_animation.dart';
import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/point_packs.dart';
import 'package:artist/Global/screen_guard.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_side_actions.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_top_bar.dart';
import 'package:artist/ZegoCloud/zego_controller.dart';
import 'package:artist/ZegoCloud/zego_gifts.dart';
import 'package:artist/ZegoCloud/zego_text_fix.dart';
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
  int? _promoPercent;
  int _promoRemaining = 0;
  Timer? _promoTimer;
  Timer? _logTimer;
  // Mode « place à la scène » : masque chat, actions et infos pour ne voir
  // que le concert. Mémorisé d'un live à l'autre.
  bool _overlayHidden = box.read('fan_overlay_hidden') == true;

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
    // Rafraîchit le fil (commentaires / cadeaux). 15 s : suffisant, et évite
    // de marteler l'API pendant un live. Le Timer est conservé et annulé dans
    // dispose() (avant, il survivait à l'écran). getEventLogs n'ouvre plus de
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

  @override
  void initState() {
    super.initState();
    // Concert : captures / enregistrements d'écran noirs (voir screen_guard.dart).
    protectScreen(true);
    refreshPurchasablePointPacks();
    // Assigné en synchrone AVANT tout appel async (fetchZegoToken attend un
    // aller-retour réseau) : sinon build() s'exécute avec currentEvent
    // encore non initialisé -> LateInitializationError au premier rendu.
    currentEvent = widget.event;
    myInitMethod();

    // Listen for in-room commands (likes, gifts, etc.)
    _commandSubscription = ZegoUIKit().getInRoomCommandReceivedStream().listen(
      _onInRoomCommandReceived,
    );
  }

  @override
  void dispose() {
    protectScreen(false);
    commentController.dispose();
    _commandSubscription?.cancel();
    _promoTimer?.cancel();
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

  void _startPromo(int percent, int seconds) {
    _promoTimer?.cancel();
    setState(() {
      _promoPercent = percent;
      _promoRemaining = seconds;
    });
    _promoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_promoRemaining <= 1) {
        t.cancel();
        setState(() {
          _promoPercent = null;
          _promoRemaining = 0;
        });
      } else {
        setState(() => _promoRemaining--);
      }
    });
  }

  String _fmtPromo(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _promoBanner() {
    return GestureDetector(
      onTap: () => Get.to(
        () => CheckOutScreen(
          event: currentEvent,
          discountPercent: _promoPercent!,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE6C76A), goldSecondary],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_offer_rounded,
              color: midnightPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PROMO -$_promoPercent% • ${_fmtPromo(_promoRemaining)}',
                style: const TextStyle(
                  color: midnightPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: midnightPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Acheter',
                style: TextStyle(
                  color: goldPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onInRoomCommandReceived(ZegoInRoomCommandReceivedData data) {
    if (data.command == 'like') {
      _heartKey.currentState?.addHeart();
    } else if (data.command.startsWith('promo:')) {
      final parts = data.command.split(':');
      if (parts.length >= 3) {
        final percent = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;
        if (percent > 0 && seconds > 0) _startPromo(percent, seconds);
      }
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
    return CaptureShield(child: Scaffold(
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
          ZegoTextFix(
            child: ZegoUIKitPrebuiltLiveStreaming(
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
          ),

          // ── Animations Layer ─────────────────────────────────────────
          IgnorePointer(child: HeartAnimationOverlay(key: _heartKey)),

          // ── Custom Overlay UI ────────────────────────────────────────
          _buildOverlayUI(),
        ],
        );
      }),
    ));
  }

  ZegoUIKitPrebuiltLiveStreamingConfig _buildZegoConfig() {
    return ZegoUIKitPrebuiltLiveStreamingConfig.audience()
      ..inRoomMessage.visible = false
      ..audioVideoViewConfig.useVideoViewAspectFill = true
      ..inRoomMessageConfig = ZegoInRoomMessageConfig(visible: false)
      // ── Co-host "sur scène" (main levée) ── Même limite que côté hôte. Le
      // bouton "demander à monter" (lever la main) du SDK envoie la demande à
      // l'artiste, qui valide avant que la caméra + le micro du fan passent en
      // direct pour toute la room.
      ..coHost.maxCoHostCount = 8
      ..topMenuBarConfig = ZegoTopMenuBarConfig(buttons: []);
  }

  // Petit bouton rond (même style que les commandes de l'écran artiste).
  Widget _fanToggle({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? goldPrimary
              : Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? midnightPrimary : ivory,
        ),
      ),
    );
  }

  Widget _buildOverlayUI() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Décalage sous la barre du haut de Zego (avatar de l'hôte,
          // spectateurs, fermer), sinon notre en-tête la chevauche.
          const SizedBox(height: 54),

          // En-tête compact (artiste · LIVE · titre) + bouton œil. Le bouton
          // reste TOUJOURS visible (pour réafficher), estompé en mode épuré.
          Padding(
            padding: myPadding,
            child: Row(
              children: [
                Expanded(
                  child: _overlayHidden
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: LiveStreamTopBar(event: currentEvent),
                        ),
                ),
                Opacity(
                  opacity: _overlayHidden ? 0.4 : 1,
                  child: Tooltip(
                    message: 'fan_clean_view'.tr,
                    child: _fanToggle(
                      icon: _overlayHidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      active: !_overlayHidden,
                      onTap: () {
                        setState(() => _overlayHidden = !_overlayHidden);
                        box.write('fan_overlay_hidden', _overlayHidden);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bannière promo (compte à rebours) — diffusée par l'artiste. Reste
          // visible en mode épuré : offre limitée dans le temps.
          if (_promoPercent != null)
            Padding(
              padding: myPadding.copyWith(top: 8),
              child: _promoBanner(),
            ),

          const Spacer(),

          // Bottom Chat + Actions (masqués en mode épuré)
          if (!_overlayHidden)
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

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
// ignore: depend_on_referenced_packages
import 'package:zego_express_engine/zego_express_engine.dart';

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
  // Contrôles hôte : masquer tout l'overlay (place à la scène) / couper le chat.
  bool _overlayHidden = false;
  bool _chatHidden = false;
  // Compteur de durée du live (démarré quand le live diffuse réellement).
  DateTime? _liveStartedAt;
  Timer? _durationTimer;
  String _liveDuration = '00:00';
  // Relais Zego -> Mux (enregistrement replay) : déclenché une seule fois.
  bool _relayStarted = false;

  @override
  void initState() {
    super.initState();
    // Assigné en synchrone AVANT tout appel async (fetchZegoToken attend un
    // aller-retour réseau) : sinon build() s'exécute avec currentEvent
    // encore non initialisé -> LateInitializationError au premier rendu.
    currentEvent = widget.event;
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
    _durationTimer?.cancel();
    // Signale la fin du live -> Mux finalise l'asset de replay.
    zegoController.stopRecording(widget.event.id.toString());
    super.dispose();
  }

  // Compteur de durée du live : démarre au premier passage en diffusion.
  void _startDurationTimer() {
    if (_durationTimer != null) return;
    _liveStartedAt = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final d = DateTime.now().difference(_liveStartedAt!);
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _liveDuration = h > 0 ? '$h:$m:$s' : '$m:$s';
      });
    });
  }

  // Relais du flux Zego vers Mux (RTMP) pour l'enregistrement du replay.
  // muxRtmpUrl est fourni par le backend (startRecording) si le replay est
  // activé pour ce concert. Le streamID suit la convention du UIKit :
  // "<liveID>_<userID>_main" (confirmé dans les logs Zego). Enveloppé dans un
  // try/catch : un échec de relais ne doit jamais interrompre le live.
  Future<void> _relayToMux() async {
    if (_relayStarted) return;
    final rtmp = zegoController.muxRtmpUrl.value;
    if (rtmp == null || rtmp.isEmpty) return;
    _relayStarted = true;
    final streamId =
        '${currentEvent.id}_${zegoController.userId}_main';
    try {
      final res = await ZegoExpressEngine.instance
          .addPublishCdnUrl(streamId, rtmp);
      myPrint(
        'relayToMux: addPublishCdnUrl($streamId -> $rtmp) '
        'errorCode=${res.errorCode}',
      );
    } catch (e) {
      _relayStarted = false; // autorise un nouvel essai
      myPrint('relayToMux: exception -> $e');
    }
  }

  Future<void> _initData() async {
    final zegoTokenOk = await zegoController.fetchZegoToken();
    if (!zegoTokenOk && mounted) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: "Connexion au live impossible. Réessaie.",
      );
    }
    // Prépare l'enregistrement du replay (crée le flux Mux côté serveur si le
    // replay est activé pour ce concert). Le relais Zego->Mux (dernière ligne)
    // reste à brancher/tester en live — voir ZegoController.startRecording.
    await zegoController.startRecording(widget.event.id.toString());
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
            child: Text('common_cancel'.tr, style: TextStyle(color: greyColor)),
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
            appID: ZegoCloudKeys.appId,
            token: zegoToken,
            userID: zegoController.userId,
            userName: zegoController.userName,
            liveID: currentEvent.id.toString(),
            config: ZegoUIKitPrebuiltLiveStreamingConfig.host()
              ..audioVideoViewConfig.useVideoViewAspectFill = true
              ..inRoomMessage.visible = false
              // ── Co-host "sur scène" (les fans lèvent la main -> l'artiste
              // valide) ── Jusqu'à 8 fans montent avec caméra + micro, en grille
              // auto. L'artiste reçoit une demande et accepte/refuse ; rien ne
              // s'affiche sans son accord. Descendre à 4 pour les très gros
              // concerts. Fonctionnalité demandée par les artistes (Alizés).
              ..coHost.maxCoHostCount = 8
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
                  _startDurationTimer();
                  _relayToMux();
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
        );
      }),
    );
  }

  // Petit bouton rond de contrôle hôte (œil / chat).
  Widget _hostToggle({
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
          // Décalage sous la barre du haut de Zego (avatar hôte + compteur +
          // bouton quitter), sinon notre barre perso la chevauche.
          const SizedBox(height: 54),

          // Barre de contrôles hôte — TOUJOURS visible (permet de réafficher
          // l'overlay après l'avoir masqué).
          Padding(
            padding: myPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Compteur de durée du live (depuis le début de la diffusion)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: liveRed,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _liveDuration,
                        style: const TextStyle(
                          color: ivory,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Couper / réafficher le chat
                    _hostToggle(
                      icon: _chatHidden
                          ? Icons.chat_bubble_outline
                          : Icons.chat_bubble,
                      active: !_chatHidden,
                      onTap: () =>
                          setState(() => _chatHidden = !_chatHidden),
                    ),
                    // Vider l'écran (place à la scène) / réafficher
                    _hostToggle(
                      icon: _overlayHidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      active: !_overlayHidden,
                      onTap: () =>
                          setState(() => _overlayHidden = !_overlayHidden),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tout le reste de l'overlay est masquable (place à la scène).
          if (!_overlayHidden) ...[
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
                      // Live chat feed (masquable indépendamment)
                      Expanded(
                        child: _chatHidden
                            ? const SizedBox.shrink()
                            : LiveStreamChatPreview(
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
        ],
      ),
    );
  }
}

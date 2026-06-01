import 'dart:async';

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Formate une duree video en m:ss (ou h:mm:ss si > 1h).
String _fmtDur(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// Onglet Live = 2 pages en swipe horizontal :
///  - Page 0 "Pour toi" : feed vertical de reels (VybzzZ Originals)
///  - Page 1 "En direct" : lives en cours, apercu gratuit 60s puis gate opaque
class VybzLiveScreen extends StatefulWidget {
  const VybzLiveScreen({super.key});

  @override
  State<VybzLiveScreen> createState() => _VybzLiveScreenState();
}

class _VybzLiveScreenState extends State<VybzLiveScreen> {
  final eventController = Get.find<EventController>();
  final PageController _hController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _hController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      body: Stack(
        children: [
          PageView(
            controller: _hController,
            onPageChanged: (i) {
              setState(() => _page = i);
              // Met en pause le reel quand on quitte "Pour toi".
              final c = eventController.currentController.value;
              if (c != null && c.value.isInitialized) {
                i == 0 ? c.play() : c.pause();
              }
            },
            children: const [_ForYouFeed(), _LivesFeed()],
          ),

          // Pastille de navigation centrale (Pour toi · En direct)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: blackColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: whiteColor.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tab('live_tab_for_you'.tr, 0),
                    _tab('live_tab_live'.tr, 1, live: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, {bool live = false}) {
    final active = _page == index;
    return GestureDetector(
      onTap: () => _goTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? whiteColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: liveRed,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: active ? whiteColor : whiteColor.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PAGE 0 — "Pour toi" : feed vertical de reels (logique d'origine conservee)
// ───────────────────────────────────────────────────────────────────────────
class _ForYouFeed extends StatefulWidget {
  const _ForYouFeed();

  @override
  State<_ForYouFeed> createState() => _ForYouFeedState();
}

class _ForYouFeedState extends State<_ForYouFeed> {
  final eventController = Get.find<EventController>();

  @override
  void initState() {
    super.initState();
    final events = eventController.allEvents.value.data ?? [];
    final url = eventController.reelUrlFor(
      events.isNotEmpty ? events[0] : null,
    );
    if (url != null) {
      eventController.initVideoPlayer(url);
    }
  }

  @override
  void dispose() {
    eventController.disposeVideoController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final events = eventController.allEvents.value.data ?? [];
      return events.isEmpty
          ? Center(
              child: Text(
                'live_no_reel'.tr,
                style: TextStyle(color: whiteColor),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              onPageChanged: eventController.onPageChanged,
              itemCount: APIs.muxDemoPlaybackIds.isNotEmpty
                  ? APIs.muxDemoPlaybackIds.length
                  : events.length,
              itemBuilder: (context, index) {
                final event = events[index % events.length];
                return GetBuilder<EventController>(
                  builder: (controller) {
                    final videoController = controller.currentController.value;

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
                        // Bouton fermer (toujours visible) -> sortie du live
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          left: 12,
                          child: GestureDetector(
                            onTap: () =>
                                Get.offAll(() => const MyBottomBar()),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: blackColor.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: whiteColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        if (controller.showVideoControls.value &&
                            videoController != null)
                          Positioned.fill(
                            child: Container(
                              color: blackColor.withValues(alpha: 0.3),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.replay_5,
                                            color: whiteColor,
                                            size: 40,
                                          ),
                                          onPressed: () =>
                                              controller.seekVideo(-5),
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
                                          onPressed: () =>
                                              controller.seekVideo(5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Jauge scrubbable (glisser pour avancer/reculer)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      150,
                                    ),
                                    child: ValueListenableBuilder<
                                      VideoPlayerValue
                                    >(
                                      valueListenable: videoController,
                                      builder: (context, value, _) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            VideoProgressIndicator(
                                              videoController,
                                              allowScrubbing: true,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              colors: const VideoProgressColors(
                                                playedColor: goldPrimary,
                                                bufferedColor: Colors.white24,
                                                backgroundColor: Colors.white12,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _fmtDur(value.position),
                                                  style: const TextStyle(
                                                    color: whiteColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  _fmtDur(value.duration),
                                                  style: TextStyle(
                                                    color: whiteColor
                                                        .withValues(alpha: 0.7),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (controller.showVideoControls.value)
                          Container(
                          padding: myPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              height(0.03),
                              Row(
                                children: [
                                  Text(
                                    'VybzzZ',
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
                                    onTap: () => myShare(
                                      message:
                                          '${event.name?.capitalize ?? 'VybzzZ'} — ${APIs.mainIP}',
                                    ),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: whiteColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: const Icon(
                                        Icons.ios_share_rounded,
                                        color: whiteColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: controller.toggleMute,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: whiteColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
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
                        if (controller.showVideoControls.value)
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
                                    label: 'join_live'.tr,
                                    onTap: () {
                                      Get.to(() => FutureScreen(event: event));
                                    },
                                  ),
                                ),
                                height(0.07),
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
    });
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PAGE 1 — "En direct" : feed vertical des lives en cours
// ───────────────────────────────────────────────────────────────────────────
class _LivesFeed extends StatefulWidget {
  const _LivesFeed();

  @override
  State<_LivesFeed> createState() => _LivesFeedState();
}

class _LivesFeedState extends State<_LivesFeed> {
  final eventController = Get.find<EventController>();

  @override
  void initState() {
    super.initState();
    eventController.getEventsByStatus(status: EventStatus.live);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lives = eventController.liveNowEvents.value.data ?? [];
      if (lives.isEmpty) return const _NoLiveState();
      return PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: lives.length,
        itemBuilder: (context, index) =>
            _LivePreviewCard(event: lives[index]),
      );
    });
  }
}

class _NoLiveState extends StatelessWidget {
  const _NoLiveState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: midnightPrimary,
      width: Get.width,
      height: Get.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors_off_rounded,
              color: whiteColor.withValues(alpha: 0.4), size: 56),
          height(0.02),
          Text(
            'live_no_live_title'.tr,
            style: TextStyle(
              color: whiteColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          height(0.01),
          Text(
            'live_no_live_subtitle'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: whiteColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte live : apercu gratuit 60s (image + badge LIVE) puis gate opaque.
class _LivePreviewCard extends StatefulWidget {
  final Event event;
  const _LivePreviewCard({required this.event});

  @override
  State<_LivePreviewCard> createState() => _LivePreviewCardState();
}

class _LivePreviewCardState extends State<_LivePreviewCard>
    with SingleTickerProviderStateMixin {
  static const int previewSeconds = 60;
  Timer? _timer;
  int _remaining = previewSeconds;
  bool _gated = false;
  late final AnimationController _zoom;

  bool get _hasAccess {
    final owns = (widget.event.ticketBuyerIds ?? [])
        .contains(userModel.value.user?.id ?? 1);
    final price = double.tryParse(widget.event.ticketPrice ?? '') ?? 0;
    return owns || price <= 0;
  }

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    if (!_hasAccess) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _gated = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _zoom.dispose();
    super.dispose();
  }

  void _joinLive() => Get.to(() => JoinStream(event: widget.event));
  void _openDetail() => Get.to(() => FutureScreen(event: widget.event));

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aperçu = image de couverture avec léger zoom (Ken Burns).
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: _zoom, curve: Curves.easeInOut),
          ),
          child: ImageWidget(
            url: '${APIs.eventImageIP}/${e.coverImage}',
            fit: BoxFit.cover,
          ),
        ),
        // Dégradés pour lisibilité
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x00000000), Color(0xCC000000)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Badge LIVE + spectateurs (haut gauche)
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: liveRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      'live_badge'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Infos bas + CTA
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: e.artist != null
                      ? () => Get.to(() => ArtistDetailScreen(artist: e.artist!))
                      : null,
                  child: Text(
                    '@${e.artist?.artistName?.capitalize ?? 'live_artist_name_fallback'.tr}',
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                height(0.008),
                Text(
                  e.name?.capitalize ?? 'live_event_fallback'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                height(0.018),

                // Apercu gratuit (barre + compteur) — uniquement si gate actif
                if (!_hasAccess && !_gated) ...[
                  Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          color: goldPrimary, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'live_free_preview'.trParams({
                          'seconds': '$_remaining',
                        }),
                        style: const TextStyle(
                          color: ivory,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (previewSeconds - _remaining) / previewSeconds,
                      minHeight: 4,
                      backgroundColor: whiteColor.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(goldPrimary),
                    ),
                  ),
                  height(0.018),
                ],

                MyButton(
                  label: _hasAccess
                      ? 'live_enter_live'.tr
                      : 'live_join_the_live'.tr,
                  image: 'assets/arrow.png',
                  imageColor: midnightPrimary,
                  labelColor: midnightPrimary,
                  onTap: _hasAccess ? _joinLive : _openDetail,
                ),
                // Espace pour la bottom nav
                height(0.06),
              ],
            ),
          ),
        ),

        // ── Overlay opaque (gate) quand l'aperçu est terminé
        IgnorePointer(
          ignoring: !_gated,
          child: AnimatedOpacity(
            opacity: _gated ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: Container(
              color: midnightPrimary.withValues(alpha: 0.92),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: goldPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: goldPrimary, size: 34),
                  ),
                  height(0.025),
                  Text(
                    'live_preview_ended'.tr,
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  height(0.012),
                  Text(
                    'live_preview_ended_desc'.trParams({
                      'artist': e.artist?.artistName?.capitalize ??
                          'live_artist_name_fallback'.tr,
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: whiteColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  height(0.03),
                  MyButton(
                    label: 'live_buy_ticket'.tr,
                    image: 'assets/arrow.png',
                    imageColor: midnightPrimary,
                    labelColor: midnightPrimary,
                    onTap: _openDetail,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/live_router.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/LiveScreen/create_short_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:artist/widgets/feed_poster.dart';
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

/// Onglet Live = 3 pages en swipe horizontal :
///  - Page 0 "Pour toi" : feed vertical de reels (VybzzZ Originals)
///  - Page 1 "En direct" : lives en cours, apercu gratuit 60s puis gate opaque
///  - Page 2 "Clips" : feed vertical des shorts UGC (uploadés via Mux)
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
            children: [
              const _ForYouFeed(),
              const _LivesFeed(),
              _ClipsFeed(isActive: _page == 2),
            ],
          ),

          // Pastille de navigation centrale (Pour toi · En direct)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0,
            right: 0,
            child: Obx(() {
              // Les onglets restent TOUJOURS visibles : l'application s'ouvre
              // sur cet écran, et les masquer laissait l'utilisateur sans
              // aucun repère ni moyen d'en sortir.
              eventController.showVideoControls.value; // dépendance Obx conservée
              return Center(
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
                    _tab('Clips', 2),
                  ],
                ),
              ),
            );
            }),
          ),

          // X de sortie sur les pages "En direct" et "Clips" : l'onglet Live
          // masque la barre de nav, donc sans ça on reste coincé. Même action
          // que le X de "Pour toi".
          if (_page != 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              child: GestureDetector(
                onTap: () => Get.offAll(() => const MyBottomBar()),
                child: const Icon(
                  Icons.close_rounded,
                  color: whiteColor,
                  size: 30,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
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
      final clipUrls = eventController.forYouClipUrls;
      final hasContent = clipUrls.isNotEmpty || events.isNotEmpty;
      return !hasContent
          ? Center(
              child: Text(
                'live_no_reel'.tr,
                style: TextStyle(color: whiteColor),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              onPageChanged: eventController.onPageChanged,
              itemCount: clipUrls.isNotEmpty ? clipUrls.length : events.length,
              itemBuilder: (context, index) {
                // Les clips admin (feed_clips) ne sont pas rattachés à un
                // concert précis : event peut être null (clips purs), le
                // bandeau artiste/concert est alors simplement masqué plus bas.
                final event = events.isNotEmpty
                    ? events[index % events.length]
                    : null;
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
                                : FeedPoster(
                                    url: index < clipUrls.length
                                        ? clipUrls[index]
                                        : null,
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
                                          '${event?.name?.capitalize ?? 'VybzzZ'} — ${APIs.mainIP}',
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
                                // Clip admin pur (feed_clips sans concert
                                // associé) : pas de bandeau artiste à afficher.
                                if (event != null) ...[
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (event.artist == null) return;
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
                                ],
                                height(0.07),
                              ],
                            ),
                          ),
                        ),

                        // Boutons "+" (créer un short) et fermer (X) — placés en
                        // dernier dans le Stack pour rester AU-DESSUS du voile de
                        // contrôles (sinon le Positioned.fill avale leurs taps).
                        if (controller.showVideoControls.value)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            right: 12,
                            child: GestureDetector(
                              onTap: () =>
                                  Get.to(() => const CreateShortScreen()),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: goldPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: midnightPrimary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        // La croix de sortie est TOUJOURS affichée : elle
                        // n'apparaissait qu'après avoir tapé la vidéo au
                        // hasard, ce qui rendait l'écran sans issue visible.
                        if (true)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 12,
                            child: GestureDetector(
                              onTap: () =>
                                  Get.offAll(() => const MyBottomBar()),
                              child: const Icon(
                                Icons.close_rounded,
                                color: whiteColor,
                                size: 30,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 8),
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

  void _joinLive() => joinLive(widget.event);
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

// ───────────────────────────────────────────────────────────────────────────
// PAGE 2 — "Clips" : feed vertical des shorts UGC (uploadés via Mux).
// Contrôleur vidéo indépendant pour ne pas interférer avec "Pour toi".
// ───────────────────────────────────────────────────────────────────────────
class _ClipsFeed extends StatefulWidget {
  final bool isActive;
  const _ClipsFeed({required this.isActive});

  @override
  State<_ClipsFeed> createState() => _ClipsFeedState();
}

class _ClipsFeedState extends State<_ClipsFeed> {
  final eventController = Get.find<EventController>();
  final PageController _pageController = PageController();
  VideoPlayerController? _controller;
  int _index = 0;

  List<String> get _ids => eventController.clipsFeedUrls;

  @override
  void initState() {
    super.initState();
    if (widget.isActive && _ids.isNotEmpty) _initVideo(_ids.first);
  }

  @override
  void didUpdateWidget(covariant _ClipsFeed old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      if (_controller == null && _ids.isNotEmpty) {
        _initVideo(_ids[_index]);
      } else {
        _controller?.play();
      }
    } else if (!widget.isActive && old.isActive) {
      _controller?.pause();
    }
  }

  void _initVideo(String videoUrl) {
    _controller?.dispose();
    _controller = null;
    final c = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
    c.setLooping(true);
    _controller = c;
    if (widget.isActive) c.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    if (ids.isEmpty) return const _NoClipsState();

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: ids.length,
          onPageChanged: (i) {
            _index = i;
            _initVideo(ids[i]);
          },
          itemBuilder: (context, index) {
            final c = _controller;
            final ready = c != null && c.value.isInitialized;
            // Tap sur un clip (paysage) → plein écran paysage (façon YouTube).
            final openFullscreen = () async {
              if (index >= ids.length) return;
              _controller?.pause();
              await Get.to(() => ReplayPlayerScreen(
                    url: ids[index],
                    playlist: ids,
                    startIndex: index,
                    autoAdvance: true,
                    forceLandscape: true,
                  ));
              if (mounted && widget.isActive) _controller?.play();
            };
            return GestureDetector(
              onTap: openFullscreen,
              child: Container(
                width: Get.width,
                height: Get.height,
                color: blackColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ready)
                      Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      )
                    else
                      FeedPoster(url: index < _ids.length ? _ids[index] : null),
                    // Indice "plein écran" en bas à droite du clip.
                    if (ready)
                      Positioned(
                        right: 14,
                        bottom: 90,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Libellé "VYBZZZ Clips"
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Row(
            children: [
              const Text(
                'VybzzZ',
                style: TextStyle(
                  color: whiteColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Clips',
                style: TextStyle(
                  color: goldPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Bouton "+" créer un short
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          right: 12,
          child: GestureDetector(
            onTap: () => Get.to(() => const CreateShortScreen()),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: goldPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: midnightPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// État vide de l'onglet Clips : invite à ajouter un clip.
class _NoClipsState extends StatelessWidget {
  const _NoClipsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: midnightPrimary,
      width: Get.width,
      height: Get.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_collection_outlined,
              color: whiteColor.withValues(alpha: 0.4), size: 56),
          height(0.02),
          Text(
            'live_no_clips'.tr,
            style: TextStyle(
              color: whiteColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          height(0.01),
          Text(
            'clip_be_first'.tr,
            style: TextStyle(
              color: whiteColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          height(0.03),
          GestureDetector(
            onTap: () => Get.to(() => const CreateShortScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: goldPrimary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: midnightPrimary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'clip_create_title'.tr,
                    style: const TextStyle(
                      color: midnightPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

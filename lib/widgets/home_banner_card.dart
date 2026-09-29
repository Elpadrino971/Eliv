import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:artist/Global/app_date.dart';

class HomeBannerCard extends StatefulWidget {
  const HomeBannerCard({super.key, required this.event});
  final Event event;

  @override
  State<HomeBannerCard> createState() => _HomeBannerCardState();
}

class _HomeBannerCardState extends State<HomeBannerCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;

  // Teaser libéré au passage en arrière-plan (décodeur + tampons HLS) et
  // recréé au retour : l'app suspendue reste légère. Un seul teaser vit à la
  // fois (PageView.builder : seule la bannière visible est construite).
  bool _releasedInBackground = false;

  Event get event => widget.event;

  bool get _isLive =>
      event.startDateTime != null &&
      event.endDateTime != null &&
      DateTime.now().isAfter(event.startDateTime!) &&
      DateTime.now().isBefore(event.endDateTime!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  void _initVideo() {
    final reel = event.videoReel;
    if (reel == null || reel.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(reel));
    controller
        .initialize()
        .then((_) {
          // Widget démonté ou lecteur remplacé/libéré entre-temps : ne pas
          // toucher à un lecteur déjà disposé.
          if (!mounted || _videoController != controller) return;
          controller
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() {});
        })
        .catchError((_) {
          // Flux video indisponible : le visuel de couverture reste affiche.
        });
    _videoController = controller;
  }

  void _releaseVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void didUpdateWidget(covariant HomeBannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.videoReel != widget.event.videoReel) {
      _releaseVideo();
      _initVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_videoController == null) return;
      _releaseVideo();
      _releasedInBackground = true;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _releasedInBackground) {
      _releasedInBackground = false;
      _initVideo();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseVideo();
    super.dispose();
  }

  /// 12800 -> "12.8K"
  String _formatCount(int? value) {
    final v = value ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  Widget _coverImage() {
    return Image.network(
      '${APIs.eventImageIP}/${event.coverImage}',
      fit: BoxFit.cover,
      // Couverture décodée à 1080 px max (pas en pleine résolution d'upload).
      cacheWidth: 1080,
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/background4.png', fit: BoxFit.cover),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: cardDeep),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoReady = _videoController?.value.isInitialized ?? false;
    return SizedBox(
      width: Get.width,
      height: Get.height * 0.46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Photo de couverture (toujours presente en dessous)
          Positioned.fill(child: _coverImage()),

          // ── Video de teaser (Mux) : fondu enchaine par-dessus la photo
          // des qu'elle est prete, pour eviter un changement brusque.
          if (_videoController != null)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: videoReady ? 1 : 0,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeIn,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),

          // ── Overlay bleu nuit pour la lisibilite
          const DecoratedBox(
            decoration: BoxDecoration(gradient: kImageOverlay),
          ),

          // ── Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pastille de localisation affichée UNIQUEMENT si l'artiste
                    // a une adresse : sinon on masque la puce plutôt que
                    // d'afficher "N/A" (plus propre pour l'utilisateur).
                    if ((event.artist?.address ?? '').trim().isNotEmpty)
                      _glassChip(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/location_icon.png',
                              width: 16,
                              height: 16,
                              color: goldPrimary,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: Get.width * 0.45,
                              ),
                              child: Text(
                                (event.artist?.address ?? '').trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ivory,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    _glassChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 15,
                            color: ivory,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatCount(event.joinedUsersCount),
                            style: const TextStyle(
                              color: ivory,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                _isLive ? _liveBadge() : _eventTypeLabel(),
                const SizedBox(height: 10),

                Text(
                  event.artist?.artistName ?? event.artist?.fullName ?? 'N/A',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: ivory,
                    fontWeight: FontWeight.w600,
                    fontSize: 30,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.name ?? 'N/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: goldPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                _infoRows(),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Get.to(() => FutureScreen(event: event)),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: goldPrimary.withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: midnightPrimary,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'join_live'.tr.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: AppFonts.ui,
                                  color: midnightPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: midnightPrimary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: goldSecondary, width: 1.4),
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: goldPrimary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTypeLabel() {
    return Text(
      'live_concert'.tr.toUpperCase(),
      style: const TextStyle(
        fontFamily: AppFonts.ui,
        color: goldPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 2,
      ),
    );
  }

  Widget _infoRows() {
    final dt = event.startDateTime;
    final hasDate = dt != null;
    final address = event.artist?.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDate)
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: goldPrimary, size: 14),
              const SizedBox(width: 6),
              Text(
                AppDate.dayDate(dt).toUpperCase(),
                style: const TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.schedule_rounded,
                  color: goldPrimary, size: 14),
              const SizedBox(width: 6),
              Text(
                AppDate.time(dt),
                style: const TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        if (hasDate && (address != null && address.isNotEmpty))
          const SizedBox(height: 8),
        if (address != null && address.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: goldPrimary, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ivory,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _glassChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: liveRed,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 6),
          Text(
            'LIVE NOW',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

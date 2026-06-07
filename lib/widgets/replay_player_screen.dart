import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/cast_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Lecteur de REPLAY / LIVE (HLS Mux). Plein écran : play/pause, jauge,
/// fermer, cast (AirPlay), ROTATION écran, et barre d'actions (like / tips /
/// partage) si l'[event] est fourni.
class ReplayPlayerScreen extends StatefulWidget {
  const ReplayPlayerScreen({
    super.key,
    this.playbackId,
    this.url,
    this.title,
    this.isLive = false,
    this.event,
  }) : assert(playbackId != null || url != null, 'playbackId ou url requis');

  final String? playbackId;
  final String? url;
  final String? title;
  final bool isLive;

  /// Concert associé (pour like / tips / partage). Optionnel.
  final Event? event;

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;

  bool _liked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.event?.likesCount ?? 0;
    // Autorise la rotation (paysage) pendant la lecture vidéo.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _init();
  }

  Future<void> _init() async {
    try {
      final src = widget.url ?? Mux.hlsUrl(widget.playbackId!);
      final c = VideoPlayerController.networkUrl(Uri.parse(src));
      await c.initialize();
      if (!widget.isLive) await c.setLooping(true);
      c.play();
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Restaure le portrait (l'app est portrait-only ailleurs).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  void _toggleLike() {
    final event = widget.event;
    if (event?.id == null) return;
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
      if (_likes < 0) _likes = 0;
    });
    Get.find<EventController>().likeEvent(eventId: '${event!.id}', liked: _liked);
  }

  void _share() {
    final name = widget.event?.name ?? widget.title ?? 'un concert';
    final artist = widget.event?.artist?.artistName ?? widget.event?.artist?.fullName ?? '';
    myShare(
      message: 'Regarde "$name"${artist.isNotEmpty ? ' de $artist' : ''} sur VYBZZZ 🎤🔥\nhttps://vybzzz.online',
    );
  }

  void _openTips() async {
    final event = widget.event;
    if (event?.id == null) return;
    final controller = Get.find<EventController>();
    if ((controller.gifts.value.data ?? []).isEmpty) {
      await controller.getGifts();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: midnightSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => GetBuilder<EventController>(
        builder: (c) {
          final gifts = c.gifts.value.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Envoyer un pourboire 🎁',
                    style: TextStyle(color: ivory, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                if (gifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: goldPrimary)),
                  )
                else
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: gifts.map((g) {
                      return GestureDetector(
                        onTap: () async {
                          Get.back();
                          await controller.sendGift(eventId: '${event!.id}', giftId: '${g.id}');
                          Get.snackbar('Merci !', 'Pourboire "${g.name}" envoyé 🎁',
                              backgroundColor: cardDeep, colorText: ivory);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardDeep,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: goldSecondary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.card_giftcard_rounded, color: goldPrimary, size: 26),
                              const SizedBox(height: 4),
                              Text(g.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: ivory, fontSize: 11)),
                              Text('\$${g.price ?? '0'}',
                                  style: const TextStyle(color: textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    Color color = whiteColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: blackColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: whiteColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final hasEvent = widget.event?.id != null;
    return Scaffold(
      backgroundColor: blackColor,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && c != null)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else if (_error)
              Center(
                child: Text(
                  'Replay indisponible',
                  style: TextStyle(color: whiteColor.withValues(alpha: 0.7)),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: goldPrimary)),

            // Fermer (haut gauche)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: blackColor.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: whiteColor, size: 22),
                ),
              ),
            ),

            // Cast / AirPlay (haut droite)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 12,
              child: const CastButton(),
            ),

            // Barre d'actions verticale (like / tips / partage) — droite
            if (hasEvent)
              Positioned(
                right: 12,
                bottom: 110,
                child: Column(
                  children: [
                    _actionButton(
                      icon: _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? const Color(0xffFF4D6D) : whiteColor,
                      label: '$_likes',
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      icon: Icons.card_giftcard_rounded,
                      color: goldPrimary,
                      label: 'Tips',
                      onTap: _openTips,
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      icon: Icons.ios_share_rounded,
                      label: 'Partager',
                      onTap: _share,
                    ),
                  ],
                ),
              ),

            // Badge EN DIRECT
            if (widget.isLive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: liveRed, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 7),
                        SizedBox(width: 5),
                        Text('EN DIRECT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),

            // Play/pause + jauge (au tap)
            if (_ready && c != null && _showControls) ...[
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
                  child: Icon(
                    c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: whiteColor,
                    size: 64,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 36,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, value, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          colors: const VideoProgressColors(
                            playedColor: goldPrimary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(value.position),
                                style: const TextStyle(
                                    color: whiteColor, fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(_fmt(value.duration),
                                style: TextStyle(
                                    color: whiteColor.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

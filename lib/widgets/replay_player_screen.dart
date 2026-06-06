import 'package:artist/Global/colors.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/widgets/cast_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Lecteur de REPLAY (VOD) — joue un flux HLS Mux a partir d'un playback id.
/// Plein ecran noir, play/pause, jauge scrubbable, bouton fermer.
class ReplayPlayerScreen extends StatefulWidget {
  const ReplayPlayerScreen({
    super.key,
    this.playbackId,
    this.url,
    this.title,
    this.isLive = false,
  }) : assert(playbackId != null || url != null, 'playbackId ou url requis');

  /// Playback ID Mux (public). On en derive l'URL HLS.
  final String? playbackId;

  /// URL HLS complète (ex. event.videoReel = https://stream.mux.com/<id>.m3u8).
  /// Prioritaire sur [playbackId] si fournie.
  final String? url;
  final String? title;

  /// true = flux LIVE (concert pro Mux Live) : pas de boucle, badge EN DIRECT.
  final bool isLive;

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
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
              const Center(
                child: CircularProgressIndicator(color: goldPrimary),
              ),

            // Bouton fermer (toujours visible)
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
                  child: const Icon(
                    Icons.close_rounded,
                    color: whiteColor,
                    size: 22,
                  ),
                ),
              ),
            ),

            // Bouton CAST / AirPlay (toujours visible, haut droite)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 12,
              child: const CastButton(),
            ),

            // Badge EN DIRECT (flux live pro)
            if (widget.isLive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: liveRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 7),
                        SizedBox(width: 5),
                        Text(
                          'EN DIRECT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Contrôles + jauge (au tap)
            if (_ready && c != null && _showControls) ...[
              Center(
                child: GestureDetector(
                  onTap: () => setState(
                    () => c.value.isPlaying ? c.pause() : c.play(),
                  ),
                  child: Icon(
                    c.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
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
                            Text(
                              _fmt(value.position),
                              style: const TextStyle(
                                color: whiteColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _fmt(value.duration),
                              style: TextStyle(
                                color: whiteColor.withValues(alpha: 0.7),
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
          ],
        ),
      ),
    );
  }
}

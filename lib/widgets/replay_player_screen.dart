import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/Global/orientation_helper.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/cast_button.dart';
import 'package:artist/widgets/mini_player.dart';
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
    this.forceLandscape = false,
    this.adopt,
  }) : assert(playbackId != null || url != null || adopt != null,
            'playbackId, url ou adopt requis');

  final String? playbackId;
  final String? url;
  final String? title;
  final bool isLive;

  /// Ouvre directement en paysage (clips musicaux 16:9). L'app reste
  /// portrait-only ailleurs ; on restaure le portrait à la fermeture.
  final bool forceLandscape;

  /// Concert associé (pour like / tips / partage). Optionnel.
  final Event? event;

  /// Lecteur DÉJÀ initialisé, transmis par le mini-lecteur lors d'un
  /// ré-agrandissement. Quand il est fourni, l'écran ne crée PAS de nouveau
  /// lecteur et n'en dispose PAS (le mini-lecteur en garde la propriété).
  final VideoPlayerController? adopt;

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;
  // Le lecteur a été confié au mini-lecteur -> ne pas le disposer ici.
  bool _handedOff = false;
  // Fermeture explicite (croix) -> ne pas restaurer la mini-carte.
  bool _closed = false;

  bool _liked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    // Ouverture d'une NOUVELLE vidéo alors qu'un mini-lecteur flotte encore :
    // on ferme l'ancien pour ne jamais avoir deux vidéos qui jouent en même
    // temps (le ré-agrandissement passe par "adopt" et ne tombe pas ici).
    if (widget.adopt == null &&
        Get.isRegistered<MiniPlayerController>() &&
        MiniPlayerController.to.controller.value != null) {
      MiniPlayerController.to.close();
    }
    _likes = widget.event?.likesCount ?? 0;
    // Clip musical 16:9 → bascule réelle en paysage via l'API native iOS 16
    // (façon Netflix/YouTube). Sinon (replay concert) : rotation libre.
    if (widget.forceLandscape) {
      OrientationHelper.forceLandscape();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _init();
  }

  Future<void> _init() async {
    // Ré-agrandissement depuis le mini-lecteur : on réutilise le lecteur déjà
    // initialisé (la vidéo continue sans coupure), on ne le recrée pas.
    if (widget.adopt != null) {
      final c = widget.adopt!;
      if (!c.value.isPlaying) c.play();
      setState(() {
        _controller = c;
        _ready = true;
      });
      return;
    }
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
    // On ne dispose le lecteur QUE si cet écran en est le propriétaire :
    // - pas en mode "adopt" (il appartient au mini-lecteur),
    // - pas s'il vient d'être confié au mini-lecteur (réduction).
    if (widget.adopt == null && !_handedOff) {
      _controller?.dispose();
    }
    // Retour système (bouton retour Android) depuis un plein écran adopté,
    // sans réduction ni fermeture explicite : on ré-affiche la mini-carte
    // pour que la vidéo (qui continue) reste accessible et pilotable.
    if (widget.adopt != null && !_handedOff && !_closed) {
      MiniPlayerController.to.restore();
    }
    // Restaure le portrait (l'app est portrait-only ailleurs).
    if (widget.forceLandscape) {
      OrientationHelper.resetPortrait();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  /// Réduit en mini-lecteur flottant (façon YouTube) : on confie le lecteur au
  /// contrôleur global, la vidéo continue, et on ferme le plein écran.
  void _minimize() {
    final c = _controller;
    if (c == null || !_ready) return;
    _handedOff = true;
    MiniPlayerController.to.attach(
      c: c,
      url: widget.url,
      playbackId: widget.playbackId,
      title: widget.title,
      isLive: widget.isLive,
      forceLandscape: widget.forceLandscape,
      event: widget.event,
    );
    Get.back();
  }

  /// Ferme définitivement le lecteur (croix). En mode "adopt", il faut couper
  /// et libérer le lecteur détenu par le mini-lecteur.
  void _close() {
    _closed = true;
    if (widget.adopt != null) {
      MiniPlayerController.to.close();
    }
    Get.back();
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
                Text('replay_send_tip'.tr,
                    style: const TextStyle(color: ivory, fontSize: 18, fontWeight: FontWeight.bold)),
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
                          Get.snackbar('replay_tip_thanks'.tr, 'Pourboire "${g.name}" envoyé 🎁',
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
                              Text('${g.price ?? '0'} €',
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
      body: _playerBody(c, hasEvent),
    );
  }

  Widget _playerBody(VideoPlayerController? c, bool hasEvent) {
    return GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        // Glisser vers le bas -> réduire en mini-lecteur (façon YouTube).
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 250) _minimize();
        },
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
                  'replay_unavailable'.tr,
                  style: TextStyle(color: whiteColor.withValues(alpha: 0.7)),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: goldPrimary)),

            // Réduire (mini-lecteur) + Fermer — haut gauche
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _minimize,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: blackColor.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: whiteColor, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: blackColor.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: whiteColor, size: 22),
                    ),
                  ),
                ],
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
                      label: 'common_share'.tr,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 7),
                        const SizedBox(width: 5),
                        Text('live_badge'.tr,
                            style: const TextStyle(
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
    );
  }
}

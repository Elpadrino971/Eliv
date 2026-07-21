import 'dart:async';

import 'package:artist/Global/api.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Applique un mode de fusion (BlendMode) entre l'enfant et ce qui est peint
/// DERRIÈRE (le live). Avec BlendMode.screen, le noir des vidéos de cadeaux
/// devient transparent et seul l'effet lumineux reste -> l'artiste n'est plus
/// masqué. Pas de dépendance externe.
class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({required this.blendMode, super.child});
  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);
  BlendMode _blendMode;
  set blendMode(BlendMode v) {
    if (v == _blendMode) return;
    _blendMode = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class GiftAnimationManager {
  // Cadeaux qui disposent d'une vidéo d'animation (assets/animations/<nom>.mp4).
  static const Set<String> _videoGifts = {
    'rose',
    'coeur',
    'couronne',
    'diamant',
    'etoile',
    'feu',
    'fusee',
    'chateau',
  };

  // Un seul plein écran à la fois. Les cadeaux qui arrivent pendant qu'une
  // animation joue (ou quand il y a déjà des chips) s'affichent en petit dans
  // un coin avec un multiplicateur ×N.
  static bool _fullscreenBusy = false;
  static final Map<String, _ChipData> _chips = {};
  static OverlayEntry? _chipEntry;
  static VoidCallback? _refreshChips;

  static String _normalize(String name) {
    var s = name.toLowerCase().trim();
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'û': 'u', 'ù': 'u', 'ü': 'u',
      'ç': 'c', 'œ': 'oe',
    };
    accents.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  static void showGiftAnimation({
    required BuildContext context,
    required String giftImagePath,
    required String giftName,
    required String userName,
  }) {
    final key = _normalize(giftName);
    final hasVideo = _videoGifts.contains(key);

    // SOLO (rien d'autre en cours) -> plein écran.
    if (!_fullscreenBusy && _chips.isEmpty) {
      if (hasVideo) {
        _fullscreenBusy = true;
        showDialog(
          context: context,
          barrierDismissible: true,
          // Barrière transparente : l'animation (fond noir rendu invisible par
          // le blend "screen") passe par-dessus le live sans masquer l'artiste.
          barrierColor: Colors.transparent,
          builder: (_) => _GiftVideoOverlay(
            assetPath: 'assets/animations/$key.mp4',
            giftName: giftName,
            userName: userName,
          ),
        ).then((_) => _fullscreenBusy = false);
        return;
      }
      // Cadeau sans vidéo -> petite carte image statique (3 s).
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(const Duration(seconds: 3), () {
            if (Navigator.canPop(Get.context!)) Navigator.pop(Get.context!);
          });
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                giftImagePath.isNotEmpty
                    ? ImageWidget(
                        url: '${APIs.giftImageIP}/$giftImagePath',
                        width: 80,
                        height: 80,
                      )
                    : Image.asset('assets/gift_icon.png', width: 80, height: 80),
                const SizedBox(height: 8),
                Text(
                  '$giftName 🎁',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'de $userName',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    // MULTIPLE / occupé -> chip compact dans un coin avec ×N.
    _bumpChip(context, key, giftName);
  }

  static void _bumpChip(BuildContext context, String key, String giftName) {
    final existing = _chips[key];
    if (existing != null) {
      existing.count += 1;
      existing.resetTimer();
    } else {
      final data = _ChipData(giftName: giftName);
      data.onExpire = () {
        _chips.remove(key);
        _refreshChips?.call();
        if (_chips.isEmpty) {
          _chipEntry?.remove();
          _chipEntry = null;
          _refreshChips = null;
        }
      };
      data.startTimer();
      _chips[key] = data;
    }

    if (_chipEntry == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _chipEntry = OverlayEntry(
        builder: (_) => _GiftChipsOverlay(
          chips: _chips,
          bind: (fn) => _refreshChips = fn,
        ),
      );
      overlay.insert(_chipEntry!);
    }
    _refreshChips?.call();
  }
}

class _ChipData {
  _ChipData({required this.giftName, this.count = 1});
  final String giftName;
  int count;
  Timer? _timer;
  VoidCallback? onExpire;

  void startTimer() {
    _timer = Timer(const Duration(seconds: 3), () => onExpire?.call());
  }

  void resetTimer() {
    _timer?.cancel();
    startTimer();
  }
}

// Pile de chips compacts (coin bas-gauche) : un par type de cadeau, avec ×N.
class _GiftChipsOverlay extends StatefulWidget {
  const _GiftChipsOverlay({required this.chips, required this.bind});
  final Map<String, _ChipData> chips;
  final void Function(VoidCallback) bind;

  @override
  State<_GiftChipsOverlay> createState() => _GiftChipsOverlayState();
}

class _GiftChipsOverlayState extends State<_GiftChipsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.bind(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.chips.values.toList();
    return Positioned(
      left: 12,
      bottom: 200,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (c) => Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/gift_icon.png', width: 22, height: 22),
                      const SizedBox(width: 6),
                      Text(
                        c.giftName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '×${c.count}',
                        style: const TextStyle(
                          color: Color(0xffE6C76A),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// Overlay vidéo plein écran : joue l'animation une fois puis se ferme.
class _GiftVideoOverlay extends StatefulWidget {
  const _GiftVideoOverlay({
    required this.assetPath,
    required this.giftName,
    required this.userName,
  });

  final String assetPath;
  final String giftName;
  final String userName;

  @override
  State<_GiftVideoOverlay> createState() => _GiftVideoOverlayState();
}

class _GiftVideoOverlayState extends State<_GiftVideoOverlay> {
  VideoPlayerController? _controller;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;
    controller.setVolume(0); // muet : ne pas couvrir l'audio du live
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
    }).catchError((_) {
      _close();
    });
    controller.addListener(_onTick);
    Future.delayed(const Duration(seconds: 6), _close);
  }

  void _onTick() {
    final c = _controller;
    if (_closed || c == null) return;
    final v = c.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      _close();
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: _close,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width,
                maxHeight: size.height * 0.75,
              ),
              child: ready
                  ? _BlendMask(
                      blendMode: BlendMode.screen,
                      child: AspectRatio(
                        aspectRatio:
                            c.value.aspectRatio == 0 ? 1 : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    )
                  : const SizedBox(
                      width: 120,
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.giftName} 🎁',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'de ${widget.userName}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

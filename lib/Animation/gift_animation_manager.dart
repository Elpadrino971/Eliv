import 'package:artist/Global/api.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

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

  // Normalise un nom de cadeau (accents/casse/espaces) pour le mapper au
  // fichier vidéo : "Cœur"/"Coeur" -> coeur, "Étoile" -> etoile, "Château" ->
  // chateau, "Fusée" -> fusee…
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

    // Cadeau avec vidéo -> animation plein écran.
    if (_videoGifts.contains(key)) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => _GiftVideoOverlay(
          assetPath: 'assets/animations/$key.mp4',
          giftName: giftName,
          userName: userName,
        ),
      );
      return;
    }

    // Repli : image statique (3 s) comme avant.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(Get.context!)) {
            Navigator.pop(Get.context!);
          }
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
                '$giftName Gift!',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'from $userName',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Overlay vidéo : joue l'animation du cadeau une fois puis se ferme.
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
      // Si la vidéo ne charge pas, on ferme proprement.
      _close();
    });
    controller.addListener(_onTick);
    // Filet de sécurité : fermeture au bout de 6 s même si l'évènement de fin
    // n'arrive pas.
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
    return GestureDetector(
      onTap: _close,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ready
                ? AspectRatio(
                    aspectRatio: c.value.aspectRatio == 0
                        ? 1
                        : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  )
                : const SizedBox(
                    width: 120,
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
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

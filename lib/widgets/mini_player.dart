import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Mini-lecteur global façon YouTube.
///
/// Quand on regarde un replay / clip en plein écran (ReplayPlayerScreen), on
/// peut le RÉDUIRE : le lecteur vidéo (déjà initialisé) est « adopté » par ce
/// contrôleur global — la vidéo NE S'ARRÊTE PAS — et une petite carte flottante
/// apparaît au-dessus de toute l'app. On continue à naviguer partout ; un tap
/// sur la carte ré-agrandit, la croix ferme.
///
/// La carte est montée une seule fois, au-dessus du Navigator (voir
/// [MiniPlayerHost] branché dans le builder de GetMaterialApp), pour survivre
/// aux changements de page.
class MiniPlayerController extends GetxController {
  static MiniPlayerController get to => Get.find<MiniPlayerController>();

  /// Lecteur vidéo en cours (partagé entre plein écran et mini-carte).
  final Rxn<VideoPlayerController> controller = Rxn<VideoPlayerController>();

  /// La mini-carte est-elle affichée ? (false pendant le plein écran).
  final RxBool visible = false.obs;

  /// Position de la carte (coin haut-gauche), déplaçable au doigt.
  final Rx<Offset?> pos = Rx<Offset?>(null);

  // Paramètres nécessaires pour ré-ouvrir le plein écran à l'identique.
  String? _url;
  String? _playbackId;
  String? _title;
  bool _isLive = false;
  bool _forceLandscape = false;
  Event? _event;

  /// Le plein écran nous confie son lecteur (réduction). La vidéo continue.
  void attach({
    required VideoPlayerController c,
    String? url,
    String? playbackId,
    String? title,
    bool isLive = false,
    bool forceLandscape = false,
    Event? event,
  }) {
    final prev = controller.value;
    if (prev != null && prev != c) prev.dispose();
    controller.value = c;
    _url = url;
    _playbackId = playbackId;
    _title = title;
    _isLive = isLive;
    _forceLandscape = forceLandscape;
    _event = event;
    visible.value = true;
  }

  /// Ré-agrandit : ré-ouvre le plein écran en RÉUTILISANT le même lecteur.
  Future<void> maximize() async {
    final c = controller.value;
    if (c == null) return;
    visible.value = false; // cache la carte pendant le plein écran
    await Get.to(
      () => ReplayPlayerScreen(
        url: _url,
        playbackId: _playbackId,
        title: _title,
        isLive: _isLive,
        forceLandscape: _forceLandscape,
        event: _event,
        adopt: c,
      ),
    );
    // Au retour : si le plein écran n'a ni réduit ni fermé (retour système),
    // il aura, selon le cas, ré-attaché ou fermé. Rien à faire ici.
  }

  /// Ré-affiche la mini-carte (ex. retour système depuis le plein écran adopté,
  /// sans réduction ni fermeture explicite) tant qu'un lecteur est vivant.
  void restore() {
    if (controller.value != null) visible.value = true;
  }

  /// Ferme définitivement : coupe et libère le lecteur.
  void close() {
    controller.value?.dispose();
    controller.value = null;
    visible.value = false;
    pos.value = null;
  }
}

/// Monté au-dessus de toute l'app (builder de GetMaterialApp). Affiche la
/// mini-carte flottante quand un lecteur est réduit.
class MiniPlayerHost extends StatelessWidget {
  const MiniPlayerHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MiniPlayerController>()) {
      Get.put(MiniPlayerController(), permanent: true);
    }
    final ctrl = MiniPlayerController.to;
    return Stack(
      children: [
        child,
        // Positioned.fill -> l'Obx reçoit tout l'écran ; la carte se place
        // elle-même dans son propre Stack (un Positioned ne peut pas être
        // renvoyé directement par un Obx sous un Stack).
        Positioned.fill(
          child: Obx(() {
            final c = ctrl.controller.value;
            if (!ctrl.visible.value || c == null) {
              return const SizedBox.shrink();
            }
            return _MiniCard(ctrl: ctrl, video: c);
          }),
        ),
      ],
    );
  }
}

class _MiniCard extends StatefulWidget {
  const _MiniCard({required this.ctrl, required this.video});
  final MiniPlayerController ctrl;
  final VideoPlayerController video;

  @override
  State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard> {
  static const double _w = 172;
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ar = widget.video.value.aspectRatio;
    final h = _w / (ar <= 0 ? (16 / 9) : ar);
    final maxX = (media.size.width - _w - 8).clamp(8.0, double.infinity);
    final maxY =
        (media.size.height - h - media.padding.bottom - 8).clamp(8.0, double.infinity);
    final minY = media.padding.top + 8;

    // Position par défaut : bas-droite, au-dessus de la barre de navigation.
    _pos ??= widget.ctrl.pos.value ?? Offset(maxX, maxY - 70);
    final left = _pos!.dx.clamp(8.0, maxX);
    final top = _pos!.dy.clamp(minY, maxY < minY ? minY : maxY);

    // Un Stack plein écran (transparent hors de la carte -> laisse passer les
    // taps vers l'app en dessous) contenant la carte positionnée librement.
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: GestureDetector(
        onTap: widget.ctrl.maximize,
        onPanUpdate: (d) {
          setState(() => _pos = Offset(left + d.delta.dx, top + d.delta.dy));
          widget.ctrl.pos.value = _pos; // mémorise entre les affichages
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _w,
            height: h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: goldSecondary.withValues(alpha: 0.4)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: widget.video.value.size.width,
                    height: widget.video.value.size.height,
                    child: VideoPlayer(widget.video),
                  ),
                ),
                // Voile léger pour détacher les boutons du fond.
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: widget.ctrl.close,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Play / pause rapide.
                Align(
                  alignment: Alignment.center,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.video,
                    builder: (context, value, _) {
                      return GestureDetector(
                        onTap: () => value.isPlaying
                            ? widget.video.pause()
                            : widget.video.play(),
                        child: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
          ),
        ),
      ],
    );
  }
}

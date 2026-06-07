import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:get/get.dart';

/// Rejoint un live.
///
/// - Si l'event a une **vidéo Mux** (`videoReel` = flux HLS `stream.mux.com`),
///   on joue ce flux dans le lecteur plein écran (mode live).
/// - Sinon, on ouvre le **vrai stream Zego** temps réel (`JoinStream`).
///
/// Renvoie le Future de navigation pour que l'appelant puisse `await`.
Future<dynamic>? joinLive(Event event) {
  final reel = event.videoReel;
  final isMux = reel != null && reel.contains('stream.mux.com');
  if (isMux) {
    return Get.to(
      () => ReplayPlayerScreen(
        url: reel,
        isLive: true,
        title: event.name,
        event: event,
      ),
    );
  }
  return Get.to(() => JoinStream(event: event));
}

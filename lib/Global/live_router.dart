import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:get/get.dart';

/// Vrai si l'URL pointe vers un flux HLS Mux (`stream.mux.com`).
bool isMuxUrl(String? url) => url != null && url.contains('stream.mux.com');

/// Vrai si le concert est terminé (`completed` / `ended`).
bool isEventCompleted(Event event) =>
    event.status == 'completed' || event.status == 'ended';

/// Vrai si le replay de ce concert est lisible : concert terminé, vidéo
/// présente, et fenêtre de replay non expirée (`replay_expired` /
/// `replay_expires_at` renvoyés par le backend, voir helpers.js).
bool hasPlayableReplay(Event event) {
  if (!isEventCompleted(event)) return false;
  final reel = event.videoReel;
  if (reel == null || reel.trim().isEmpty) return false;
  if (event.replayExpired == true) return false;
  final expiresAt = event.replayExpiresAt;
  if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return false;
  return true;
}

/// Rejoint un live (ou son replay).
///
/// - Concert **en direct** (`status == 'live'`) : on ouvre le vrai stream
///   Zego temps réel (`JoinStream`), avec chat / cadeaux / co-host.
///   NB : `mux_live_playback_id` est renseigné par le backend pour TOUT live
///   dont le replay est activé (misc.routes.js `/recording/start` crée le
///   flux Mux qui sert au relais d'enregistrement), pas seulement pour les
///   « concerts PRO » diffusés via Mux. Tant que le relais Zego -> Mux n'est
///   pas validé en production, on ne route donc JAMAIS un fan vers le lecteur
///   HLS pendant un live : il verrait un écran vide avec 20 s de latence.
/// - Concert **terminé** avec un replay Mux lisible : lecteur plein écran.
/// - Sinon : `JoinStream` (comportement historique).
///
/// Renvoie le Future de navigation pour que l'appelant puisse `await`.
Future<dynamic>? joinLive(Event event) {
  if (event.status == 'live') {
    return Get.to(() => JoinStream(event: event));
  }
  final reel = event.videoReel;
  if (hasPlayableReplay(event) && isMuxUrl(reel)) {
    return Get.to(
      () => ReplayPlayerScreen(
        url: reel,
        isLive: false,
        title: event.name,
        event: event,
      ),
    );
  }
  return Get.to(() => JoinStream(event: event));
}

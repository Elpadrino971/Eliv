import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/ZegoCloud/pre_stream_screen.dart';
import 'package:artist/ZegoCloud/pro_live_screen.dart';
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
/// - Concert **en direct en mode « mobile »** (`status == 'live'`, défaut) :
///   on ouvre le vrai stream Zego temps réel (`JoinStream`), avec chat /
///   cadeaux / co-host.
///   NB : `mux_live_playback_id` est renseigné par le backend pour TOUT live
///   dont le replay est activé (misc.routes.js `/recording/start` crée le
///   flux Mux qui sert au relais d'enregistrement). Pour un live MOBILE, on
///   ne route donc JAMAIS un fan vers le lecteur HLS : seul `live_mode ==
///   'pro'` (ci-dessous) décide du lecteur Mux, pas la présence de l'id.
/// - Concert **en direct en mode « pro »** (`live_mode == 'pro'`, régie
///   vidéo OBS/ATEM -> Mux) : lecteur HLS faible latence ([ProLiveScreen])
///   si le backend a renvoyé `mux_live_playback_id` (billet, artiste, admin
///   ou concert gratuit) ; sinon, page d'achat ([CheckOutScreen]).
/// - Concert **terminé** avec un replay Mux lisible : lecteur plein écran.
/// - Sinon : `JoinStream` (comportement historique).
///
/// Renvoie le Future de navigation pour que l'appelant puisse `await`.
Future<dynamic>? joinLive(Event event) {
  if (event.status == 'live' && event.isProLive) {
    return _joinProLive(event);
  }
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

bool _hasPlaybackId(Event event) =>
    (event.muxLivePlaybackId ?? '').trim().isNotEmpty;

/// Concert « pro » en direct. Le playback id n'est renvoyé qu'aux ayants
/// droit (billet, artiste, admin, concert gratuit) : s'il manque, on relit
/// le concert (les listes / la réponse d'achat ne le portent pas toujours)
/// avant de conclure qu'il faut un billet.
Future<dynamic> _joinProLive(Event event) async {
  Event current = event;
  if (!_hasPlaybackId(current) && current.id != null) {
    try {
      final controller = Get.isRegistered<EventController>()
          ? Get.find<EventController>()
          : Get.put(EventController());
      final fresh = await controller.getEventById(current.id.toString());
      if (fresh != null) current = fresh;
    } catch (e) {
      myPrint('joinLive (pro): getEventById -> $e');
    }
  }
  // Playback id présent, ou fan déjà ayant droit (billet / artiste) dont
  // l'id n'est pas encore disponible : l'écran pro relit le concert et
  // réessaie tout seul (message « la régie n'a pas encore commencé »). On
  // ne renvoie donc JAMAIS un détenteur de billet vers l'achat (boucle
  // achat -> checkout).
  final uid = userModel.value.user?.id;
  final bool entitled = uid != null &&
      (current.artistId == uid ||
          (current.ticketBuyerIds ?? const <int>[]).contains(uid));
  if (_hasPlaybackId(current) || entitled) {
    return Get.to(() => ProLiveScreen(event: current));
  }
  return Get.to(() => CheckOutScreen(event: current));
}

/// Salle d'attente (jour J, avant l'heure). Concert « pro » : pas de salle
/// Zego (l'artiste ne s'y connecte jamais), on ouvre directement l'écran
/// pro qui patiente jusqu'à ce que la régie envoie l'image. Sinon :
/// [PreStreamScreen] (comportement historique).
Future<dynamic>? openWaitingRoom(Event event) {
  if (event.isProLive) return _joinProLive(event);
  return Get.to(() => PreStreamScreen(event: event));
}

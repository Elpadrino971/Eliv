import 'dart:async';

import 'package:artist/BottomBar/screens/LiveScreen/create_short_screen.dart';
import 'package:artist/Global/global.dart';
import 'package:get/get.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// « Partager → VYBZZZ » : reçoit une vidéo depuis le partage natif du
/// téléphone (galerie, autre app) et ouvre directement l'écran de création de
/// clip, vidéo déjà chargée.
///
/// AUCUNE API ni validation TikTok : c'est le partage système (iOS Share
/// Extension / Android intent SEND). L'app apparaît dans la feuille « Envoyer à »
/// au même titre que WhatsApp, Snapchat, etc.
class ShareReceiver {
  ShareReceiver._();

  static bool _started = false;
  static StreamSubscription<List<SharedMediaFile>>? _sub;

  /// À appeler une fois l'app prête et l'utilisateur connecté (ex. depuis
  /// l'écran d'accueil). Idempotent.
  static void init() {
    if (_started) return;
    _started = true;

    // Partage reçu pendant que l'app tourne (déjà ouverte).
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handle,
      onError: (_) {},
    );

    // Partage qui a lancé l'app (démarrage à froid) : on lit puis on remet à
    // zéro pour ne pas le rejouer au prochain lancement.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handle(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  static void _handle(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // On ne traite que la 1re vidéo partagée (le reste est ignoré pour l'instant).
    SharedMediaFile? video;
    for (final f in files) {
      if (f.type == SharedMediaType.video) {
        video = f;
        break;
      }
    }
    if (video == null) return;

    // Il faut être connecté pour publier un clip. Sinon on ignore (l'utilisateur
    // pourra repartager après connexion).
    final loggedIn = userModel.value.token != null;
    if (!loggedIn) return;

    // Un frame plus tard pour être sûr que la navigation GetX est prête.
    Future.microtask(() {
      Get.to(() => CreateShortScreen(sharedVideoPath: video!.path));
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}

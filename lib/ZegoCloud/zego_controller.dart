import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:artist/services/api_services.dart';
import 'package:get/get.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class ZegoController extends GetxController {
  final Rx<User?> currentUser = userModel.value.user.obs;

  // Real-time viewer count from Zego
  final RxInt viewerCount = 0.obs;

  // Real-time messages from Zego
  final RxList<ChatMessage> realTimeMessages = <ChatMessage>[].obs;

  // Token de connexion Zego (généré côté serveur, remplace l'appSign en
  // dur). null tant qu'il n'a pas été récupéré : voir fetchZegoToken().
  final Rx<String?> zegoToken = Rx<String?>(null);

  // Cible RTMP Mux pour l'enregistrement du replay (rtmps://.../app/<clé>),
  // récupérée via startRecording(). null si le replay est désactivé, Mux non
  // configuré, ou erreur. C'est cette URL que Zego doit relayer (voir la note
  // relayToMux ci-dessous) pour que Mux enregistre le concert.
  final Rx<String?> muxRtmpUrl = Rx<String?>(null);

  String get userId =>
      currentUser.value?.id?.toString() ??
      "user_${DateTime.now().millisecondsSinceEpoch}";
  String get userName =>
      currentUser.value?.fullName ??
      currentUser.value?.artistName ??
      "User $userId";

  /// À appeler avant d'ouvrir un écran de live (start/join/pré-live) :
  /// récupère un token courte-durée depuis le backend. Retourne false si
  /// l'appel échoue (réseau, backend down…) — l'écran appelant doit alors
  /// afficher une erreur plutôt que de se rabattre sur un secret en dur.
  Future<bool> fetchZegoToken() async {
    try {
      final resp = ApiResponse();
      resp.typeSetter = 'post';
      resp.urlSetter = APIs.zegoTokenAPI;
      final res = await resp.hitAPI();
      if (res is! String || res.split(' ').first == 'error') {
        myPrint('fetchZegoToken: réponse invalide -> $res');
        return false;
      }
      final token = jsonDecode(res)['data']?['token'] as String?;
      if (token == null) {
        myPrint('fetchZegoToken: pas de token dans la réponse -> $res');
        return false;
      }
      zegoToken.value = token;
      return true;
    } catch (e) {
      myPrint('fetchZegoToken: exception -> $e');
      return false;
    }
  }

  /// Démarre l'enregistrement du concert pour le replay : le backend crée un
  /// flux Live Mux (si le replay est activé pour cet event et Mux configuré) et
  /// renvoie l'URL RTMP à relayer. Stocke muxRtmpUrl. Retourne l'URL RTMP, ou
  /// null si pas d'enregistrement (replay off / Mux absent / erreur).
  ///
  /// NOTE (dernière étape à brancher + tester en live) : une fois le live Zego
  /// en cours de diffusion, il faut relayer le flux vers muxRtmpUrl pour que
  /// Mux enregistre. Avec le SDK Zego Express, l'appel est :
  ///   ZegoExpressEngine.instance.addPublishCdnUrl(streamID, muxRtmpUrl.value!)
  /// où streamID est l'ID publié par le UIKit (ex: "<liveID>_<userID>_main").
  /// À vérifier contre la version installée du package + tester sur un vrai
  /// live (impossible à valider hors appareil).
  Future<String?> startRecording(String eventId) async {
    try {
      final resp = ApiResponse();
      resp.typeSetter = 'post';
      resp.urlSetter = APIs.recordingStartAPI(eventId);
      final res = await resp.hitAPI();
      if (res is! String || res.split(' ').first == 'error') {
        myPrint('startRecording: réponse invalide -> $res');
        return null;
      }
      final data = jsonDecode(res)['data'] as Map<String, dynamic>?;
      if (data == null || data['recording'] != true) {
        myPrint('startRecording: pas d\'enregistrement -> ${data?['reason']}');
        return null;
      }
      final rtmp = data['rtmp_url'] as String?;
      muxRtmpUrl.value = rtmp;
      myPrint('startRecording: cible RTMP Mux -> $rtmp');
      return rtmp;
    } catch (e) {
      myPrint('startRecording: exception -> $e');
      return null;
    }
  }

  /// Signale la fin de l'enregistrement (Mux finalise l'asset automatiquement).
  Future<void> stopRecording(String eventId) async {
    try {
      final resp = ApiResponse();
      resp.typeSetter = 'post';
      resp.urlSetter = APIs.recordingStopAPI(eventId);
      await resp.hitAPI();
    } catch (e) {
      myPrint('stopRecording: exception -> $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initMessageListener();
  }

  void _initMessageListener() {
    // Use ZegoUIKit.instance (not ZegoUIKit()) for correct access
    ZegoUIKit.instance.getInRoomMessageListStream().listen((
      List<ZegoInRoomMessage> messages,
    ) {
      for (var message in messages) {
        final alreadyExists = realTimeMessages.any(
          (m) => m.message == message.message && m.name == message.user.name,
        );
        if (!alreadyExists) {
          realTimeMessages.add(
            ChatMessage(
              name: message.user.name,
              message: message.message,
              image: '${userModel.value.user?.profileImage}',
            ),
          );
        }
      }
    });
  }

  void sendMessage(String message) {
    // Correct API: ZegoUIKit.instance.sendInRoomMessage
    ZegoUIKit.instance.sendInRoomMessage(message);
  }

  void updateViewerCount(int count) {
    viewerCount.value = count;
  }
}

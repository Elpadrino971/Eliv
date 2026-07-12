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
      if (res is! String || res.split(' ').first == 'error') return false;
      final token = jsonDecode(res)['data']?['token'] as String?;
      if (token == null) return false;
      zegoToken.value = token;
      return true;
    } catch (_) {
      return false;
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

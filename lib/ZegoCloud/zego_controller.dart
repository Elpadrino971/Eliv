import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/ZegoCloud/widgets/live_stream_chat_preview.dart';
import 'package:get/get.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class ZegoController extends GetxController {
  final Rx<User?> currentUser = userModel.value.user.obs;

  // Real-time viewer count from Zego
  final RxInt viewerCount = 0.obs;

  // Real-time messages from Zego
  final RxList<ChatMessage> realTimeMessages = <ChatMessage>[].obs;

  String get userId =>
      currentUser.value?.id?.toString() ??
      "user_${DateTime.now().millisecondsSinceEpoch}";
  String get userName =>
      currentUser.value?.fullName ??
      currentUser.value?.artistName ??
      "User $userId";

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

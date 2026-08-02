import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  final String name;
  final String message;
  final String image;

  ChatMessage({required this.name, required this.message, required this.image});
}

class LiveStreamChatPreview extends StatefulWidget {
  const LiveStreamChatPreview({super.key, required this.messages});
  final List<Activity> messages;

  @override
  State<LiveStreamChatPreview> createState() => _LiveStreamChatPreviewState();
}

class _LiveStreamChatPreviewState extends State<LiveStreamChatPreview> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LiveStreamChatPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widget.messages
              .map(
                (msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ChatMessageTile(
                    name: msg.userInfo?.fullName ?? '',
                    message: msg.description ?? '',
                    image: msg.userInfo?.profileImage ?? '',
                    type: msg.type ?? 'comment',
                    giftImage: msg.gift,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    super.key,
    required this.name,
    required this.message,
    required this.image,
    required this.type,
    this.giftImage,
  });

  final String name;
  final String message;
  final String image;
  final String type;
  final String? giftImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: whiteColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 0,
        leading: ClipOval(
          child: image.startsWith('http')
              ? Image.network(
                  image,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => _placeholderImage(),
                )
              : _placeholderImage(),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: type == 'gift' && giftImage != null
            ? Padding(
                padding: const EdgeInsets.only(top: 5),
                child: ImageWidget(
                  url: '${APIs.giftImageIP}/$giftImage',
                  width: 75,
                  height: 75,

                  fit: BoxFit.contain,
                ),
              )
            : Text(
                message,
                style: const TextStyle(
                  color: whiteColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // Avatar neutre (pas de vraie photo) : une vraie photo stock d'un visage
  // humain était affichée comme si c'était CELLE de l'utilisateur sans photo
  // -> icône générique à la place, comme partout ailleurs dans l'app.
  Widget _placeholderImage() {
    return Container(
      width: 40,
      height: 40,
      color: greyColor.withValues(alpha: 0.3),
      child: const Icon(Icons.person, color: whiteColor, size: 24),
    );
  }
}

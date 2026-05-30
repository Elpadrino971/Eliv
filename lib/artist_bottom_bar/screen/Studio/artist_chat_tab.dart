import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ArtistChatScreen extends StatefulWidget {
  const ArtistChatScreen({
    super.key,
    required this.activities,
    required this.eventId,
  });
  final List<Activity> activities;
  final String eventId;

  @override
  State<ArtistChatScreen> createState() => _ArtistChatScreenState();
}

class _ArtistChatScreenState extends State<ArtistChatScreen> {
  final eventController = Get.find<EventController>();
  final ScrollController _scrollController = ScrollController();
  final messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant ArtistChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activities.length != oldWidget.activities.length) {
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
    messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (eventController.hasAbusiveWords(text)) {
      myWarningDialog(subtitle: 'Your message contains restricted words.');
      return;
    }

    messageController.clear();
    FocusScope.of(context).unfocus();

    await eventController.getEventComments(
      eventId: widget.eventId,
      comment: text,
    );
    // Refreshing is handled by parent timer, but we could manually trigger it here too
  }

  @override
  Widget build(BuildContext context) {
    final chatActivities =
        widget.activities.where((a) => a.type != 'gift').toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemBuilder: (context, index) {
              final msg = chatActivities[index];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.userInfo?.fullName ?? 'anonymous',
                    style: const TextStyle(
                      color: Color(0xffA1A1A1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  height(0.01),
                  MyContainer(
                    padding: const EdgeInsets.all(10),
                    widget: Text(
                      msg.description ?? '',
                      style: const TextStyle(
                        color: Color(0xff404040),
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
            separatorBuilder: (context, index) => height(0.015),
            itemCount: chatActivities.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: MyTextField(
                  hintText: 'Message fans...',
                  controller: messageController,
                ),
              ),
              width(0.02),
              GestureDetector(
                onTap: _sendMessage,
                child: MyContainer(
                  padding: const EdgeInsets.all(11),
                  color: Get.isDarkMode ? redColor : mainThemeColor,
                  noWidth: true,
                  widget: const Icon(
                    Icons.arrow_forward,
                    color: whiteColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

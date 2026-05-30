import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/gift_model.dart';
import 'package:artist/ZegoCloud/zego_controller.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ZegoGifts extends StatefulWidget {
  const ZegoGifts({super.key, required this.eventId, required this.onGiftSent});
  final String eventId;
  final Function(List<Activity>) onGiftSent;

  @override
  State<ZegoGifts> createState() => _ZegoGiftsState();
}

class _ZegoGiftsState extends State<ZegoGifts> {
  final eventController = Get.find<EventController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Get.isDarkMode ? darkmodeColor : whiteColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Send Gift',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          height(0.02),
          Expanded(
            child: Obx(() {
              final gifts = eventController.gifts.value.data ?? [];
              if (gifts.isEmpty) {
                return const Center(child: Text('No gifts available'));
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.85,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  return GiftSelectionCard(
                    gift: gift,
                    onTap: () => _confirmSendGift(gift),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _confirmSendGift(Datum gift) async {
    final userPoints = int.tryParse(userModel.value.user?.points ?? '0') ?? 0;
    final giftCost = int.tryParse(gift.coins ?? '0') ?? 0;

    if (userPoints < giftCost) {
      myWarningDialog(
        subtitle: 'You do not have enough coins to send this gift.',
      );
      return;
    }

    await myAlertDialog(
      title: 'Send ${gift.name}',
      content: 'Spend ${gift.coins} coins to send this gift?',
      onTap: () async {
        Get.back(); // close dialog
        Get.back(); // close bottom sheet

        // Trigger local animation for the sender
        GiftAnimationManager.showGiftAnimation(
          context: context,
          giftImagePath: gift.image ?? 'assets/gift_icon.png',
          giftName: gift.name ?? 'Gift',
          userName: Get.find<ZegoController>().userName,
        );

        final updatedActivities = await eventController.sendGift(
          eventId: widget.eventId,
          giftId: gift.id.toString(),
        );

        if (updatedActivities != null) {
          widget.onGiftSent(updatedActivities);
        }
      },
    );
  }
}

class GiftSelectionCard extends StatelessWidget {
  const GiftSelectionCard({super.key, required this.gift, required this.onTap});

  final Datum gift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Get.isDarkMode ? midnightSecondary : boxColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: goldSecondary.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: gift.image != null && gift.image!.isNotEmpty
                  ? ImageWidget(
                      url: '${APIs.giftImageIP}/${gift.image}',
                      width: 120,
                      height: 120,
                    )
                  : Image.asset('assets/gift_icon.png'),
            ),
            height(0.01),
            Text(
              gift.name ?? 'Gift',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            height(0.005),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: goldPrimary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${gift.coins} Coins',
                  style: const TextStyle(
                    color: goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:artist/Animation/gift_animation_manager.dart';
import 'package:artist/BottomBar/screens/profile/user_wallet.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/gift_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/ZegoCloud/zego_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Emoji de repli d'un cadeau, déduit de son nom (ou de son fichier image) :
/// affiché si l'image ne charge pas, au lieu du visuel « no image ».
String giftFallbackEmoji(Datum gift) {
  final key = '${gift.name ?? ''} ${gift.image ?? ''}'.toLowerCase();
  if (key.contains('rose')) return '🌹';
  if (key.contains('coeur') || key.contains('cœur') || key.contains('heart')) {
    return '❤️';
  }
  if (key.contains('etoile') || key.contains('étoile') || key.contains('star')) {
    return '⭐';
  }
  if (key.contains('diamant') || key.contains('diamond')) return '💎';
  if (key.contains('couronne') || key.contains('crown')) return '👑';
  if (key.contains('flamme') || key.contains('feu') || key.contains('fire')) {
    return '🔥';
  }
  if (key.contains('fusée') || key.contains('fusee') || key.contains('rocket')) {
    return '🚀';
  }
  if (key.contains('chateau') || key.contains('château') || key.contains('castle')) {
    return '🏰';
  }
  return '🎁';
}

class ZegoGifts extends StatefulWidget {
  const ZegoGifts({super.key, required this.eventId, required this.onGiftSent});
  final String eventId;
  final Function(List<Activity>) onGiftSent;

  @override
  State<ZegoGifts> createState() => _ZegoGiftsState();
}

class _ZegoGiftsState extends State<ZegoGifts> {
  final eventController = Get.find<EventController>();

  int get _balance {
    final raw = (userModel.value.user?.points ?? '0').trim();
    return int.tryParse(raw) ?? double.tryParse(raw)?.round() ?? 0;
  }

  // Solde du fan + raccourci vers le portefeuille (recharge de points).
  Widget _balanceRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: cardDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => Text(
                'gift_balance'.trParams({'n': '$_balance'}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // ferme la feuille : le live reste en dessous
              Get.to(() => const UserWallet());
            },
            style: TextButton.styleFrom(
              foregroundColor: goldPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            child: Text(
              'gift_recharge'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: midnightSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'live_send_gift'.tr,
                  style: const TextStyle(
                    color: ivory,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: ivory),
                ),
              ],
            ),
            _balanceRow(),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                final gifts = eventController.gifts.value.data ?? [];
                if (gifts.isEmpty) {
                  return Center(
                    child: Text(
                      'live_no_gifts'.tr,
                      style: const TextStyle(color: textMuted),
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
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
      ),
    );
  }

  void _confirmSendGift(Datum gift) async {
    final userPoints = _balance;
    final giftCost = gift.cost;

    if (userPoints < giftCost) {
      myWarningDialog(
        subtitle: 'live_not_enough_coins'.tr,
      );
      return;
    }

    await myAlertDialog(
      title: 'live_send_x'.trParams({'name': '${gift.name}'}),
      content: 'live_spend_coins'.trParams({'coins': '$giftCost'}),
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
          // Le serveur a débité le fan : on répercute localement pour que le
          // solde affiché (et le contrôle « solde insuffisant ») reste juste.
          final u = userModel.value.user;
          if (u != null && giftCost > 0) {
            final left = userPoints - giftCost;
            userModel.value = userModel.value.copyWith(
              user: u.copyWith(user: User(points: '${left < 0 ? 0 : left}')),
            );
          }
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

  Widget _emoji() => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        giftFallbackEmoji(gift),
        style: const TextStyle(fontSize: 40),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final image = gift.image?.trim() ?? '';
    final url = image.startsWith('http') ? image : '${APIs.giftImageIP}/$image';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: goldSecondary.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Flexible : l'icône rétrécit sur les petits écrans (pas de
            // débordement de la carte), 64 px au maximum.
            Flexible(
              child: SizedBox(
                width: 64,
                height: 64,
                child: image.isEmpty
                    ? _emoji()
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox.shrink(),
                        errorWidget: (context, url, error) => _emoji(),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              gift.name ?? 'Gift',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ivory,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '🪙 ${gift.cost}',
              style: const TextStyle(
                color: goldPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

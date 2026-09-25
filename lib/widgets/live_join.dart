import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/ZegoCloud/pre_stream_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Avatar avec anneau « LIVE » (façon TikTok) quand l'artiste est en direct.
/// Au tap : [onTap] (généralement -> showLiveJoinSheet).
/// Réutilisable PARTOUT où on affiche un avatar d'artiste (feed, clips,
/// artistes en vedette, profil, recherche…).
class LiveRingAvatar extends StatelessWidget {
  const LiveRingAvatar({
    super.key,
    required this.imageUrl,
    required this.isLive,
    this.size = 64,
    this.onTap,
    this.placeholder,
  });

  final String? imageUrl;
  final bool isLive;
  final double size;
  final VoidCallback? onTap;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => _fallback(),
            )
          : _fallback(),
    );

    if (!isLive) {
      return onTap == null ? avatar : GestureDetector(onTap: onTap, child: avatar);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF2D55), Color(0xFFFF6B00), Color(0xFFE6C76A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              child: avatar,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() =>
      placeholder ??
      Container(
        width: size,
        height: size,
        color: const Color(0xFF1A2238),
        child: const Icon(Icons.person, color: Colors.white54),
      );
}

/// Bandeau « Rejoindre le live » qui glisse par le bas de la page ACTUELLE
/// (pas de changement de page). Montant -> paiement inline -> transfert dans
/// le live. Réutilise le tunnel billet existant (IAP ticket_XX + /buy-ticket).
Future<void> showLiveJoinSheet(User artist) async {
  final liveId = artist.liveEventId;
  if (liveId == null) return;

  final eventCtrl = Get.isRegistered<EventController>()
      ? Get.find<EventController>()
      : Get.put(EventController());
  final price = double.tryParse(artist.liveTicketPrice ?? '0') ?? 0;
  final priceLabel = price <= 0 ? 'Gratuit' : '${price.toStringAsFixed(2)} €';

  Future<void> join() async {
    myLoadingDialog();
    final fetched = await eventCtrl.getEventById(liveId.toString());
    Get.back(); // ferme le loader
    if (fetched == null) {
      myWarningDialog(subtitle: 'Live indisponible, réessaie.');
      return;
    }
    Event event = fetched;
    final p = double.tryParse(event.ticketPrice ?? '0') ?? 0;
    final uid = userModel.value.user?.id;
    final hasTicket = (event.ticketBuyerIds ?? []).contains(uid);

    if (!hasTicket) {
      // Concert payant : achat IAP inline (le gratuit saute cette étape).
      if (p > 0) {
        final sub = Get.isRegistered<SubscriptionController>()
            ? Get.find<SubscriptionController>()
            : Get.put(SubscriptionController());
        myLoadingDialog();
        final paid = await sub.purchaseByProductId('ticket_${p.floor()}');
        Get.back();
        if (!paid) {
          myWarningDialog(
            title: sub.lastPurchaseCancelled ? 'common_info'.tr : null,
            subtitle: sub.lastPurchaseCancelled
                ? 'pay_cancelled'.tr
                : 'pay_not_completed'.tr,
          );
          return;
        }
      }
      // Enregistre l'accès (billet gratuit, ou après paiement vérifié serveur).
      myLoadingDialog();
      final updated = await eventCtrl.registerTicketAndGet(event.id.toString());
      Get.back();
      if (updated != null) event = updated;
    }

    Get.back(); // ferme le bandeau
    Get.to(() => PreStreamScreen(event: event));
  }

  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1430),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              LiveRingAvatar(
                imageUrl: artist.artistProfile ?? artist.profileImage,
                isLive: true,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.artistName ?? artist.fullName ?? 'Artiste',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFFFF2D55), size: 9),
                        SizedBox(width: 6),
                        Text(
                          'En direct maintenant',
                          style: TextStyle(color: Color(0xFFC9C4B4), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Billet', style: TextStyle(color: Color(0xFF96A0C2), fontSize: 11)),
                  Text(
                    priceLabel,
                    style: const TextStyle(
                      color: Color(0xFFE6C76A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6C76A),
                foregroundColor: const Color(0xFF0A1226),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: join,
              child: Text(
                price <= 0 ? 'Rejoindre le live' : 'Payer $priceLabel et rejoindre',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: false,
  );
}

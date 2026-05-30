import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveEventsCards extends StatelessWidget {
  const LiveEventsCards({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => FutureScreen(event: event)),
      child: Container(
        width: Get.width * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: kGoldBorder,
          boxShadow: kCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                '${APIs.eventImageIP}/${event.coverImage}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: cardDeep),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : Container(color: cardDeep),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: kImageOverlay),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _liveBadge(),
                        const SizedBox(width: 8),
                        Flexible(child: _genrePill()),
                        const Spacer(),
                        Text(
                          '\$${event.ticketPrice}',
                          style: const TextStyle(
                            color: ivory,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        ClipOval(
                          child: ImageWidget(
                            url: '${event.artist?.profileImage}',
                            height: 32,
                            width: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                event.name?.capitalize ?? 'N/A',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ivory,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                (event.artist?.artistName ?? 'N/A')
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              Get.to(() => CheckOutScreen(event: event)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: kGoldGradient,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'JOIN LIVE',
                              style: TextStyle(
                                color: midnightPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: liveRed,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 7),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _genrePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.5)),
      ),
      child: Text(
        event.genre?.genre?.capitalize ?? 'N/A',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ivory,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

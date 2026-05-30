import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({super.key, required this.event});
  final Event event;

  bool get _isLive =>
      event.startDateTime != null &&
      event.endDateTime != null &&
      DateTime.now().isAfter(event.startDateTime!) &&
      DateTime.now().isBefore(event.endDateTime!);

  /// 12800 -> "12.8K"
  String _formatCount(int? value) {
    final v = value ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Get.width,
      height: Get.height * 0.46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image de concert (cinématique)
          Image.network(
            '${APIs.eventImageIP}/${event.coverImage}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Image.asset('assets/background4.png', fit: BoxFit.cover),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : Container(color: cardDeep),
          ),

          // ── Overlay bleu nuit pour la lisibilité
          const DecoratedBox(
            decoration: BoxDecoration(gradient: kImageOverlay),
          ),

          // ── Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _glassChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/location_icon.png',
                            width: 16,
                            height: 16,
                            color: goldPrimary,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: Get.width * 0.45,
                            ),
                            child: Text(
                              event.artist?.address ?? 'N/A',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ivory,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _glassChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 15,
                            color: ivory,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatCount(event.joinedUsersCount),
                            style: const TextStyle(
                              color: ivory,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                if (_isLive) _liveBadge(),
                const SizedBox(height: 10),

                Text(
                  event.artist?.fullName ?? 'N/A',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: ivory,
                    fontWeight: FontWeight.w600,
                    fontSize: 30,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.name ?? 'N/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: goldPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Get.to(() => CheckOutScreen(event: event)),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: goldPrimary.withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: midnightPrimary,
                                size: 24,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'JOIN LIVE',
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  color: midnightPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: midnightPrimary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: goldSecondary, width: 1.4),
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: goldPrimary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: liveRed,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 6),
          Text(
            'LIVE NOW',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

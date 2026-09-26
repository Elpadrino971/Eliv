import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:artist/Global/global.dart';
import 'package:get/get.dart';

import 'dart:async';

class NextPerformanceCard extends StatefulWidget {
  const NextPerformanceCard({super.key, required this.event});

  final Event event;

  @override
  State<NextPerformanceCard> createState() => _NextPerformanceCardState();
}

class _NextPerformanceCardState extends State<NextPerformanceCard> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  void _startTimer() {
    _timer?.cancel();
    if (widget.event.startDateTime == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = widget.event.startDateTime!.difference(now);

      if (difference.isNegative) {
        _duration = Duration.zero;
        _timer?.cancel();
      } else {
        _duration = difference;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Container(
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
              '${APIs.eventImageIP}/${widget.event.coverImage}',
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
                      _countdownBadge(),
                      const Spacer(),
                      Text(
                        priceLabel(widget.event.ticketPrice),
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
                          url: '${widget.event.artist?.profileImage}',
                          height: 32,
                          width: 32,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Get.to(
                            () => ArtistDetailScreen(
                              artist: widget.event.artist!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.event.name ?? 'N/A',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ivory,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                (widget.event.artist?.artistName ?? 'N/A')
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
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            Get.to(() => FutureScreen(event: widget.event)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: goldSecondary, width: 1.2),
                          ),
                          child: const Text(
                            'GET TICKET',
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              color: goldPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 1,
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
    );
  }

  Widget _countdownBadge() {
    final showDays = _duration.inDays > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDays) ...[
            _unit(_two(_duration.inDays), 'DAY'),
            _sep(),
          ],
          _unit(_two(_duration.inHours % 24), 'HR'),
          _sep(),
          _unit(_two(_duration.inMinutes % 60), 'MIN'),
        ],
      ),
    );
  }

  Widget _unit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ivory,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          ':',
          style: TextStyle(
            color: goldPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );
}

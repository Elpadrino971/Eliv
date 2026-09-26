import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Chronological "agenda" view: a vertical date rail on the left (day number +
/// weekday in a pill, a vertical timeline connector and a small artist marker
/// square) paired with large concert cards on the right.
///
/// Events are sorted by start date so the rail reads as a timeline. The
/// soonest upcoming concert is highlighted with a gold pill.
class ConcertsTimelineView extends StatelessWidget {
  const ConcertsTimelineView({
    super.key,
    required this.events,
    this.onTapEvent,
  });

  final List<Event> events;
  final void Function(Event event)? onTapEvent;

  @override
  Widget build(BuildContext context) {
    final dated = events.where((e) => e.startDateTime != null).toList()
      ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));

    if (dated.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 24),
      itemCount: dated.length,
      itemBuilder: (context, index) {
        final event = dated[index];
        return _TimelineRow(
          event: event,
          isFirst: index == 0,
          isLast: index == dated.length - 1,
          highlight: index == 0, // soonest concert
          onTap: onTapEvent == null ? null : () => onTapEvent!(event),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.highlight,
    this.onTap,
  });

  final Event event;
  final bool isFirst;
  final bool isLast;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = event.startDateTime!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateRail(
            date: date,
            artistImage: event.artist?.artistProfile,
            isFirst: isFirst,
            isLast: isLast,
            highlight: highlight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _ConcertCard(event: event, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.date,
    required this.artistImage,
    required this.isFirst,
    required this.isLast,
    required this.highlight,
  });

  final DateTime date;
  final String? artistImage;
  final bool isFirst;
  final bool isLast;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;
    final Color dayColor = isDark ? whiteColor : blackColor;

    return SizedBox(
      width: 52,
      child: Column(
        children: [
          // Date pill (day number + weekday)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              gradient: highlight
                  ? const LinearGradient(
                      colors: [vybzzzGoldLight, vybzzzGoldDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: highlight ? null : vybzzzSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlight ? Colors.transparent : vybzzzGoldBorder,
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: TextStyle(
                    color: highlight ? blackColor : dayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('E').format(date).toUpperCase(),
                  style: TextStyle(
                    color: highlight ? blackColor : vybzzzTextSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Connector line + artist marker square
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // vertical line
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: vybzzzGoldBorder,
                    ),
                  ),
                ),
                // artist marker (small rounded square thumbnail)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: vybzzzGold, width: 1.5),
                      color: vybzzzSurface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ImageWidget(
                      url: artistImage ?? '${APIs.profileIP}/default.png',
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertCard extends StatelessWidget {
  const _ConcertCard({required this.event, this.onTap});

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = event.startDateTime!;
    final dateStr = DateFormat('d MMMM, h:mma').format(date);
    final price = event.ticketPrice;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: Get.height * 0.24,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageWidget(
                url: '${APIs.eventImageIP}/${event.coverImage}',
                fit: BoxFit.cover,
              ),
              // Bottom dark gradient for legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        blackColor.withValues(alpha: 0.1),
                        blackColor.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              // "From $price" pill
              if (price != null && price.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: blackColor.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: vybzzzGoldBorder),
                    ),
                    child: Text(
                      (double.tryParse(price) ?? 0) <= 0
                          ? 'common_free'.tr
                          : 'From $price €',
                      style: const TextStyle(
                        color: whiteColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              // Artist + venue + date
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.artist?.artistName ??
                          event.artist?.fullName ??
                          event.name ??
                          'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: whiteColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.artist?.address ?? event.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: vybzzzTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: whiteColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
}

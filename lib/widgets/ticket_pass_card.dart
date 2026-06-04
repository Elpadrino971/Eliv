import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Premium "concert pass" ticket card for the Tickets screen.
///
/// Layout: full-bleed artist/cover image header with status badge, a notched
/// perforation line (the classic ticket cut-out), an info grid
/// (date / time / location / seat) and a decorative barcode + ticket id.
///
/// NOTE: the barcode is a deterministic vector pattern derived from the ticket
/// id — it is decorative, not a scannable Code-128. To make it scannable later,
/// add the `barcode_widget` (or `qr_flutter`) package and swap [_BarcodeStrip].
class TicketPassCard extends StatelessWidget {
  const TicketPassCard({
    super.key,
    required this.event,
    this.isPast = false,
    this.previewAsset,
  });

  final Event event;
  final bool isPast;

  /// Optional local asset (e.g. 'assets/artist_image5.png') used instead of the
  /// network cover/avatar. For the demo preview only — leave null for real
  /// tickets so the artist's real images load from the server.
  final String? previewAsset;

  String get _ticketId {
    final ticket = (event.tickets != null && event.tickets!.isNotEmpty)
        ? event.tickets!.first
        : null;
    final raw = ticket?.receiptNumber ?? 'VBZ-${event.id ?? '0000'}';
    return raw.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Color pageColor = Theme.of(context).scaffoldBackgroundColor;
    final start = event.startDateTime;
    final dateStr = start != null ? DateFormat('dd MMM yyyy').format(start) : '—';
    final timeStr = start != null ? DateFormat('hh:mm a').format(start) : '—';

    return Container(
      decoration: BoxDecoration(
        color: vybzzzSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: vybzzzGoldBorder),
        boxShadow: [
          BoxShadow(
            color: blackColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(event: event, isPast: isPast, previewAsset: previewAsset),
          _Perforation(notchColor: pageColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(label: 'DATE', value: dateStr),
                    ),
                    Expanded(
                      child: _InfoBlock(label: 'TIME', value: timeStr),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        label: 'LOCATION',
                        value: event.artist?.address ?? 'TBA',
                      ),
                    ),
                    Expanded(
                      child: _InfoBlock(
                        label: 'SEAT',
                        value: 'General Admission',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _BarcodeStrip(seed: _ticketId),
                const SizedBox(height: 8),
                Text(
                  'TICKET ID  •  $_ticketId',
                  style: const TextStyle(
                    color: vybzzzTextSecondary,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.event,
    required this.isPast,
    this.previewAsset,
  });

  final Event event;
  final bool isPast;
  final String? previewAsset;

  @override
  Widget build(BuildContext context) {
    final bool isLive = event.status == 'live';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Stack(
        children: [
          previewAsset != null
              ? Image.asset(
                  previewAsset!,
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                )
              : ImageWidget(
                  url: '${APIs.eventImageIP}/${event.coverImage}',
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                ),
          // Dark overlay for legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    blackColor.withValues(alpha: 0.15),
                    blackColor.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          // Status badge
          Positioned(
            top: 12,
            left: 12,
            child: _Badge(
              label: isPast ? 'ATTENDED' : (isLive ? 'LIVE NOW' : 'UPCOMING'),
              color: isPast
                  ? greyColor
                  : (isLive ? const Color(0xffDD0000) : vybzzzGold),
              textColor: isLive || !isPast ? whiteColor : whiteColor,
              filledGold: !isPast && !isLive,
            ),
          ),
          // Artist + event name
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: previewAsset != null
                          ? Image.asset(
                              previewAsset!,
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                            )
                          : ImageWidget(
                              url: event.artist?.artistProfile ??
                                  '${APIs.profileIP}/default.png',
                              width: 26,
                              height: 26,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        event.artist?.artistName ??
                            event.artist?.fullName ??
                            'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: vybzzzGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.name ?? 'N/A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.filledGold = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final bool filledGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: filledGold
            ? const LinearGradient(colors: [vybzzzGoldLight, vybzzzGoldDark])
            : null,
        color: filledGold ? null : color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filledGold ? blackColor : textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Notched perforation line that gives the "torn ticket" look.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.notchColor});

  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed line
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: _DashedLine(),
          ),
          // Left notch
          Positioned(
            left: -14,
            child: _Notch(color: notchColor),
          ),
          // Right notch
          Positioned(
            right: -14,
            child: _Notch(color: notchColor),
          ),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: vybzzzGoldBorder),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 5.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1.5,
              color: vybzzzTextSecondary.withValues(alpha: 0.4),
            ),
          ),
        );
      },
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: vybzzzTextSecondary,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Decorative barcode rendered on a white strip (for the classic pass look).
class _BarcodeStrip extends StatelessWidget {
  const _BarcodeStrip({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: whiteColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(
        painter: _BarcodePainter(seed: seed),
        size: Size.infinite,
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter({required this.seed});
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = blackColor;
    // Derive a deterministic bar pattern from the seed characters.
    final units = seed.isEmpty ? [3, 1, 2, 4] : seed.codeUnits;
    double x = 0;
    int i = 0;
    bool bar = true;
    while (x < size.width) {
      final unit = units[i % units.length];
      // bar widths cycle 1..4 px, gaps 1..3 px for a varied look
      final w = bar ? (unit % 4 + 1).toDouble() : (unit % 3 + 1).toDouble();
      if (bar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1;
      bar = !bar;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.seed != seed;
}

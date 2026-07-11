import 'package:artist/Global/colors.dart';
import 'package:artist/Models/susbcription_model.dart';
import 'package:flutter/material.dart';

/// Bright blue used for the featured (Founder) glow + "BEST VALUE" ribbon.
const Color _featuredBlue = Color(0xff2E9BFF);

/// Premium subscription card (VYBZZZ "Choose your plan" style).
///
/// Per-plan background image (assets/plan_<key>.png) under a dark gradient for
/// legibility; falls back to a clean gradient if the asset is missing. Founder
/// gets a blue glow + diagonal "BEST VALUE" ribbon, plus the live seat counter
/// and struck-through public price anchor sent by the backend.
class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final bool showButton;
  final bool isAnnual;
  final String? purchasedDate;
  final VoidCallback? onPurchaseTap;
  final VoidCallback? onWebPurchaseTap;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.showButton = true,
    this.isAnnual = false,
    this.onPurchaseTap,
    this.onWebPurchaseTap,
    this.purchasedDate,
  });

  bool get _featured =>
      (subscription.isFounder ?? false) ||
      (subscription.badge != null && subscription.badge!.isNotEmpty);

  /// Bascule annuelle active ET une equivalence annuelle existe pour ce plan.
  bool get _showAnnual =>
      isAnnual &&
      subscription.annualPrice != null &&
      subscription.annualPrice!.isNotEmpty;

  /// "Economisez $X" (2 mois offerts = 2 x le prix mensuel).
  String? get _annualSavings {
    final monthly = double.tryParse(subscription.price ?? '');
    if (monthly == null) return null;
    final savings = monthly * 2;
    return savings % 1 == 0
        ? savings.toStringAsFixed(0)
        : savings.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final key = _planKey(subscription.title);
    final Color border = _featured ? _featuredBlue : goldSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (_featured ? _featuredBlue : goldPrimary).withValues(
              alpha: _featured ? 0.35 : 0.12,
            ),
            blurRadius: _featured ? 22 : 14,
            spreadRadius: _featured ? 1 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: midnightSecondary,
            border: Border.all(
              color: border.withValues(alpha: _featured ? 0.9 : 0.45),
              width: _featured ? 2 : 1.2,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              // ── Background image (right-weighted) + dark gradient overlay ──
              Positioned.fill(
                child: Image.asset(
                  'assets/plan_$key.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        midnightSecondary.withValues(alpha: 0.80),
                        midnightSecondary.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Content ──
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(key),
                    const SizedBox(height: 14),
                    _commissionRow(),
                    if (_featured) ...[
                      const SizedBox(height: 10),
                      _seatCounter(),
                    ],
                    if (_showAnnual &&
                        subscription.perks != null &&
                        subscription.perks!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _perksList(),
                    ],
                    if (purchasedDate != null) ...[
                      const SizedBox(height: 10),
                      _purchasedRow(),
                    ],
                    if (showButton) ...[
                      const SizedBox(height: 16),
                      _chooseButton(),
                    ],
                    if (onWebPurchaseTap != null) ...[
                      const SizedBox(height: 10),
                      _webPurchaseLink(),
                    ],
                  ],
                ),
              ),

              // ── Diagonal "BEST VALUE" ribbon ──
              if (subscription.badge != null &&
                  subscription.badge!.isNotEmpty)
                _ribbon(subscription.badge!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow(String key) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan icon hexure
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: goldPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: goldSecondary.withValues(alpha: 0.7)),
          ),
          child: Icon(_planIcon(key), color: goldPrimary, size: 26),
        ),
        const SizedBox(width: 12),
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subscription.title ?? 'N/A',
                style: const TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _planSubtitle(key),
                style: TextStyle(
                  color: goldPrimary.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Price
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _showAnnual
              ? _annualPriceLines()
              : _monthlyPriceLines(),
        ),
      ],
    );
  }

  List<Widget> _monthlyPriceLines() {
    return [
      if (subscription.publicPrice != null &&
          subscription.publicPrice!.isNotEmpty)
        Text(
          '\$${subscription.publicPrice}',
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      Text(
        '\$${subscription.price ?? '0'}',
        style: const TextStyle(
          color: whiteColor,
          fontWeight: FontWeight.w900,
          fontSize: 26,
        ),
      ),
      Text(
        _billingLabel(subscription.priceType),
        style: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ];
  }

  /// "2 mois offerts" : prix mensuel barre (x12) + prix annuel + economie.
  List<Widget> _annualPriceLines() {
    final monthly = double.tryParse(subscription.price ?? '');
    final struckThrough = monthly != null
        ? (monthly * 12 % 1 == 0
            ? (monthly * 12).toStringAsFixed(0)
            : (monthly * 12).toStringAsFixed(2))
        : null;
    return [
      if (struckThrough != null)
        Text(
          '\$$struckThrough',
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      Text(
        '\$${subscription.annualPrice}',
        style: const TextStyle(
          color: whiteColor,
          fontWeight: FontWeight.w900,
          fontSize: 26,
        ),
      ),
      const Text(
        '/ year',
        style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      if (_annualSavings != null) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: goldPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'SAVE \$$_annualSavings',
            style: const TextStyle(
              color: goldPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _commissionRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: goldPrimary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.percent_rounded, size: 14, color: goldPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: ivory, fontSize: 13.5),
              children: [
                TextSpan(
                  text: '${subscription.commission ?? '0'}% commission',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' on every transaction',
                  style: TextStyle(color: textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _perksList() {
    final perks = subscription.perks ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: perks
          .map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: goldPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: const TextStyle(
                        color: ivory,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _seatCounter() {
    if (subscription.seatsRemaining == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Text('🔥', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _founderCounterLabel(subscription),
            style: TextStyle(
              color: _featuredBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _purchasedRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Purchased on', style: TextStyle(color: textMuted, fontSize: 13)),
        Text(
          purchasedDate!,
          style: const TextStyle(
            color: ivory,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Chemin "web" (Stripe, 0% commission Apple/Google) — lien secondaire
  /// sous le bouton principal. Le call site ne le passe que sur Android
  /// (anti-steering Apple 3.1.1 : interdit dans l'app iOS).
  Widget _webPurchaseLink() {
    return GestureDetector(
      onTap: onWebPurchaseTap,
      child: Center(
        child: Text(
          'Payer par carte (meilleur prix, web)',
          style: TextStyle(
            color: goldPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: goldPrimary,
          ),
        ),
      ),
    );
  }

  Widget _chooseButton() {
    return GestureDetector(
      onTap: onPurchaseTap ?? () {},
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [goldPrimary, goldSecondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'CHOOSE PLAN',
              style: TextStyle(
                color: midnightPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
            ),
            Positioned(
              right: 16,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: midnightPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ribbon(String text) {
    return Positioned(
      top: 16,
      right: -34,
      child: Transform.rotate(
        angle: 0.7853981, // 45°
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          color: _featuredBlue,
          child: Text(
            text,
            style: const TextStyle(
              color: whiteColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _planKey(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('founder')) return 'founder';
    if (t.contains('growth')) return 'growth';
    if (t.contains('elite')) return 'elite';
    return 'starter';
  }

  IconData _planIcon(String key) {
    switch (key) {
      case 'founder':
        return Icons.star_rounded;
      case 'growth':
        return Icons.trending_up_rounded;
      case 'elite':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  String _planSubtitle(String key) {
    switch (key) {
      case 'founder':
        return 'LIMITED TIME OFFER';
      case 'growth':
        return 'GROW YOUR AUDIENCE';
      case 'elite':
        return 'BEST FOR SCALING';
      default:
        return 'START EASILY';
    }
  }

  /// "63/200 places restantes · +\$149 dans 13"
  String _founderCounterLabel(Subscription s) {
    final remaining = s.seatsRemaining ?? 0;
    final total = s.seatsTotal ?? 200;
    var label = '$remaining/$total places restantes';
    if (s.nextPrice != null && s.nextPriceInSeats != null) {
      label += ' · +\$${s.nextPrice} dans ${s.nextPriceInSeats}';
    }
    return label;
  }

  String _billingLabel(String? priceType) {
    switch (priceType?.toLowerCase()) {
      case 'yearly':
        return '/ year';
      case 'weekly':
        return '/ week';
      default:
        return '/ month';
    }
  }
}

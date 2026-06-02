import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/susbcription_model.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_default_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final bool showButton;
  final String? purchasedDate;
  final VoidCallback? onPurchaseTap;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.showButton = true,
    this.onPurchaseTap,
    this.purchasedDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;
    final Color accentColor = isDark ? goldPrimary : mainThemeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? darkmodeColor : whiteColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header gradient strip ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              border: Border.all(
                color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Expanded(
                  child: Text(
                    subscription.title ?? 'N/A',
                    style: const TextStyle(
                      color: whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Price + billing cycle column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Ancrage prix public (ex: 199) barré au-dessus du prix Founder
                    if (subscription.publicPrice != null &&
                        subscription.publicPrice!.isNotEmpty)
                      Text(
                        '\$${subscription.publicPrice}',
                        style: TextStyle(
                          color: whiteColor.withValues(alpha: 0.7),
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
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      _billingLabel(subscription.priceType),
                      style: TextStyle(
                        color: whiteColor.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commission row
                Row(
                  children: [
                    Icon(Icons.percent_rounded, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: isDark ? whiteColor : blackColor,
                            fontSize: 13.5,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Commission: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text:
                                  '${subscription.commission ?? '0'}% ${_commissionTypeLabel(subscription.commissionType)} commission on every transaction',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Founder launch: badge + live seat counter (only when the
                //    backend marks the plan as Founder; otherwise no-op) ──────
                if (subscription.badge != null &&
                    subscription.badge!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor),
                    ),
                    child: Text(
                      subscription.badge!,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                if ((subscription.isFounder ?? false) &&
                    subscription.seatsRemaining != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _founderCounterLabel(subscription),
                          style: TextStyle(
                            color: isDark ? whiteColor : blackColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                purchasedDate != null
                    ? SizedBox(
                        child: Column(
                          mainAxisSize: .min,
                          children: [
                            height(0.01),

                            Row(
                              mainAxisAlignment: .spaceBetween,
                              children: [
                                MyDefaultText(
                                  text: 'Purchased On:',
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : blackColor,
                                ),
                                MyDefaultText(
                                  text: purchasedDate!,
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : blackColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : SizedBox.shrink(),

                if (showButton) const SizedBox(height: 8),

                // Artists count row
                // if (subscription.artistsCount != null &&
                //     subscription.artistsCount!.isNotEmpty) ...[
                //   Row(
                //     children: [
                //       Icon(Icons.people_outline, size: 16, color: accentColor),
                //       const SizedBox(width: 6),
                //       Text(
                //         'Up to ${subscription.artistsCount} artists',
                //         style: TextStyle(
                //           color: isDark
                //               ? whiteColor.withValues(alpha: 0.75)
                //               : const Color(0xff555555),
                //           fontSize: 13,
                //         ),
                //       ),
                //     ],
                //   ),
                //   const SizedBox(height: 8),
                // ],

                // Divider
                // if (showButton)
                //   Divider(
                //     color: Get.isDarkMode
                //         ? whiteColor.withValues(alpha: 0.5)
                //         : blackColor.withValues(alpha: 0.5),
                //     thickness: 1,
                //   ),
                const SizedBox(height: 8),

                // Purchase button
                if (showButton)
                  MyButton(
                    label: 'Continue',
                    onTap: onPurchaseTap ?? () {},
                    buttonHeight: Get.height * 0.05,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
      case 'monthly':
        return '/ month';
      case 'yearly':
        return '/ year';
      case 'weekly':
        return '/ week';
      default:
        return '/ month';
    }
  }

  String _commissionTypeLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'fixed':
        return 'fixed';
      case 'percentage':
        return '';
      default:
        return '';
    }
  }
}

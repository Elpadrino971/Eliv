import 'dart:async';
import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// ────────────────────────────────────────────────────────────────────────
/// « CE QUE TU GAGNES » — calculateur affiché sous le sélecteur de prix du
/// formulaire de création de concert.
///
///   GET /api/pricing/estimate?price=4.99 (Bearer)
///   -> { price, store_fee_rate, net, artist_rate, artist_share,
///        platform_share, promo, currency, grid }
///
/// Les montants viennent du backend (pas de recalcul côté app). Si l'API
/// échoue, repli local (net = prix × 0,85, part artiste = net × 0,50) marqué
/// « estimation ». Debounce 300 ms sur le prix, cache par prix, appel
/// silencieux (aucun dialogue d'erreur).
/// ────────────────────────────────────────────────────────────────────────

/// Part d'un invité vue par le calculateur : nom + % de la part artiste.
class GuestShare {
  const GuestShare({required this.name, required this.sharePct});

  final String name;
  final int sharePct;
}

/// Résultat de l'estimation (backend ou repli local).
class RevenueEstimate {
  const RevenueEstimate({
    required this.price,
    required this.storeFeeRate,
    required this.net,
    required this.artistRate,
    required this.artistShare,
    required this.platformShare,
    required this.promo,
    required this.currency,
    this.isFallback = false,
  });

  final double price;
  final double storeFeeRate;
  final double net;
  final double artistRate;
  final double artistShare;
  final double platformShare;
  final bool promo;
  final String currency;

  /// true = calcul local car l'API n'a pas répondu : affiché « estimation ».
  final bool isFallback;

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  factory RevenueEstimate.fromJson(Map json, double requestedPrice) {
    final price = _asDouble(json['price'], requestedPrice);
    final net = _asDouble(json['net']);
    final artistShare = _asDouble(json['artist_share']);
    return RevenueEstimate(
      price: price,
      storeFeeRate: _asDouble(json['store_fee_rate'], 0.15),
      net: net,
      artistRate: _asDouble(json['artist_rate'], 0.5),
      artistShare: artistShare,
      platformShare: _asDouble(json['platform_share'], net - artistShare),
      promo: json['promo'] == true || '${json['promo']}' == '1',
      currency: (json['currency'] ?? 'EUR').toString(),
    );
  }

  /// Repli local quand l'API est indisponible.
  factory RevenueEstimate.fallback(double price) {
    final net = price * 0.85;
    final artistShare = net * 0.5;
    return RevenueEstimate(
      price: price,
      storeFeeRate: 0.15,
      net: net,
      artistRate: 0.5,
      artistShare: artistShare,
      platformShare: net - artistShare,
      promo: false,
      currency: 'EUR',
      isFallback: true,
    );
  }
}

// ── Formatage (locale de l'app) ──────────────────────────────────────────

bool _useDecimalComma() {
  final lang = Get.locale?.languageCode ?? 'fr';
  return const {'fr', 'de', 'es', 'it', 'pt', 'ru'}.contains(lang);
}

/// Groupe les milliers avec une espace fine insécable : « 1 245 ».
String _groupThousands(String digits) {
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write(' ');
  }
  return buf.toString();
}

/// « 4,99 € » / « 1 245 € » (decimals = 0). Signe moins typographique.
String formatEuro(double value, {int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = _groupThousands(parts[0]);
  final sep = _useDecimalComma() ? ',' : '.';
  final fraction = decimals > 0 && parts.length > 1 ? '$sep${parts[1]}' : '';
  return '${negative ? '−' : ''}$intPart$fraction €';
}

/// « 15 » pour 0.15, « 58,8 » pour 0.588 (sans le signe %).
String formatRatePct(double rate) {
  final v = rate * 100;
  if ((v - v.roundToDouble()).abs() < 0.05) return '${v.round()}';
  final s = v.toStringAsFixed(1);
  return _useDecimalComma() ? s.replaceAll('.', ',') : s;
}

/// « 1 000 » pour 1000.
String formatInt(int value) => _groupThousands('$value');

// ── Widget ───────────────────────────────────────────────────────────────

class RevenueEstimateCard extends StatefulWidget {
  const RevenueEstimateCard({
    super.key,
    required this.price,
    this.guests = const [],
  });

  /// Prix du billet (0 = concert gratuit).
  final double price;

  /// Invités et leur % de la part artiste (peut être vide).
  final List<GuestShare> guests;

  @override
  State<RevenueEstimateCard> createState() => _RevenueEstimateCardState();
}

class _RevenueEstimateCardState extends State<RevenueEstimateCard> {
  /// Cache par prix (clé = prix à 2 décimales), partagé entre instances.
  /// Les replis locaux ne sont pas mis en cache : on retente au prochain prix.
  static final Map<String, RevenueEstimate> _cache = {};

  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const List<int> _audiences = [100, 500, 1000];

  Timer? _debounce;
  int _seq = 0;
  RevenueEstimate? _estimate;
  bool _loading = false;

  String get _priceKey => widget.price.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _applyPrice(immediate: true);
  }

  @override
  void didUpdateWidget(covariant RevenueEstimateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price.toStringAsFixed(2) != _priceKey) {
      // Le framework rebuild juste après didUpdateWidget : pas de setState.
      _applyPrice(immediate: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Met à jour l'état pour le prix courant (sans setState : appelé depuis
  /// initState / didUpdateWidget, un build suit toujours).
  void _applyPrice({required bool immediate}) {
    _debounce?.cancel();
    _seq++;
    if (widget.price <= 0) {
      _estimate = null;
      _loading = false;
      return;
    }
    final cached = _cache[_priceKey];
    if (cached != null) {
      _estimate = cached;
      _loading = false;
      return;
    }
    _estimate = null;
    _loading = true;
    final int seq = _seq;
    final String key = _priceKey;
    final double price = widget.price;
    if (immediate) {
      _fetch(seq, key, price);
    } else {
      _debounce = Timer(_debounceDelay, () => _fetch(seq, key, price));
    }
  }

  Future<void> _fetch(int seq, String key, double price) async {
    RevenueEstimate result;
    try {
      final req = ApiResponse();
      req.typeSetter = 'get';
      req.urlSetter = APIs.pricingEstimateAPI(key);
      final dynamic value = await req.hitAPI();
      if (value is String && value.split(' ').first != 'error') {
        final decoded = jsonDecode(value);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is Map) {
          result = RevenueEstimate.fromJson(data, price);
          _cache[key] = result;
        } else {
          result = RevenueEstimate.fallback(price);
        }
      } else {
        // Silencieux : pas de dialogue, on affiche le repli « estimation ».
        myPrint('pricing/estimate: $value');
        result = RevenueEstimate.fallback(price);
      }
    } catch (e) {
      myPrint('pricing/estimate: exception -> $e');
      result = RevenueEstimate.fallback(price);
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _estimate = result;
      _loading = false;
    });
  }

  // ── Rendu ──────────────────────────────────────────────────────────────

  Color get _textColor => Get.isDarkMode ? ivory : blackColor;

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Get.isDarkMode ? cardDeep : const Color(0xffF6F1E4),
    borderRadius: BorderRadius.circular(15),
    border: kGoldBorder,
  );

  Widget _title() {
    final est = _estimate;
    return Row(
      children: [
        const Icon(Icons.auto_graph_rounded, color: goldPrimary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'rev_est_title'.tr,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              color: _textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        if (est != null && est.isFallback)
          Text(
            '(${'rev_est_estimate'.tr})',
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    double indent = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 6, left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.body,
                color: bold ? _textColor : textMuted,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              color: valueColor ?? _textColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: goldPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          color: goldPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }

  /// « ×100 spectateurs = 249 € » puis « ×500 = 1 245 € », « ×1 000 = … ».
  String _audienceLabel(int index, double mainShare) {
    final int n = _audiences[index];
    final String prefix = index == 0
        ? 'rev_est_viewers'.trParams({'n': formatInt(n)})
        : '×${formatInt(n)}';
    return '$prefix = ${formatEuro(mainShare * n, decimals: 0)}';
  }

  Widget _freeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_giftcard_rounded, color: goldPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'rev_est_free'.tr,
              style: TextStyle(
                fontFamily: AppFonts.body,
                color: _textColor,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: goldPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.price <= 0) return _freeCard();
    final est = _estimate;
    if (_loading || est == null) return _loadingCard();

    // Frais store = prix − net (cohérent avec les montants du backend).
    final double storeFee = est.price - est.net;

    // Répartition entre l'artiste principal et ses invités : arithmétique
    // simple sur la part artiste renvoyée par le backend.
    final guests = widget.guests;
    final int guestsPct = guests.fold<int>(0, (sum, g) => sum + g.sharePct);
    final int youPct = (100 - guestsPct).clamp(0, 100).toInt();
    final double mainShare = guests.isEmpty
        ? est.artistShare
        : est.artistShare * youPct / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          const SizedBox(height: 4),
          _row('rev_est_ticket_price'.tr, formatEuro(est.price)),
          _row(
            'rev_est_store_fee'.trParams({
              'pct': formatRatePct(est.storeFeeRate),
            }),
            formatEuro(-storeFee),
          ),
          _row('rev_est_net'.tr, formatEuro(est.net)),
          _row(
            'rev_est_your_share'.trParams({
              'pct': formatRatePct(est.artistRate),
            }),
            formatEuro(est.artistShare),
            bold: true,
            valueColor: goldPrimary,
          ),
          _row('rev_est_platform'.tr, formatEuro(est.platformShare)),
          if (guests.isNotEmpty) ...[
            _row(
              '→ ${'rev_est_you'.tr}',
              '$youPct % · ${formatEuro(mainShare)}',
              indent: 8,
              valueColor: goldPrimary,
            ),
            for (final g in guests)
              _row(
                '→ ${g.name}',
                '${g.sharePct} % · '
                    '${formatEuro(est.artistShare * g.sharePct / 100)}',
                indent: 8,
              ),
          ],
          if (est.promo)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'rev_est_promo'.tr,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  color: textMuted,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 10),
          // Projections d'audience (part de l'artiste principal).
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < _audiences.length; i++)
                _audienceChip(_audienceLabel(i, mainShare)),
            ],
          ),
        ],
      ),
    );
  }
}

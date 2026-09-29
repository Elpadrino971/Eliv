import 'dart:convert';

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// ────────────────────────────────────────────────────────────────────────
/// « À LA UNE » — popup plein écran affiché au lancement de l'app (après le
/// splash) ou juste après une connexion / inscription réussie, quand l'admin
/// a mis un concert en avant (GET /api/featured-event).
///
/// Règles :
///  • appel réseau silencieux (timeout court, jamais de dialogue d'erreur) ;
///  • préchargé dès le splash ([prefetchFeaturedEvent]) pour apparaître sans
///    délai ;
///  • une seule apparition par session (drapeau statique) ;
///  • « Plus tard » mémorise la fermeture pour la journée et cet id
///    (`featured_dismissed_<id>` = "yyyy-MM-dd") ;
///  • uniquement pour un utilisateur connecté (à la charge de l'appelant).
/// ────────────────────────────────────────────────────────────────────────

/// Concert à la une tel que renvoyé par l'API.
class FeaturedEvent {
  const FeaturedEvent({
    required this.id,
    required this.event,
    this.headline,
    this.until,
  });

  /// Id de la mise en avant (pas celui du concert) : sert de clé de
  /// mémorisation « fermé aujourd'hui ».
  final int id;
  final String? headline;
  final DateTime? until;
  final Event event;

  bool get isActive => until == null || DateTime.now().isBefore(until!);
}

Future<FeaturedEvent?>? _prefetch;
bool _shownThisSession = false;
bool _checking = false;

/// Lance (une seule fois) l'appel réseau. Un échec réseau (null) n'est pas
/// mis en cache : un appel ultérieur (ex. après connexion) réessaie.
Future<FeaturedEvent?> prefetchFeaturedEvent() {
  return _prefetch ??= _fetchFeaturedEvent().then((value) {
    if (value == null) _prefetch = null;
    return value;
  });
}

Future<FeaturedEvent?> _fetchFeaturedEvent() async {
  try {
    final res = await http
        .get(Uri.parse(APIs.featuredEventAPI))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is! Map) return null;
    final eventJson = data['event'];
    if (eventJson is! Map) return null;
    final event = Event.fromJson(Map<String, dynamic>.from(eventJson));
    if (event.id == null) return null;

    final rawId = data['id'];
    final int id = rawId is int ? rawId : (int.tryParse('$rawId') ?? event.id!);

    DateTime? until;
    final rawUntil = data['until'];
    if (rawUntil is String && rawUntil.trim().isNotEmpty) {
      until = DateTime.tryParse(rawUntil);
    }

    String? headline;
    final rawHeadline = data['headline'];
    if (rawHeadline is String && rawHeadline.trim().isNotEmpty) {
      headline = rawHeadline.trim();
    }

    return FeaturedEvent(id: id, event: event, headline: headline, until: until);
  } catch (e) {
    // Silencieux : pas de popup, l'app continue normalement.
    myPrint('featured-event: $e');
    return null;
  }
}

String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Affiche le popup « À la une » si un concert est mis en avant, actif, et
/// pas déjà fermé aujourd'hui. Ne lève jamais d'exception ; ne s'affiche
/// qu'une fois par session.
Future<void> showFeaturedEventIfAny() async {
  if (_shownThisSession || _checking) return;
  _checking = true;
  try {
    final featured = await prefetchFeaturedEvent();
    if (featured == null || !featured.isActive) return;
    if (_shownThisSession) return;
    final dismissed = box.read('featured_dismissed_${featured.id}');
    if (dismissed != null && dismissed.toString() == _todayKey()) return;

    // Laisse la transition vers l'écran principal se terminer avant
    // d'empiler le popup (sinon il s'ouvre sur l'écran en cours de sortie).
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (Get.context == null) return;

    _shownThisSession = true;
    await Get.dialog<void>(
      FeaturedEventSheet(featured: featured),
      barrierDismissible: false,
      barrierColor: blackColor.withValues(alpha: 0.78),
      useSafeArea: false,
    );
  } catch (e) {
    myPrint('featured-event: $e');
  } finally {
    _checking = false;
  }
}

/// Contenu du popup (fond bleu nuit, coins arrondis, couverture en haut).
class FeaturedEventSheet extends StatelessWidget {
  const FeaturedEventSheet({super.key, required this.featured});

  final FeaturedEvent featured;

  Event get event => featured.event;

  bool get _hasTicket {
    final uid = userModel.value.user?.id;
    if (uid == null) return false;
    if (event.artistId == uid) return true;
    return event.ticketBuyerIds?.contains(uid) ?? false;
  }

  String get _artistName {
    final a = event.artist;
    final name = (a?.artistName ?? '').trim();
    if (name.isNotEmpty) return name;
    return (a?.fullName ?? '').trim();
  }

  /// URL de couverture : nom de fichier sur le backend, ou URL complète
  /// collée telle quelle dans le champ (comme les cartes existantes).
  String? get _coverUrl {
    final cover = (event.coverImage ?? '').trim();
    if (cover.isEmpty) return null;
    if (cover.startsWith('http')) return cover;
    return '${APIs.eventImageIP}/$cover';
  }

  void _dismissForToday() {
    box.write('featured_dismissed_${featured.id}', _todayKey());
    Get.back();
  }

  void _openEvent() {
    Get.back();
    Get.to(() => FutureScreen(event: event));
  }

  Widget _fallbackCover() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardDeep, midnightSecondary, Color(0xff3A2E12)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded, color: goldSecondary, size: 54),
      ),
    );
  }

  Widget _cover() {
    final url = _coverUrl;
    if (url == null) return _fallbackCover();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: cardDeep),
      errorWidget: (_, __, ___) => _fallbackCover(),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: liveRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              featured.headline ?? 'feat_badge'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                color: ivory,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closeButton() {
    return Material(
      color: midnightPrimary.withValues(alpha: 0.72),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _dismissForToday,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.close_rounded, color: ivory, size: 18),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: goldPrimary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = event.startDateTime;
    final dateLabel = start == null
        ? ''
        : '${AppDate.fullDate(start)} · ${AppDate.time(start)}';
    final artist = _artistName;
    final coverHeight = Get.height * 0.34;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Container(
                width: Get.width,
                decoration: BoxDecoration(
                  color: midnightPrimary,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: goldSecondary.withValues(alpha: 0.35),
                  ),
                  boxShadow: kCardShadow,
                ),
                // Défilement de secours sur les petits écrans (iPhone SE).
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Couverture + badge + fermeture
                      SizedBox(
                        height: coverHeight,
                        width: Get.width,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _cover(),
                            const DecoratedBox(
                              decoration: BoxDecoration(gradient: kImageOverlay),
                            ),
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 60,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _badge(),
                              ),
                            ),
                            Positioned(top: 10, right: 10, child: _closeButton()),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 14,
                              child: Text(
                                event.name ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  color: ivory,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Détails
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (artist.isNotEmpty) ...[
                              _metaRow(Icons.mic_rounded, artist),
                              const SizedBox(height: 8),
                            ],
                            if (dateLabel.isNotEmpty) ...[
                              _metaRow(Icons.calendar_today_rounded, dateLabel),
                              const SizedBox(height: 8),
                            ],
                            _metaRow(
                              Icons.confirmation_number_rounded,
                              priceLabel(event.ticketPrice),
                            ),
                            const SizedBox(height: 18),
                            MyButton(
                              label: _hasTicket ? 'feat_view'.tr : 'feat_book'.tr,
                              onTap: _openEvent,
                              buttonHeight: 50,
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: TextButton(
                                onPressed: _dismissForToday,
                                child: Text(
                                  'feat_later'.tr,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.ui,
                                    color: textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

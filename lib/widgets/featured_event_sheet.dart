import 'dart:ui' as ui;
import 'dart:convert';

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/teaser_video.dart';
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
FeaturedEvent? _cached;
bool _shownThisSession = false;
bool _checking = false;

/// Lance (une seule fois) l'appel réseau. Un échec réseau (null) n'est pas
/// mis en cache : un appel ultérieur (ex. après connexion) réessaie.
Future<FeaturedEvent?> prefetchFeaturedEvent() {
  return _prefetch ??= _fetchFeaturedEvent().then((value) {
    if (value == null) {
      _prefetch = null;
    } else {
      _cached = value;
    }
    return value;
  });
}

/// Concert à la une mis en cache par [prefetchFeaturedEvent] (déclenché dès
/// le splash). Renvoie la valeur en cache si elle est encore active, sinon
/// (re)lance l'appel réseau silencieux. Null quand l'admin n'a rien mis à
/// la une (`data: null`), quand la mise en avant est expirée, ou en cas
/// d'échec réseau — l'appelant n'affiche alors simplement rien.
Future<FeaturedEvent?> getFeaturedEvent() async {
  final cached = _cached;
  if (cached != null && cached.isActive) return cached;
  final value = await prefetchFeaturedEvent();
  if (value == null || !value.isActive) return null;
  return value;
}

/// Valeur en cache SANS appel réseau (rendu immédiat), ou null.
FeaturedEvent? get cachedFeaturedEvent {
  final cached = _cached;
  if (cached != null && cached.isActive) return cached;
  return null;
}

/// URL de couverture d'un concert : nom de fichier sur le backend, ou URL
/// complète collée telle quelle dans le champ (comme les cartes existantes).
String? featuredCoverUrl(Event event) {
  final cover = (event.coverImage ?? '').trim();
  if (cover.isEmpty) return null;
  if (cover.startsWith('http')) return cover;
  return '${APIs.eventImageIP}/$cover';
}

/// Couches visuelles « À la une » (popup et carte hero), à empiler dans un
/// Stack `fit: StackFit.expand` : fond flouté (miniature du teaser, sinon
/// l'affiche) + voile sombre + teaser vidéo muet en boucle quand le concert
/// en a un, sinon l'affiche entière (jamais recadrée). [cover] construit la
/// couche image (affiche ou dégradé de secours).
List<Widget> _featuredVisualLayers(
  Event event,
  Widget Function({BoxFit fit}) cover,
) {
  final teaser = teaserUrlOf(event);
  final poster = teaser == null ? null : teaserPosterOf(event);
  final Widget blurSource = poster == null
      ? cover()
      : CachedNetworkImage(
          imageUrl: poster,
          fit: BoxFit.cover,
          // Flouté : une petite image suffit.
          memCacheWidth: 360,
          placeholder: (_, __) => cover(),
          errorWidget: (_, __, ___) => cover(),
        );
  return [
    // Fond : image floutée, pour remplir les bords quand l'affiche ou la
    // vidéo n'a pas le même format que la zone.
    ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: blurSource,
    ),
    const ColoredBox(color: Color(0x66000000)),
    if (teaser == null)
      cover(fit: BoxFit.contain)
    else
      TeaserVideo(
        url: teaser,
        poster: poster ?? featuredCoverUrl(event),
        fit: BoxFit.contain,
        fallback: cover(fit: BoxFit.contain),
      ),
  ];
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

  String? get _coverUrl => featuredCoverUrl(event);

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

  Widget _cover({BoxFit fit = BoxFit.cover}) {
    final url = _coverUrl;
    if (url == null) return _fallbackCover();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
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
    final coverHeight = Get.height * 0.40;

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
                      // ── Affiche en entier (souvent une affiche avec du
                      // texte : jamais recadrée ni recouverte d'un titre).
                      SizedBox(
                        height: coverHeight,
                        width: Get.width,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Fond flouté + affiche entière, ou teaser vidéo
                            // (muet, en boucle) quand le concert en a un.
                            ..._featuredVisualLayers(event, _cover),
                            Positioned(top: 10, right: 10, child: _closeButton()),
                          ],
                        ),
                      ),

                      // ── Badge + titre sous l'affiche
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _badge(),
                            const SizedBox(height: 10),
                            Text(
                              event.name ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                color: ivory,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
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

/// ────────────────────────────────────────────────────────────────────────
/// Carte « À la une » réutilisable : bloc d'entête de l'accueil ([hero]),
/// et carte compacte pour les états vides (onglet « En direct », « Pour toi »,
/// « Concerts à venir »). Tap → fiche du concert ([FutureScreen]).
/// ────────────────────────────────────────────────────────────────────────
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.featured,
    this.hero = false,
    this.badgeLabel,
    this.onTap,
  });

  final FeaturedEvent featured;

  /// Grand format (couverture pleine largeur) ; sinon carte compacte en ligne.
  final bool hero;

  /// Texte du badge ; par défaut le titre saisi par l'admin ou « À la une ».
  final String? badgeLabel;

  /// Action au tap ; par défaut, ouvre la fiche du concert.
  final VoidCallback? onTap;

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

  /// Date + heure dans le fuseau du spectateur (ex. « sam. 26 juil. · 20:00 »).
  String get _dateLabel {
    final start = event.startDateTime;
    if (start == null) return '';
    return '${AppDate.dayDate(start)} · ${AppDate.time(start)}';
  }

  void _open() {
    final custom = onTap;
    if (custom != null) {
      custom();
      return;
    }
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
        child: Icon(Icons.music_note_rounded, color: goldSecondary, size: 42),
      ),
    );
  }

  Widget _cover({BoxFit fit = BoxFit.cover}) {
    final url = featuredCoverUrl(event);
    if (url == null) return _fallbackCover();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => const ColoredBox(color: cardDeep),
      errorWidget: (_, __, ___) => _fallbackCover(),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: liveRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              badgeLabel ?? featured.headline ?? 'feat_badge'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                color: ivory,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: midnightPrimary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldSecondary, width: 1.2),
      ),
      child: Text(
        priceLabel(event.ticketPrice),
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          color: goldPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _dateRow({Color color = ivory}) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded, color: goldPrimary, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _ctaPill() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        gradient: kGoldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: goldPrimary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.confirmation_number_rounded,
            color: midnightPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              (_hasTicket ? 'feat_view'.tr : 'feat_book'.tr).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                color: midnightPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final artist = _artistName;
    // L'affiche (souvent un visuel avec du texte, format portrait) est montrée
    // EN ENTIER sur un fond flouté ; les infos passent dessous, jamais
    // par-dessus le texte de l'affiche.
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardDeep,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.35)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: Get.height * 0.36,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: _featuredVisualLayers(event, _cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge(),
                const SizedBox(height: 10),
                if (artist.isNotEmpty) ...[
                  Text(
                    artist.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      color: goldPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  event.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: ivory,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (_dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _dateRow(),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _ctaPill()),
                    const SizedBox(width: 12),
                    _priceChip(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final artist = _artistName;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 96, height: 120, child: _cover()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge(),
                const SizedBox(height: 8),
                if (artist.isNotEmpty) ...[
                  Text(
                    artist.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      color: goldPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  event.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: ivory,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (_dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _dateRow(color: textMuted),
                ],
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: _priceChip()),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: goldPrimary, size: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: hero ? _buildHero() : _buildCompact(),
    );
  }
}

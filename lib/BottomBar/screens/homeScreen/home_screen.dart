import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/live_performance_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/notification_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/performances_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/feed_clip_model.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/widgets/featured_event_sheet.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:artist/widgets/widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Accueil.
///
/// Règle d'affichage (base de production quasi vide : 0 artiste vedette,
/// 1 concert à venir, 0 live, 52 clips) : un squelette (shimmer) n'apparaît
/// QUE pendant le chargement initial ; une liste vide après chargement donne
/// une section MASQUÉE (artistes vedettes < 3, live en cours, concert du
/// jour) ou un état vide chaleureux (concerts à venir). Jamais de shimmer
/// infini. L'accueil s'ouvre sur la carte « À la une » (hero) quand l'admin a
/// mis un concert en avant, et une grille « Clips » remplit l'écran.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authController = Get.put(AuthController(), permanent: true);
  final eventController = Get.put(EventController(), permanent: true);

  var selectedArtist = '';

  var like = false;

  final PageController _bannerController = PageController();
  int _bannerPage = 0;

  /// Concert « À la une » (GET /api/featured-event). Valeur en cache du
  /// splash pour un rendu immédiat ; rafraîchie à chaque [myInitMethod].
  FeaturedEvent? _featured = cachedFeaturedEvent;

  /// Vrai pendant toute la séquence de chargement de l'accueil : les sections
  /// dont la requête n'a pas encore démarré affichent un squelette (au lieu
  /// d'apparaître masquées puis en shimmer puis remplies).
  bool _refreshing = false;

  /// Nombre max de clips dans la grille de l'accueil.
  static const int _maxHomeClips = 10;

  Future myInitMethod() async {
    _refreshing = true;

    /// À la une (appel http indépendant de l'ApiResponse partagé -> en
    /// parallèle du reste, jamais de dialogue d'erreur).
    getFeaturedEvent().then((featured) {
      if (mounted) setState(() => _featured = featured);
    });

    try {
      /// Banner Events
      await eventController.getBannerEvents();

      /// Featured Artists
      await eventController.getFeaturedArtists();

      /// Live Events
      await eventController.getEventsByStatus(
        status: EventStatus.live,
        dateStatus: EventDateStatus.today,
      );

      /// Today's Events
      await eventController.getEventsByStatus(
        status: EventStatus.published,
        dateStatus: EventDateStatus.today,
      );

      /// Upcoming Events
      await eventController.getEventsByStatus(
        status: EventStatus.published,
        dateStatus: EventDateStatus.future,
      );

      /// User Model
      await authController.getUserModel();

      /// User Joined Events
      await eventController.getUserJoinedEvents();

      /// Clips des feeds "Pour toi" / "Clips" (gérés depuis l'admin)
      await eventController.loadFeedClips();
    } catch (e) {
      myPrint('home init: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _bannerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Squelette autorisé uniquement si la requête est en cours (ou que la
  /// séquence de chargement de l'accueil n'est pas terminée).
  bool _skeleton(bool loading) => loading || _refreshing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: midnightPrimary,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [_buildFeed(), _buildTimeline()],
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: HomePageDots(current: _currentPage, count: 2),
            ),
          ],
        ),
      ),
    );
  }

  /// Page 1: the home feed (top bar + hero « À la une » + banner carousel +
  /// sections).
  Widget _buildFeed() {
    return RefreshIndicator(
      color: goldPrimary,
      backgroundColor: midnightSecondary,
      onRefresh: myInitMethod,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),

            /// « À la une » : premier bloc, grand format. Rien si l'admin n'a
            /// rien mis en avant.
            if (_featured != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 22),
                child: FeaturedEventCard(featured: _featured!, hero: true),
              ),

            _buildBanner(),

            Padding(
              padding: myPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Live Now (masqué si aucun live)
                  _buildLiveNow(),

                  /// Next Performance (concerts du jour, masqué si vide)
                  _buildNextPerformance(),

                  /// Upcoming Events (état vide chaleureux)
                  _buildUpcoming(),

                  height(0.01),

                  /// Clips (grille 2 colonnes, masquée si aucun clip)
                  _buildClips(),

                  /// Featured Artists (masqué si < 3 artistes)
                  _buildFeaturedArtists(),

                  height(0.08),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carrousel des bannières (admin). Le concert déjà affiché en hero « À la
  /// une » est écarté pour ne pas l'afficher deux fois.
  Widget _buildBanner() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final raw = controller.bannerEvents.value.data;
        if (raw == null) {
          if (_skeleton(controller.isLoadingBanner)) {
            return const BannerShimmer();
          }
          return const SizedBox.shrink();
        }
        final featuredId = _featured?.event.id;
        final events = featuredId == null
            ? raw
            : raw.where((e) => e.id != featuredId).toList();
        if (events.isEmpty) {
          return _featured == null ? height(0.01) : const SizedBox.shrink();
        }
        final page = _bannerPage < events.length ? _bannerPage : 0;
        return Column(
          children: [
            SizedBox(
              height: Get.height * 0.46,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: events.length,
                onPageChanged: (i) => setState(() => _bannerPage = i),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: GestureDetector(
                      onTap: () => Get.to(() => FutureScreen(event: event)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: HomeBannerCard(event: event),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (events.length > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(events.length, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? goldPrimary
                          : ivory.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLiveNow() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final events = controller.liveNowEvents.value.data;
        if (events == null) {
          if (_skeleton(controller.isLoadingLiveNow)) {
            return Column(
              children: [const EventCardShimmer(), height(0.02)],
            );
          }
          return const SizedBox.shrink();
        }
        // Aucun live -> section masquée (pas de « Aucun live » froid).
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SectionHeader(
              title: 'live_now'.tr,
              icon: 'assets/live_icon.png',
              onViewAll: () =>
                  Get.to(() => LivePerformanceScreen(events: events)),
            ),
            height(0.015),
            SizedBox(
              height: Get.height * 0.2,
              child: ListView.separated(
                separatorBuilder: (context, index) => width(0.02),
                itemCount: events.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return LiveEventsCards(event: event);
                },
              ),
            ),
            height(0.02),
          ],
        );
      },
    );
  }

  Widget _buildNextPerformance() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final events = controller.nextEvents.value.data;
        if (events == null) {
          if (_skeleton(controller.isLoadingNextEvents)) {
            return Column(
              children: [const EventCardShimmer(), height(0.02)],
            );
          }
          return const SizedBox.shrink();
        }
        // Rien aujourd'hui -> section masquée : « Concerts à venir » juste
        // en dessous porte déjà l'information.
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SectionHeader(
              title: 'next_performance'.tr,
              icon: 'assets/date_icon.png',
              onViewAll: () => Get.to(
                () => PerformancesScreen(
                  events: events,
                  title: 'next_performance'.tr,
                ),
              ),
            ),
            height(0.015),
            SizedBox(
              height: Get.height * 0.21,
              child: ListView.separated(
                separatorBuilder: (context, index) => width(0.02),
                itemCount: events.length > 3 ? 3 : events.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return NextPerformanceCard(event: event);
                },
              ),
            ),
            height(0.02),
          ],
        );
      },
    );
  }

  Widget _buildUpcoming() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final allUpcoming = controller.upcomingEvents.value.data;
        if (allUpcoming == null) {
          if (_skeleton(controller.isLoadingUpcoming)) {
            return Column(
              children: [
                SectionHeader(
                  title: 'upcoming_events'.tr,
                  icon: 'assets/date_icon.png',
                ),
                height(0.02),
                const EventTileShimmer(),
              ],
            );
          }
          // Échec réseau : même état vide chaleureux (jamais de shimmer
          // infini) ; le tirer-pour-rafraîchir relance le chargement.
          return _upcomingSection(const <Event>[]);
        }
        // Concerts sans date écartés puis tri par date :
        // plus de `!` sur une date nulle dans le tri.
        final events = allUpcoming
            .where((e) => e.startDateTime != null)
            .toList()
          ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
        return _upcomingSection(events);
      },
    );
  }

  Widget _upcomingSection(List<Event> events) {
    return Column(
      children: [
        SectionHeader(
          title: 'upcoming_events'.tr,
          icon: 'assets/date_icon.png',
          onViewAll: events.isEmpty
              ? null
              : () => Get.to(
                    () => PerformancesScreen(
                      events: events,
                      title: 'upcoming_events'.tr,
                    ),
                  ),
        ),
        height(0.02),
        if (events.isEmpty) ...[
          _UpcomingEmptyState(onEnableAlerts: _enableAlerts),
          if (_featured != null) ...[
            height(0.015),
            FeaturedEventCard(featured: _featured!),
          ],
        ] else
          ListView.separated(
            separatorBuilder: (context, index) => height(0.01),
            itemCount: events.length > 3 ? 3 : events.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final event = events[index];
              return UpcomingEventTile(event: event);
            },
          ),
        height(0.02),
      ],
    );
  }

  /// « Active les notifications » : demande la permission système (silencieux
  /// si déjà accordée) puis confirme.
  Future<void> _enableAlerts() async {
    try {
      await PushNotificationSystem().requestIOSPermissions();
    } catch (e) {
      myPrint('enable alerts: $e');
    }
    if (!mounted) return;
    mySuccessDialog(subtitle: 'home_alerts_enabled'.tr);
  }

  /// Grille « Clips » (2 colonnes) alimentée par les clips du feed « Pour
  /// toi » déjà chargés. Tap -> lecteur plein écran avec enchaînement sur
  /// la même playlist que le feed ; « Voir tout » -> onglet Live.
  Widget _buildClips() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final clips = controller.forYouClips;
        if (clips.isEmpty) {
          if (!controller.feedClipsLoaded &&
              _skeleton(controller.isLoadingFeedClips)) {
            return Column(
              children: [
                SectionHeader(title: 'home_clips_section'.tr),
                height(0.015),
                const _ClipsGridShimmer(),
                height(0.02),
              ],
            );
          }
          return const SizedBox.shrink();
        }
        final shown = clips.take(_maxHomeClips).toList();
        final playlist = controller.forYouClipUrls.toList();
        return Column(
          children: [
            SectionHeader(
              title: 'home_clips_section'.tr,
              onViewAll: () => Get.offAll(() => const MyBottomBar(index: 2)),
            ),
            height(0.015),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: shown.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 9 / 14,
              ),
              itemBuilder: (context, index) {
                final clip = shown[index];
                return _HomeClipTile(
                  clip: clip,
                  onTap: () => _openClip(clip, index, playlist),
                );
              },
            ),
            height(0.02),
          ],
        );
      },
    );
  }

  void _openClip(FeedClip clip, int index, List<String> playlist) {
    final validIndex = index >= 0 && index < playlist.length;
    Get.to(
      () => ReplayPlayerScreen(
        url: clip.videoUrl,
        title: clip.title,
        playlist: playlist.length > 1 && validIndex ? playlist : null,
        startIndex: validIndex ? index : 0,
        autoAdvance: true,
      ),
    );
  }

  /// Artistes vedettes : masqués sous 3 artistes (un ou deux avatars seuls
  /// sur une ligne font vide).
  Widget _buildFeaturedArtists() {
    return GetBuilder<EventController>(
      builder: (controller) {
        final artists = controller.featuredArtists;
        if (artists.length >= 3) {
          return Column(
            children: [FeaturedArtistsAvatar(artists: artists), height(0.02)],
          );
        }
        if (!controller.featuredArtistsLoaded &&
            _skeleton(controller.isLoadingFeaturedArtists)) {
          return Column(
            children: [const FeaturedArtistShimmer(), height(0.02)],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Page 2: chronological "timeline" view (date rail + concert cards),
  /// revealed by swiping the home feed to the left.
  Widget _buildTimeline() {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Concerts Timeline',
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.swipe_right_alt_rounded,
                  size: 18,
                  color: vybzzzTextSecondary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Swipe back',
                  style: TextStyle(color: vybzzzTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: GetBuilder<EventController>(
              builder: (controller) {
                final upcoming = controller.upcomingEvents.value.data ?? [];
                final next = controller.nextEvents.value.data ?? [];
                // Merge next + upcoming, de-duplicated by event id.
                final merged = <int, Event>{};
                for (final e in [...next, ...upcoming]) {
                  if (e.id != null) merged[e.id!] = e;
                }
                final events = merged.values.toList();
                if (events.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_note_rounded,
                    title: 'empty_no_concerts_t'.tr,
                    subtitle: 'empty_no_concerts_s'.tr,
                  );
                }
                return ConcertsTimelineView(
                  events: events,
                  onTapEvent: (e) => Get.to(() => FutureScreen(event: e)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Row(
        children: [
          const Text(
            'VybzzZ',
            style: TextStyle(
              fontFamily: AppFonts.logo,
              color: goldPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 24,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.to(() => const NotificationScreen()),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: ivory,
                  size: 26,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: goldPrimary,
                      shape: BoxShape.circle,
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

/// État vide chaleureux de « Concerts à venir » : invitation à activer les
/// alertes plutôt qu'un « Aucun événement » froid.
class _UpcomingEmptyState extends StatelessWidget {
  const _UpcomingEmptyState({required this.onEnableAlerts});

  final VoidCallback onEnableAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: goldPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: goldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'home_upcoming_empty_t'.tr,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    color: ivory,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'home_upcoming_empty_s'.tr,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEnableAlerts,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                gradient: kGoldGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_rounded,
                    color: midnightPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'home_enable_alerts'.tr,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      color: midnightPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vignette d'un clip dans la grille de l'accueil : miniature Mux (ou fond
/// dégradé), icône lecture, titre éventuel.
class _HomeClipTile extends StatelessWidget {
  const _HomeClipTile({required this.clip, required this.onTap});

  final FeedClip clip;
  final VoidCallback onTap;

  Widget _fallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardDeep, midnightSecondary, Color(0xff3A2E12)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = clip.thumbnailUrl;
    final title = clip.title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: goldSecondary.withValues(alpha: 0.18)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: cardDeep),
                errorWidget: (_, __, ___) => _fallback(),
              )
            else
              _fallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00071426), Color(0xB3071426)],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: midnightPrimary.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: goldSecondary.withValues(alpha: 0.6),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: ivory,
                  size: 26,
                ),
              ),
            ),
            if (title != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    color: ivory,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Squelette de la grille « Clips » (2 × 2), affiché uniquement pendant le
/// premier chargement des clips.
class _ClipsGridShimmer extends StatelessWidget {
  const _ClipsGridShimmer();

  @override
  Widget build(BuildContext context) {
    final tileWidth = (Get.width - 30 - 10) / 2;
    final tileHeight = tileWidth * 14 / 9;
    return Column(
      children: List.generate(2, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row == 0 ? 10 : 0),
          child: Row(
            children: [
              Expanded(
                child: ShimmerBox(height: tileHeight, width: tileWidth, radius: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ShimmerBox(height: tileHeight, width: tileWidth, radius: 16),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Subtle page indicator for the Home feed / timeline pager.
class HomePageDots extends StatelessWidget {
  const HomePageDots({super.key, required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? vybzzzGold
                : vybzzzTextSecondary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

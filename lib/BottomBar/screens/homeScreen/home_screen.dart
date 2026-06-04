import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/live_performance_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/performances_screen.dart';
import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  Future myInitMethod() async {
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

  /// Page 1: the home feed (top bar + banner carousel + sections).
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
            GetBuilder<EventController>(
              builder: (controller) {
                final events = controller.bannerEvents.value.data;
                if (events == null) {
                  return const BannerShimmer();
                }
                if (events.isEmpty) return height(0.05);
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                            ),
                            child: GestureDetector(
                              onTap: () => Get.to(
                                () => FutureScreen(event: event),
                              ),
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
                              final active = i == _bannerPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
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
                ),

              Padding(
                padding: myPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...[
                      /// Featured Artists
                      GetBuilder<EventController>(
                        builder: (controller) {
                          final artists = controller.featuredArtists;
                          if (artists.isEmpty) {
                            return const FeaturedArtistShimmer();
                          }
                          return FeaturedArtistsAvatar(artists: artists);
                        },
                      ),
                    ],
                    height(0.02),

                    ...[
                      /// Live Now
                      GetBuilder<EventController>(
                        builder: (controller) {
                          final events = controller.liveNowEvents.value.data;
                          if (events == null) {
                            return const EventCardShimmer();
                          }
                          return Column(
                            children: [
                              SectionHeader(
                                title: 'live_now'.tr,
                                icon: 'assets/live_icon.png',
                                onViewAll: () => Get.to(
                                  () => LivePerformanceScreen(events: events),
                                ),
                              ),
                              height(0.015),

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'no_live_events'.tr,
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              if (events.isNotEmpty)
                                SizedBox(
                                  height: Get.height * 0.2,
                                  child: ListView.separated(
                                    separatorBuilder: (context, index) {
                                      return width(0.02);
                                    },
                                    itemCount: events.length,
                                    shrinkWrap: true,
                                    padding: EdgeInsets.all(0),
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      final event = events[index];
                                      return LiveEventsCards(event: event);
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    height(0.01),
                    ...[
                      /// Next Performance
                      GetBuilder<EventController>(
                        builder: (controller) {
                          final events = controller.nextEvents.value.data;
                          if (events == null) {
                            return const EventCardShimmer();
                          }
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

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'no_upcoming_events'.tr,
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: Get.height * 0.21,
                                  child: ListView.separated(
                                    separatorBuilder: (context, index) {
                                      return width(0.02);
                                    },
                                    itemCount: events.length > 3
                                        ? 3
                                        : events.length,
                                    shrinkWrap: true,
                                    padding: EdgeInsets.all(0),
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      final event = events[index];
                                      return NextPerformanceCard(event: event);
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],

                    height(0.01),
                    ...[
                      /// Upcoming Events
                      GetBuilder<EventController>(
                        builder: (controller) {
                          final events = controller.upcomingEvents.value.data;
                          if (events == null) {
                            return const EventTileShimmer();
                          }
                          return Column(
                            children: [
                              SectionHeader(
                                title: 'upcoming_events'.tr,
                                icon: 'assets/date_icon.png',
                                onViewAll: () => Get.to(
                                  () => PerformancesScreen(
                                    events: events,
                                    title: 'upcoming_events'.tr,
                                  ),
                                ),
                              ),
                              height(0.02),

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'no_upcoming_events'.tr,
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ListView.separated(
                                separatorBuilder: (context, index) {
                                  return height(0.01);
                                },
                                itemCount: events.length > 3
                                    ? 3
                                    : events.length,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.all(0),
                                itemBuilder: (context, index) {
                                  events.sort(
                                    (a, b) => a.startDateTime!.compareTo(
                                      b.startDateTime!,
                                    ),
                                  );
                                  final event = events[index];
                                  return UpcomingEventTile(event: event);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],

                    height(0.08),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                  return const EmptyState(
                    icon: Icons.event_note_rounded,
                    title: 'No concerts scheduled',
                    subtitle:
                        'Upcoming concerts will line up here on a timeline.',
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
          Stack(
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
        ],
      ),
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

import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/live_performance_screen.dart';
import 'package:artist/BottomBar/screens/homeScreen/performances_screen.dart';
import 'package:artist/Controllers/controller.dart';
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
    );
  }

  /// Page 1: the existing home feed (hero card + sections).
  Widget _buildFeed() {
    return RefreshIndicator(
        onRefresh: myInitMethod,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GetBuilder<EventController>(
                builder: (controller) {
                  final events = controller.bannerEvents.value.data;
                  if (events == null) {
                    return const BannerShimmer();
                  }
                  return Column(
                    children: [
                      if ((events).isEmpty) height(0.05),
                      if (events.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Get.to(() => FutureScreen(event: events.first));
                          },
                          child: HomeBannerCard(event: events.first),
                        ),
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
                              Row(
                                children: [
                                  Image.asset('assets/live_icon.png'),
                                  width(0.02),
                                  Text(
                                    ' Live Now',
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),

                                  GestureDetector(
                                    onTap: () {
                                      Get.to(
                                        () => LivePerformanceScreen(
                                          events: events,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'View All',
                                      style: TextStyle(
                                        color: textXolor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              height(0.01),

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'No Live Events',
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
                              Row(
                                children: [
                                  Text(
                                    textAlign: TextAlign.center,
                                    'Next Performance',
                                    style: TextStyle(
                                      color: blackColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Spacer(),

                                  GestureDetector(
                                    onTap: () {
                                      Get.to(
                                        () => PerformancesScreen(
                                          events: events,
                                          title: 'Next Performance',
                                        ),
                                      );
                                    },
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'View All',
                                      style: TextStyle(
                                        color: textXolor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              height(0.01),

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'No Next Events Available',
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
                              Row(
                                children: [
                                  Text(
                                    textAlign: TextAlign.center,
                                    'Upcoming Events',
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Spacer(),

                                  GestureDetector(
                                    onTap: () {
                                      Get.to(
                                        () => PerformancesScreen(
                                          events: events,
                                          title: 'Upcoming Events',
                                        ),
                                      );
                                    },
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'View All',
                                      style: TextStyle(
                                        color: textXolor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              height(0.02),

                              if (events.isEmpty)
                                Center(
                                  child: Text(
                                    'No Next Events Available',
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

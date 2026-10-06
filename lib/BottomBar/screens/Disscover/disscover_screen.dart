import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DisscoverScreen extends StatefulWidget {
  const DisscoverScreen({super.key});

  @override
  State<DisscoverScreen> createState() => _DisscoverScreenState();
}

class _DisscoverScreenState extends State<DisscoverScreen> {
  final eventController = Get.find<EventController>();
  var searchController = TextEditingController();

  String? selectedLocation;

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  Future<void> myInitMethod() async {
    await eventController.getFeaturedArtists();
    await eventController.getEventsByStatus(
      status: EventStatus.live,
      dateStatus: EventDateStatus.today,
    );
    await eventController.getEventsByStatus(
      status: EventStatus.published,
      dateStatus: EventDateStatus.future,
    );
  }



  List<Map> locationList = [
    {'textImage': '📍', 'title': 'Near Me'},
    {'textImage': '🗽', 'title': 'New York'},
    {'textImage': '🌴', 'title': 'Los Angeles'},
    {'textImage': '🇬🇧', 'title': 'London'},
    {'textImage': '🗾', 'title': 'Tokyo'},
    {'textImage': '🗼', 'title': 'Paris'},
    {'textImage': '🇩🇪', 'title': 'Berlin'},
    {'textImage': '🦘', 'title': 'Sydney'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<EventController>(
        builder: (controller) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: myPadding,
                child: Column(
                  children: [
                    height(0.02),
                    MyTextField(
                      hintText: 'disc_search_hint'.tr,
                      controller: searchController,
                      readOnly: true,
                      onTap: () async {
                        showSearch(
                          context: context,
                          delegate: EventSearchDelegate(
                            allEvents: controller.allEvents.value.data ?? [],
                          ),
                        );
                      },

                      // trailing: Padding(
                      //   padding: const EdgeInsets.all(13),
                      //   child: GestureDetector(
                      //     onTap: () {
                      //       _showFilterBottomSheet(context);
                      //     },
                      //     child: Image.asset(
                      //       'assets/sheet_icon.png',
                      //       width: 15,
                      //       height: 15,
                      //     ),
                      //   ),
                      // ),
                      leading: Icon(Icons.search, color: greyColor, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await controller.getFeaturedArtists();
                    await controller.getEventsByStatus(
                      status: EventStatus.live,
                      dateStatus: EventDateStatus.today,
                    );
                    await controller.getEventsByStatus(
                      status: EventStatus.published,
                      dateStatus: EventDateStatus.future,
                    );
                  },
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: myPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Featured Artists (masqués si la liste est vide :
                          /// un en-tête sans avatar faisait vide)
                          if (controller.featuredArtists.isNotEmpty) ...[
                            FeaturedArtistsAvatar(
                              artists: controller.featuredArtists,
                            ),
                            height(0.02),
                          ],

                          /// Live Now
                          if ((controller.liveNowEvents.value.data ?? [])
                              .isNotEmpty) ...[
                            Row(
                              children: [
                                Image.asset('assets/live_icon.png'),
                                width(0.02),
                                Text(
                                  ' ${'live_now'.tr}',
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            height(0.01),
                            SizedBox(
                              height: Get.height * 0.2,
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.all(0),
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final event = controller
                                      .liveNowEvents
                                      .value
                                      .data![index];
                                  return LiveEventsCards(event: event);
                                },
                                separatorBuilder: (context, index) =>
                                    width(0.02),
                                itemCount:
                                    controller.liveNowEvents.value.data!.length,
                              ),
                            ),
                            height(0.02),
                          ],

                          /// Trending (Using Live or All events as proxy)
                          Row(
                            children: [
                              Text(
                                'disc_trending'.tr,
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : blackColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Spacer(),
                              Text(
                                'view_all'.tr,
                                style: TextStyle(
                                  color: textXolor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          height(0.01),
                          SizedBox(
                            height: Get.height * 0.21,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.all(0),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final events =
                                    controller.allEvents.value.data ?? [];
                                if (events.isEmpty) return Container();
                                final event = events[index % events.length];
                                return NextPerformanceCard(event: event);
                              },
                              separatorBuilder: (context, index) => width(0.02),
                              itemCount: (controller.allEvents.value.data ?? [])
                                  .length,
                            ),
                          ),

                          height(0.02),
                          Text(
                            'disc_featured_events'.tr,
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          height(0.01),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.all(0),
                            itemBuilder: (context, index) {
                              final events =
                                  controller.upcomingEvents.value.data ?? [];
                              if (events.isEmpty) return Container();
                              final event = events[index];
                              return UpcomingEventTile(event: event);
                            },
                            separatorBuilder: (context, index) => height(0.01),
                            itemCount:
                                (controller.upcomingEvents.value.data ?? [])
                                    .length,
                          ),
                          height(0.08),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Future<void> _showFilterBottomSheet(BuildContext context) async {
  //   await showModalBottomSheet(
  //     backgroundColor: Get.isDarkMode
  //         ? cardDeep
  //         : scaffoldBackgroundColor,
  //     context: context,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setModalState) {
  //           return SingleChildScrollView(
  //             child: Padding(
  //               padding: myPadding,
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Row(
  //                     children: [
  //                       Image.asset('assets/music_icon3.png', width: 20),
  //                       width(0.02),
  //                       Text(
  //                         'Genre',
  //                         style: TextStyle(
  //                           color: Get.isDarkMode ? whiteColor : blackColor,
  //                           fontWeight: FontWeight.bold,
  //                           fontSize: 16,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                   height(0.01),
  //                   Wrap(
  //                     runSpacing: 5,
  //                     spacing: 5,
  //                     children: genreList.map((e) {
  //                       return MyContainer(
  //                         padding: const EdgeInsets.all(10),
  //                         noWidth: true,
  //                         widget: Text(
  //                           e,
  //                           style: const TextStyle(
  //                             color: Color(0xff525252),
  //                             fontWeight: FontWeight.bold,
  //                             fontSize: 16,
  //                           ),
  //                         ),
  //                       );
  //                     }).toList(),
  //                   ),
  //                   height(0.02),
  //                   Row(
  //                     children: [
  //                       Image.asset(
  //                         'assets/location_icon.png',
  //                         width: 20,
  //                         color: greyColor,
  //                       ),
  //                       width(0.02),
  //                       Text(
  //                         'Location',
  //                         style: TextStyle(
  //                           color: Get.isDarkMode ? whiteColor : blackColor,
  //                           fontWeight: FontWeight.bold,
  //                           fontSize: 16,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                   height(0.01),
  //                   GridView.builder(
  //                     shrinkWrap: true,
  //                     padding: EdgeInsets.all(0),
  //                     itemCount: locationList.length,
  //                     physics: const NeverScrollableScrollPhysics(),
  //                     gridDelegate:
  //                         const SliverGridDelegateWithFixedCrossAxisCount(
  //                           crossAxisCount: 2,
  //                           childAspectRatio: 1.9,
  //                           crossAxisSpacing: 10,
  //                           mainAxisSpacing: 10,
  //                         ),
  //                     itemBuilder: (context, index) {
  //                       final location = locationList[index]['title'];
  //                       return GestureDetector(
  //                         onTap: () {
  //                           setModalState(() {
  //                             selectedLocation = location;
  //                           });
  //                           setState(() {
  //                             selectedLocation = location;
  //                           });
  //                         },
  //                         child: MyContainer(
  //                           color: Get.isDarkMode
  //                               ? selectedLocation == location
  //                                     ? goldPrimary.withValues(alpha: 0.2)
  //                                     : cardDeep
  //                               : selectedLocation == location
  //                               ? const Color(0xffF4EDDF)
  //                               : whiteColor,
  //                           border: BoxBorder.all(
  //                             width: 3,
  //                             color: Get.isDarkMode
  //                                 ? selectedLocation == location
  //                                       ? goldPrimary
  //                                       : const Color(0xffE5E7EB)
  //                                 : selectedLocation == location
  //                                 ? mainThemeColor
  //                                 : const Color(0xffE5E7EB),
  //                           ),
  //                           widget: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text(
  //                                 locationList[index]['textImage'],
  //                                 style: const TextStyle(
  //                                   fontSize: 16,
  //                                   fontWeight: FontWeight.bold,
  //                                 ),
  //                               ),
  //                               Text(
  //                                 location,
  //                                 style: TextStyle(
  //                                   fontSize: 16,
  //                                   fontWeight: FontWeight.bold,
  //                                   color: Get.isDarkMode
  //                                       ? whiteColor
  //                                       : blackColor,
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                   ),
  //                   height(0.02),
  //                 ],
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
}

class EventSearchDelegate extends SearchDelegate {
  final List<Event> allEvents;

  EventSearchDelegate({required this.allEvents});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = allEvents.where((event) {
      final name = event.name?.toLowerCase() ?? '';
      final artist = event.artist?.artistName?.toLowerCase() ?? '';
      final genre = event.genre?.genre?.toLowerCase() ?? '';
      return name.contains(query.toLowerCase()) ||
          artist.contains(query.toLowerCase()) ||
          genre.contains(query.toLowerCase());
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: results.length,
      separatorBuilder: (context, index) => height(0.01),
      itemBuilder: (context, index) {
        return UpcomingEventTile(event: results[index]);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? []
        : allEvents.where((event) {
            final name = event.name?.toLowerCase() ?? '';
            final artist = event.artist?.artistName?.toLowerCase() ?? '';
            return name.contains(query.toLowerCase()) ||
                artist.contains(query.toLowerCase());
          }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: suggestions.length,
      separatorBuilder: (context, index) => height(0.01),
      itemBuilder: (context, index) {
        return UpcomingEventTile(event: suggestions[index]);
      },
    );
  }
}

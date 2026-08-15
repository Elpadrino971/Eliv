import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_clips_grid.dart';
import 'package:artist/travis_scott/about_screen.dart';
import 'package:artist/travis_scott/events_screen.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ArtistDetailScreen extends StatefulWidget {
  ArtistDetailScreen({super.key, this.artist, this.iD});
  User? artist;
  final int? iD;

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final eventController = Get.find<EventController>();
  var like = false;

  Future myInitMethod() async {
    if (widget.iD != null) {
      await eventController.getUserModel(id: '${widget.iD ?? 1}');
      widget.artist = eventController.artistProfile.value.user!;
      setState(() {});
    }
    await eventController.getArtistEvents(
      artistId: '${widget.artist?.id ?? 1}',
    );
    await eventController.getArtistFollowers(
      artistId: '${widget.artist?.id ?? 1}',
    );
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.03),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Image.asset(
                      'assets/button_image3.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  Spacer(),

                  ///Share
                  Image.asset(
                    'assets/button_image2.png',
                    width: 30,
                    height: 30,
                  ),
                  width(0.02),

                  ///Popup menu
                  Image.asset(
                    'assets/button_image1.png',
                    width: 30,
                    height: 30,
                  ),
                ],
              ),
              height(0.03),
              ClipOval(
                child: ImageWidget(
                  url: widget.artist?.profileImage ?? '',
                  width: 60,
                  height: 60,
                ),
              ),
              height(0.01),
              Text(
                widget.artist?.artistName ?? 'N/A',
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              height(0.01),

              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        return Text(
                          '${eventController.artistFollowers.value.data?.followersCount ?? 0}',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }),

                      Text(
                        'live_followers'.tr,
                        style: TextStyle(
                          color: Color(0xff737373),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  width(0.04),

                  // Column(
                  //   crossAxisAlignment: CrossAxisAlignment.start,
                  //   children: [
                  //     Text(
                  //       '84.2M',
                  //       style: TextStyle(
                  //         color: Get.isDarkMode ? whiteColor : blackColor,
                  //         fontSize: 15,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),

                  //     Text(
                  //       'Monthly Listeners',
                  //       style: TextStyle(
                  //         color: Color(0xff737373),
                  //         fontSize: 15,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),

              height(0.02),

              GetBuilder<EventController>(
                init: eventController,
                builder: (controller) {
                  final followers =
                      eventController.artistFollowers.value.data?.followers
                          ?.map((e) => e.id)
                          .toList() ??
                      [];
                  return GestureDetector(
                    onTap: () async {
                      eventController.isLoading.value = true;
                      eventController.update();
                      try {
                        if (followers.contains(userModel.value.user?.id)) {
                          await eventController.unfollowArtist(
                            artistId: '${widget.artist?.id ?? 1}',
                          );
                        } else {
                          await eventController.followArtist(
                            artistId: '${widget.artist?.id ?? 1}',
                          );
                        }
                      } catch (e) {
                        eventController.isLoading.value = false;
                        eventController.update();
                      }
                      await eventController.getArtistFollowers(
                        artistId: '${widget.artist?.id ?? 1}',
                      );
                      eventController.isLoading.value = false;
                      eventController.update();
                    },
                    child: SizedBox(
                      width: Get.width,
                      child: Container(
                        width: Get.width,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: eventController.isLoading.value
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    textAlign: TextAlign.center,
                                    'live_loading'.tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: whiteColor,
                                    ),
                                  ),
                                  width(0.01),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: whiteColor,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                textAlign: TextAlign.center,
                                followers.contains(userModel.value.user?.id)
                                    ? 'live_following'.tr
                                    : 'live_follow_artist'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: whiteColor,
                                ),
                              ),
                      ),
                    ),
                  );

                  // Spacer(),

                  // SizedBox(
                  //   width: Get.width * 0.15,
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       setState(() {
                  //         like = !like;
                  //       });
                  //     },
                  //     child: Container(
                  //       width: Get.width,
                  //       padding: EdgeInsets.all(10),
                  //       decoration: BoxDecoration(
                  //         color: whiteColor,
                  //         border: Border.all(color: Color(0xff223046)),
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //       child: Center(
                  //         child: like
                  //             ? Image.asset(
                  //                 'assets/heart_icon.png',
                  //                 width: 20,
                  //                 height: 20,
                  //                 color: mainThemeColor,
                  //               )
                  //             : Image.asset(
                  //                 'assets/fill_icon.png',
                  //                 width: 20,
                  //                 height: 20,
                  //               ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                },
              ),
              height(0.01),
              SizedBox(
                width: Get.width * .7,
                child: TabBar(
                  labelColor: Get.isDarkMode ? whiteColor : blackColor,
                  dividerColor: greyColor.withValues(alpha: 0.2),
                  indicatorColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  unselectedLabelColor: Color(0xff737373),
                  labelPadding: EdgeInsets.symmetric(horizontal: 6),
                  tabs: [
                    Tab(text: 'live_tab_events'.tr),
                    Tab(text: 'Vidéos'),
                    Tab(text: 'live_tab_about'.tr),
                  ],
                ),
              ),
              Obx(
                () => Expanded(
                  child: TabBarView(
                    children: [
                      EventsScreen(
                        events: eventController.artistEvents.value.data ?? [],
                      ),
                      ArtistClipsGrid(
                        artistId: '${widget.artist?.id ?? 1}',
                      ),
                      AboutScreen(artist: widget.artist ?? User()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

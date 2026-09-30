import 'package:artist/Controllers/ArtistController/artist_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_create_event.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_events_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_withdraw.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/quick_live.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/revenue_screen.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final artistController = Get.put(ArtistController(), permanent: true);

  Future<void> myInitMethod() async {
    await artistController.getArtistData(
      artistId: '${userModel.value.user?.id ?? 0}',
    );
    await artistController.getGenres();
    await artistController.getArtistEvents(
      artistId: '${userModel.value.user?.id ?? 0}',
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Get.isDarkMode
                ? Image.asset('assets/logo6.png', width: 100)
                : Image.asset('assets/logo3.png', width: 100),

            Spacer(),

            // Image.asset('assets/bell_icon2.png', width: 22, color: whiteColor),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: myInitMethod,
        child: SingleChildScrollView(
          child: Padding(
            padding: myPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'studio_title'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                        Text(
                          'studio_command_center'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff737373),
                          ),
                        ),
                      ],
                    ),

                    Spacer(),

                    GestureDetector(
                      onTap: () async {
                        await Get.to(() => ArtistCreateEvent());
                        await artistController.getArtistEvents(
                          artistId: '${userModel.value.user?.id ?? 0}',
                        );
                      },
                      child: Get.isDarkMode
                          ? Image.asset('assets/plus_icon3.png', width: 40)
                          : Image.asset('assets/plus_icon.png', width: 40),
                    ),
                  ],
                ),

                height(0.015),
                // Live instantané : titre + un bouton, sans formulaire.
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: openQuickLive,
                    icon: const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      'quick_live_btn'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0245E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                height(0.015),
                GetBuilder<ArtistController>(
                  builder: (controller) {
                    final event = controller.artistData.value.data;
                    if (event == null) {
                      return EventCardShimmer();
                    }
                    return GridView(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      physics: NeverScrollableScrollPhysics(),

                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.5,
                      ),
                      children: [
                        ArtistGridCard(
                          img: 'assets/studio_icon1.png',
                          title: 'art_events'.tr,
                          count: '${event.eventCount ?? '0'}',
                          onTap: () {
                            Get.to(() => ArtistEventsScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon2.png',
                          title: 'art_ticket_sold'.tr,
                          count: '${event.totalTicketsSold ?? '0'}',
                          onTap: () {
                            Get.to(() => RevenueScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon3.png',
                          title: 'rev_revenue'.tr,
                          count: '${event.totalRevenue ?? '0'} €',
                          onTap: () {
                            Get.to(() => RevenueScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon4.png',
                          title: 'rev_balance'.tr,
                          count: '${event.currentWallet ?? '0'} €',
                          onTap: () {
                            Get.to(() => RevenueScreen());
                          },
                        ),
                      ],
                    );
                  },
                ),
                height(0.02),
                MyButton(
                  label: 'art_withdraw'.tr,
                  onTap: () {
                    Get.to(() => ArtistWithdraw());
                  },
                  labelColor: whiteColor,
                ),
                height(0.4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistGridCard extends StatelessWidget {
  const ArtistGridCard({
    super.key,
    required this.img,
    required this.title,
    required this.count,
    this.onTap,
  });

  final String img;
  final String title;
  final String count;
  final void Function()? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MyContainer(
        padding: EdgeInsets.all(10),
        noWidth: true,
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(img, width: 40),
                Spacer(),
                Image.asset('assets/top_arrow.png', width: 15),
              ],
            ),

            Text(
              title,
              style: TextStyle(
                color: Color(0xffA1A1A1),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            Text(
              count,
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:artist/Controllers/ArtistController/artist_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_create_event.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_events_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_withdraw.dart';
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
      artistId: '${userModel.value.user?.id ?? 1}',
    );
    await artistController.getGenres();
    await artistController.getArtistEvents(
      artistId: '${userModel.value.user?.id ?? 1}',
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
                          'Studio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                        Text(
                          'Artist Command Center',
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
                          artistId: '${userModel.value.user?.id ?? 1}',
                        );
                      },
                      child: Get.isDarkMode
                          ? Image.asset('assets/plus_icon3.png', width: 40)
                          : Image.asset('assets/plus_icon.png', width: 40),
                    ),
                  ],
                ),

                height(0.01),
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
                          title: 'Events',
                          count: '${event.eventCount ?? '0'}',
                          onTap: () {
                            Get.to(() => ArtistEventsScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon2.png',
                          title: 'Ticket sold',
                          count: '${event.totalTicketsSold ?? '0'}',
                          onTap: () {
                            Get.to(() => RevenueScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon3.png',
                          title: 'Revenue',
                          count: '\$${event.totalRevenue ?? '0'}',
                          onTap: () {
                            Get.to(() => RevenueScreen());
                          },
                        ),
                        ArtistGridCard(
                          img: 'assets/studio_icon4.png',
                          title: 'Balance',
                          count: '\$${event.currentWallet ?? '0'}',
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
                  label: 'Withdraw',
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

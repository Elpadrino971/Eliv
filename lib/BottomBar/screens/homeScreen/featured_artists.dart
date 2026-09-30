import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/live_join.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FeaturedArtists extends StatefulWidget {
  const FeaturedArtists({super.key, required this.artists});

  final RxList<User> artists;

  @override
  State<FeaturedArtists> createState() => _FeaturedArtistsState();
}

class _FeaturedArtistsState extends State<FeaturedArtists> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'home_featured_artists_title'.tr),

      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            // GridView.builder(
            //   shrinkWrap: true,
            //   padding: EdgeInsets.all(0),
            //   physics: NeverScrollableScrollPhysics(),
            //   itemCount: featuredList.length,
            //   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            //     crossAxisCount: 3,
            //     crossAxisSpacing: 7,
            //     mainAxisSpacing: 7,
            //     childAspectRatio: 2.7,
            //   ),
            //   itemBuilder: (context, index) {
            //     return GestureDetector(
            //       onTap: () {
            //         setState(() {
            //           selected = featuredList[index];
            //         });
            //       },
            //       child: Container(
            //         decoration: BoxDecoration(
            //           color: Get.isDarkMode
            //               ? featuredList[index] == selected
            //                     ? goldPrimary
            //                     : cardDeep
            //               : featuredList[index] == selected
            //               ? mainThemeColor
            //               : Color(0xffF3F4F6),
            //           borderRadius: BorderRadius.circular(40),
            //         ),
            //         child: Center(
            //           child: Text(
            //             featuredList[index],
            //             style: TextStyle(
            //               color: Get.isDarkMode
            //                   ? featuredList[index] == selected
            //                         ? whiteColor
            //                         : whiteColor
            //                   : featuredList[index] == selected
            //                   ? mainThemeColor
            //                   : Color(0xffF3F4F6),
            //               fontSize: 16,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ),
            //       ),
            //     );
            //   },
            // ),
            height(0.02),

            widget.artists.isEmpty
                ? Center(child: Text('home_no_featured_artists'.tr))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(0),
                    itemCount: widget.artists.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemBuilder: (context, index) {
                      final artist = widget.artists[index];
                      return GestureDetector(
                        onTap: () {
                          // Artiste EN DIRECT -> bandeau "Rejoindre le live"
                          // (montant -> paiement -> live). Sinon -> sa fiche.
                          if (artist.isLive == true) {
                            showLiveJoinSheet(artist);
                          } else {
                            Get.to(() => ArtistDetailScreen(artist: artist));
                          }
                        },
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageWidget(
                                url: '${artist.profileImage}',
                                fit: BoxFit.cover,
                                errorAsset: 'assets/icon2.png',
                              ),
                              if (artist.isLive == true)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF2D55),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, color: Colors.white, size: 7),
                                        SizedBox(width: 4),
                                        Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              (artist.genres ?? []).isEmpty
                                  ? Container()
                                  : Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: blackColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        '${artist.genres?.first.genre}',
                                        style: TextStyle(
                                          color: whiteColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                              Spacer(),
                              SizedBox(
                                width: Get.width * 0.4,
                                child: Text(
                                  artist.artistName ?? "N/A",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: whiteColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),

                              Container(
                                width: Get.width,
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Get.isDarkMode
                                      ? goldPrimary
                                      : mainThemeColor,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(
                                  textAlign: TextAlign.center,
                                  'home_view'.tr,
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

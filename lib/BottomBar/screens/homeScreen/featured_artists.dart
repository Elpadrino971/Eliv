import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/my_appBar.dart';
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
      appBar: MyAppbar(title: 'Featured artist’s'),

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
                ? Center(child: Text('No Featured Artists'))
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
                          Get.to(() => ArtistDetailScreen(artist: artist));
                        },
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage('${artist.profileImage}'),
                              onError: (exception, stackTrace) {
                                Image.asset('assets/icon2.png');
                              },
                              fit: BoxFit.fill,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
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

                              Row(
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/user.png',
                                        width: 12,
                                        color: whiteColor,
                                      ),
                                      width(0.01),
                                      Text(
                                        '128k',
                                        style: TextStyle(
                                          color: whiteColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/icon16.png',
                                        width: 12,
                                        color: whiteColor,
                                      ),

                                      Text(
                                        '128k',
                                        style: TextStyle(
                                          color: whiteColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              height(0.01),

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
                                  'View',
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
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

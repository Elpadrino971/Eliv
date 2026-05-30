import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/homeScreen/featured_artists.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FeaturedArtistsAvatar extends StatelessWidget {
  const FeaturedArtistsAvatar({super.key, required this.artists});

  final RxList<User> artists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Image.asset('assets/icon2.png'),
            width(0.02),

            Text(
              ' Featured Artist',
              style: TextStyle(
                color: Get.isDarkMode ? Colors.white : Color(0xff171717),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            Spacer(),

            GestureDetector(
              onTap: () {
                Get.to(() => FeaturedArtists(artists: artists));
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
        SizedBox(
          height: Get.height * 0.13,
          child: ListView.separated(
            separatorBuilder: (context, index) {
              return width(0.02);
            },
            itemCount: artists.length,
            shrinkWrap: true,
            // physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(0),
            scrollDirection: Axis.horizontal,

            itemBuilder: (context, index) {
              final artist = artists[index];
              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Get.to(() => ArtistDetailScreen(artist: artist));
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: whiteColor,
                        border: Border.all(color: Color(0xffE5E5E5), width: 3),
                        borderRadius: BorderRadius.circular(50),
                      ),

                      child: ClipOval(
                        child: ImageWidget(
                          url: '${artist.profileImage}',
                          height: Get.height * 0.07,
                          width: Get.height * 0.07,
                        ),
                      ),
                    ),
                  ),
                  height(0.002),
                  SizedBox(
                    width: Get.width * 0.18,
                    child: Text(
                      artist.artistName ?? 'N/A',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff525252),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/homeScreen/featured_artists.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FeaturedArtistsAvatar extends StatelessWidget {
  const FeaturedArtistsAvatar({super.key, required this.artists});

  final RxList<User> artists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Featured Artists',
          icon: 'assets/icon2.png',
          onViewAll: () => Get.to(() => FeaturedArtists(artists: artists)),
        ),
        height(0.018),
        SizedBox(
          height: Get.height * 0.16,
          child: ListView.separated(
            separatorBuilder: (context, index) => width(0.04),
            itemCount: artists.length,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final artist = artists[index];
              final genreText =
                  (artist.genres == null || artist.genres!.isEmpty)
                  ? null
                  : artist.genres!
                        .take(2)
                        .map((g) => (g.genre ?? '').capitalizeFirst ?? '')
                        .where((s) => s.isNotEmpty)
                        .join(' · ');
              return Column(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Get.to(() => ArtistDetailScreen(artist: artist)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: goldSecondary, width: 2),
                      ),
                      child: ClipOval(
                        child: ImageWidget(
                          url: '${artist.profileImage}',
                          height: Get.height * 0.075,
                          width: Get.height * 0.075,
                        ),
                      ),
                    ),
                  ),
                  height(0.008),
                  SizedBox(
                    width: Get.width * 0.2,
                    child: Text(
                      (artist.artistName ?? 'N/A').toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ivory,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (genreText != null && genreText.isNotEmpty)
                    SizedBox(
                      width: Get.width * 0.2,
                      child: Text(
                        genreText,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: goldPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
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

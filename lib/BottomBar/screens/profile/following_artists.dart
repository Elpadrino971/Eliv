import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FollowingArtists extends StatefulWidget {
  const FollowingArtists({super.key});

  @override
  State<FollowingArtists> createState() => _FollowingArtistsState();
}

class _FollowingArtistsState extends State<FollowingArtists> {
  final authController = Get.find<AuthController>();

  Future myInitMethod() async {
    await authController.getFollowingArtists();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Artists'),
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            height(0.02),
            GetBuilder<AuthController>(
              builder: (controller) {
                final followingArtists =
                    controller.followingArtists.value.data?.followers;
                if (followingArtists == null) {
                  return Center(child: CircularProgressIndicator.adaptive());
                }
                if (followingArtists.isEmpty) {
                  return Center(child: Text('No Following Artists'));
                }
                return GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: followingArtists.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.12,
                  ),
                  itemBuilder: (context, index) {
                    final artist = followingArtists[index];
                    return GestureDetector(
                      onTap: () {
                        Get.to(
                          () => ArtistDetailScreen(iD: artist.pivot?.artistId),
                        );
                      },
                      child: Container(
                        width: Get.width * 0.3,
                        padding: myPadding,
                        decoration: BoxDecoration(
                          color: Get.isDarkMode
                              ? Color(0xff141821)
                              : Color(0xffFAFAFA),
                          border: Border.all(color: Color(0xffF5F5F5)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: ImageWidget(
                                  url: artist.profileImage ?? '',
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                              height(0.01),
                              Text(
                                artist.fullName ?? 'N/A',
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : blackColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(
                                width: Get.width * 0.3,
                                child: Text(
                                  artist.email ?? 'N/A',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xffFF2056),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

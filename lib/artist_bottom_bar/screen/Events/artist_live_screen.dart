import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
// import 'package:artist/artist_bottom_bar/screen/Events/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ArtistLiveScreen extends StatefulWidget {
  const ArtistLiveScreen({super.key});

  @override
  State<ArtistLiveScreen> createState() => _ArtistLiveScreenState();
}

class _ArtistLiveScreenState extends State<ArtistLiveScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            padding: myPadding,
            width: Get.width,
            height: Get.height,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/live_image.png'),
                fit: BoxFit.fill,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.all(0),
                  leading: ClipOval(
                    child: Image.asset(
                      'assets/artist_image2.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                  title: Text(
                    'Aria Sol',
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    '1.2M followers',
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  trailing: GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Image.asset(
                      'assets/cross_icon.png',
                      width: 35,
                      height: 35,
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      width: Get.width * 0.23,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xffDD0000),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/dots.png'),
                          width(0.02),
                          Text(
                            textAlign: TextAlign.center,
                            'Live',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Spacer(),
                    Container(
                      width: Get.width * 0.3,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: whiteColor.withValues(alpha: 0.0),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: whiteColor.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/user_icon3.png', width: 18),
                          width(0.02),
                          Text(
                            '1,254',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                height(0.01),

                Row(
                  children: [
                    Image.asset('assets/music_icon.png', width: 40, height: 40),

                    width(0.02),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: greyColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: whiteColor.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Live: Neon Nights Tour',
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Padding(
              padding: myPadding,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Get.to(() => ArtistLiveEventChat());
                    },
                    child: Image.asset('assets/chat_icon.png', width: 50),
                  ),
                  height(0.02),
                  GestureDetector(
                    onTap: () {
                      // Get.to(() => ArtistLiveEventChat());
                    },
                    child: Image.asset('assets/gift_icon.png', width: 50),
                  ),
                  height(0.02),
                  GestureDetector(
                    onTap: () {
                      // Get.to(() => StatsScreen());
                    },
                    child: Image.asset('assets/chart_icon1.png', width: 50),
                  ),
                  height(0.02),
                  Image.asset('assets/share_icon.png', width: 50),
                  height(0.02),
                  Image.asset('assets/show_icon.png', width: 50),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            child: Padding(
              padding: myPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,

                    decoration: BoxDecoration(
                      color: whiteColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 0,
                      bottom: 0,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(0),
                      minTileHeight: 0,
                      leading: ClipOval(
                        child: Image.asset(
                          'assets/artist_image1.png',
                          width: 40,
                          height: 40,
                        ),
                      ),

                      title: Text(
                        'MusicLover99',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        'ARIA IS ON FIRE!! 🔥',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  height(0.02),

                  Container(
                    width: 250,

                    decoration: BoxDecoration(
                      color: whiteColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 0,
                      bottom: 0,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(0),
                      minTileHeight: 0,
                      leading: ClipOval(
                        child: Image.asset(
                          'assets/artist_image1.png',
                          width: 40,
                          height: 40,
                        ),
                      ),

                      title: Text(
                        'VibeCheck',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        'Wooooow that drop',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  height(0.02),
                  Container(
                    width: 250,

                    decoration: BoxDecoration(
                      color: whiteColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 0,
                      bottom: 0,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(0),
                      minTileHeight: 0,
                      leading: ClipOval(
                        child: Image.asset(
                          'assets/artist_image1.png',
                          width: 40,
                          height: 40,
                        ),
                      ),

                      title: Text(
                        'Chris_P',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        'Love from London! 🇬🇧',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  height(0.02),
                  Container(
                    width: 250,

                    decoration: BoxDecoration(
                      color: whiteColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 0,
                      bottom: 0,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(0),
                      minTileHeight: 0,
                      leading: ClipOval(
                        child: Image.asset(
                          'assets/artist_image1.png',
                          width: 40,
                          height: 40,
                        ),
                      ),

                      title: Text(
                        'Jordan',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        'Best live ever',
                        style: TextStyle(
                          color: whiteColor,

                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

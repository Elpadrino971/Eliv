import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class LiveTicketsVideoScreen extends StatefulWidget {
  const LiveTicketsVideoScreen({super.key});

  @override
  State<LiveTicketsVideoScreen> createState() => _LiveTicketsVideoScreenState();
}

class _LiveTicketsVideoScreenState extends State<LiveTicketsVideoScreen> {
  var commentController = TextEditingController();
  var volumeOff = false;
  var like = false;
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
                height(0.02),
                Row(
                  children: [
                    SizedBox(
                      width: Get.width * 0.8,
                      child: MyContainer(
                        padding: EdgeInsets.only(left: 10, right: 10),
                        border: BoxBorder.all(color: greyColor),
                        color: Colors.transparent,
                        widget: ListTile(
                          minTileHeight: 0,
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

                          trailing: Container(
                            padding: EdgeInsets.all(8),
                            width: Get.width * 0.25,
                            decoration: BoxDecoration(
                              color: mainThemeColor,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              textAlign: TextAlign.center,
                              'Follow',
                              style: TextStyle(
                                color: whiteColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Spacer(),

                    GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Image.asset(
                        'assets/cross_icon.png',
                        width: 35,
                        height: 35,
                      ),
                    ),
                  ],
                ),

                height(0.02),

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
                      setState(() {
                        like = !like;
                      });
                    },
                    child: like
                        ? Image.asset('assets/dislike_icon.png', width: 50)
                        : Image.asset('assets/like_icon.png', width: 50),
                  ),

                  height(0.02),
                  GestureDetector(
                    onTap: () {},
                    child: Image.asset('assets/gift_icon.png', width: 50),
                  ),

                  height(0.02),
                  Image.asset('assets/share_icon.png', width: 50),
                  height(0.02),
                  Image.asset('assets/show_icon.png', width: 50),
                  height(0.02),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        volumeOff = !volumeOff;
                      });
                    },

                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: whiteColor.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: volumeOff
                          ? Icon(Icons.volume_up, color: whiteColor, size: 25)
                          : Icon(Icons.volume_off, color: whiteColor, size: 25),
                    ),
                  ),

                  height(0.01),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  height(0.02),
                  SizedBox(
                    width: Get.width * 0.75,
                    child: MyTextField(
                      fillColor: whiteColor.withValues(alpha: 0.2),
                      hintText: 'Add comment...',
                      controller: commentController,
                      borderRadius: 50,

                      trailing: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/button_image5.png',
                          width: 20,
                          height: 20,
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

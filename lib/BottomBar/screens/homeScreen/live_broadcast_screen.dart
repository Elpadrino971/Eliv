import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/homeScreen/report_screen.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({super.key});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  var commentController = TextEditingController();
  var volumeOff = false;
  var like = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        itemCount: 10,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                padding: myPadding,
                width: Get.width,
                height: Get.height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/live_image2.png'),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Column(
                  children: [
                    height(0.02),

                    Row(
                      children: [
                        SizedBox(
                          width: Get.width * 0.9,
                          child: ListTile(
                            minTileHeight: 0,
                            contentPadding: EdgeInsets.all(0),
                            leading: GestureDetector(
                              onTap: () {
                                Get.back();
                              },
                              child: Image.asset(
                                'assets/cross_icon.png',
                                width: 35,
                                height: 35,
                              ),
                            ),

                            title: Text(
                              'Future Nostalgia',
                              style: TextStyle(
                                color: whiteColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            subtitle: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/dots.png',
                                  color: Color(0xffFF1230),
                                ),
                                width(0.01),

                                Text(
                                  '1.2M followers',
                                  style: TextStyle(
                                    color: whiteColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                width(0.02),

                                SizedBox(
                                  width: Get.width * 0.24,
                                  child: MyContainer(
                                    padding: EdgeInsets.all(5),
                                    color: whiteColor.withValues(alpha: 0.2),
                                    border: BoxBorder.all(color: greyColor),
                                    widget: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/user.png',
                                          width: 15,
                                        ),
                                        width(0.01),

                                        Text(
                                          '42,860',
                                          style: TextStyle(
                                            color: whiteColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            trailing: PopupMenuButton(
                              padding: EdgeInsets.all(0),
                              menuPadding: EdgeInsets.all(0),

                              color: greyColor,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              itemBuilder: (context) {
                                return [
                                  PopupMenuItem(
                                    onTap: () {
                                      Get.to(() => ReportScreen());
                                    },
                                    child: Text(
                                      'home_report'.tr,
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ];
                              },
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
                            volumeOff = !volumeOff;
                          });
                        },

                        child: Container(
                          padding: EdgeInsets.all(5),
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
                              ? Icon(
                                  Icons.volume_off,
                                  color: whiteColor,
                                  size: 25,
                                )
                              : Icon(
                                  Icons.volume_up,
                                  color: whiteColor,
                                  size: 25,
                                ),
                        ),
                      ),
                      height(0.02),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            like = !like;
                          });
                        },
                        child: like
                            ? Image.asset('assets/like_icon.png', width: 40)
                            : Image.asset('assets/dislike_icon.png', width: 40),
                      ),

                      height(0.02),
                      GestureDetector(
                        onTap: () {},
                        child: Image.asset('assets/gift_icon.png', width: 45),
                      ),

                      height(0.02),
                      Image.asset('assets/share_icon.png', width: 45),
                      height(0.02),

                      height(0.06),
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
                      SizedBox(
                        width: Get.width * 0.7,
                        child: Row(
                          children: [
                            Expanded(
                              child: MyContainer(
                                padding: EdgeInsets.all(5),
                                color: mainThemeColor,
                                widget: Text(
                                  textAlign: TextAlign.center,
                                  'PLATINUM',
                                  style: TextStyle(
                                    color: whiteColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            width(0.02),

                            Expanded(
                              child: Text(
                                'NeonFan92',
                                style: TextStyle(
                                  color: mainThemeColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      height(0.01),
                      Text(
                        'This set is absolutely mental! 🔥',
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      height(0.01),
                      Text(
                        'Sarah_X',
                        style: TextStyle(
                          color: greyColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        'Best tour of 2026 honestly.',
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      height(0.01),

                      Text(
                        'RhythmMaster',
                        style: TextStyle(
                          color: greyColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Play 'Starlight' next please! ✨",
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      height(0.01),

                      Text(
                        'TechnoQueen',
                        style: TextStyle(
                          color: greyColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "LONDON IS LOUD TONIGHT!",
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      height(0.01),

                      Text(
                        'VybzzZ_BOT',
                        style: TextStyle(
                          color: Color(0xff51A2FF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Artist merch dropping in 5 mins!",
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      height(0.02),
                      SizedBox(
                        width: Get.width * 0.9,
                        child: MyTextField(
                          fillColor: whiteColor.withValues(alpha: 0.2),
                          hintText: 'home_join_conversation'.tr,
                          controller: commentController,
                          borderRadius: 50,
                          textColor: whiteColor,

                          trailing: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/message_icon.png',
                              width: 20,
                              height: 20,
                            ),
                          ),
                          leading: Padding(
                            padding: const EdgeInsets.all(5),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/artist_image1.png',
                                width: 30,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

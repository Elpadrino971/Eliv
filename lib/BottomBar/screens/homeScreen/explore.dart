import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/my_tIckets/my_tickets_screen.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  var searchController = TextEditingController();
  List searchList = ['Aria Sol', 'Techno', 'Midnight Jazz', 'Summer Fest'];

  List<Map> trendingList = [
    {
      'image': 'assets/trading_icon1.png',
      'name': 'Techno',
      'color': Color(0xffEEF2FF),
      'borderColor': Color(0xff4F39F6).withValues(alpha: 0.1),
      'textColor': Color(0xff4F39F6),
    },

    {
      'image': 'assets/trading_icon2.png',
      'name': 'Pop',
      'color': Color(0xffFFF1F2),
      'borderColor': Color(0xffEC003F).withValues(alpha: 0.1),
      'textColor': Color(0xffEC003F),
    },

    {
      'image': 'assets/trading_icon3.png',
      'name': 'Acoustic',
      'color': Color(0xffFFFBEB),
      'borderColor': Color(0xffE17100).withValues(alpha: 0.1),
      'textColor': Color(0xffE17100),
    },
    {
      'image': 'assets/trading_icon4.png',
      'name': 'Jazz',
      'color': Color(0xffECFDF5),
      'borderColor': Color(0xff009966).withValues(alpha: 0.1),
      'textColor': Color(0xff009966),
    },
  ];
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: myPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          height(0.03),
          Row(
            children: [
              SizedBox(
                width: Get.width * 0.7,
                child: MyTextField(
                  hintText: 'Artists, events, or genres...',
                  controller: searchController,
                  leading: Icon(Icons.search_rounded, color: Color(0xffA1A1A1)),

                  hintColor: Color(0xffA1A1A1),
                  textColor: Color(0xffA1A1A1),
                ),
              ),

              Spacer(),

              SizedBox(
                width: Get.width * 0.2,
                child: MyButton(
                  label: 'Cancel',
                  onTap: () {},
                  borderColor: Colors.transparent,
                  buttonColor: Colors.transparent,

                  labelColor: mainThemeColor,
                ),
              ),
            ],
          ),

          height(0.01),
          Row(
            children: [
              Image.asset(
                'assets/clock.png',
                color: Color(0xffA1A1A1),
                width: 15,
                height: 15,
              ),
              width(0.01),

              Text(
                ' Recent',
                style: TextStyle(
                  color: Color(0xffA1A1A1),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          height(0.01),

          Wrap(
            runSpacing: 5,
            spacing: 5,
            children: searchList.map((e) {
              return MyContainer(
                padding: EdgeInsets.all(10),
                noWidth: true,
                widget: Text(
                  e,
                  style: TextStyle(
                    color: Color(0xff525252),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
          ),

          height(0.01),
          Row(
            children: [
              Image.asset(
                'assets/icon17.png',
                color: Color(0xffA1A1A1),
                width: 15,
                height: 15,
              ),
              width(0.01),

              Text(
                'Trending Genres',
                style: TextStyle(
                  color: Color(0xffA1A1A1),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          height(0.01),
          GridView.builder(
            itemCount: trendingList.length,
            padding: EdgeInsets.all(0),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3.5,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Get.to(() => MyTicketsScreen());
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: trendingList[index]['color'],
                    border: Border.all(
                      color: trendingList[index]['borderColor'],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        trendingList[index]['image'],
                        width: 20,
                        height: 20,
                      ),
                      width(0.02),
                      Text(
                        trendingList[index]['name'],
                        style: TextStyle(
                          color: trendingList[index]['textColor'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          height(0.01),

          Text(
            'You might like',
            style: TextStyle(
              color: Color(0xffA1A1A1),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          height(0.01),

          GestureDetector( 
            onTap: () {
              // Get.to(() => DisscoverScreen());
            },
            child: ListTile(  
              contentPadding: EdgeInsets.all(0),
              minTileHeight: 0,
              minLeadingWidth: 0,
              leading: ClipOval(
                child: Image.asset('assets/artist_image1.png', width: 50),
              ),
              title: Text(
                'Aria Sol',
                style: TextStyle(
                  color: blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '2.4M followers',
                style: TextStyle(
                  color: Color(0xffA1A1A1),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          height(0.01),

          ListTile(
            minTileHeight: 0,
            contentPadding: EdgeInsets.all(0),
            leading: ClipOval(
              child: Image.asset('assets/artist_image2.png', width: 50),
            ),
            title: Text(
              'DJ Koda',
              style: TextStyle(
                color: blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '850K followers',
              style: TextStyle(
                color: Color(0xffA1A1A1),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

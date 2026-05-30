
import 'package:artist/BottomBar/screens/homeScreen/live_broadcast_screen.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/utils.dart';

class WeatingScreen extends StatefulWidget {
  const WeatingScreen({super.key});

  @override
  State<WeatingScreen> createState() => _WeatingScreenState();
}

class _WeatingScreenState extends State<WeatingScreen> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 3), () {
      return Get.to(() => LiveBroadcastScreen());
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: myPadding,
        width: Get.width,
        height: Get.height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/weating_image.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: SizedBox(
          width: Get.width * 0.2,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/timmer_image.png', width: 200, height: 200),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:artist/BottomBar/screens/LiveScreen/artist_detail.dart';
import 'package:artist/BottomBar/screens/homeScreen/future_screen.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dart:async';

class NextPerformanceCard extends StatefulWidget {
  const NextPerformanceCard({super.key, required this.event});

  final Event event;

  @override
  State<NextPerformanceCard> createState() => _NextPerformanceCardState();
}

class _NextPerformanceCardState extends State<NextPerformanceCard> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  void _startTimer() {
    _timer?.cancel();
    if (widget.event.startDateTime == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = widget.event.startDateTime!.difference(now);

      if (difference.isNegative) {
        _duration = Duration.zero;
        _timer?.cancel();
      } else {
        _duration = difference;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width * 0.8,
      padding: myPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        image: DecorationImage(
          image: NetworkImage(
            '${APIs.eventImageIP}/${widget.event.coverImage}',
          ),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _duration.inDays > 0
                    ? Get.width * 0.35
                    : Get.width * 0.23,
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: whiteColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_duration.inDays > 0) ...[
                      Column(
                        children: [
                          Text(
                            textAlign: TextAlign.center,
                            _duration.inDays.toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            textAlign: TextAlign.center,
                            'Day',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        textAlign: TextAlign.center,
                        ':',
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    Column(
                      children: [
                        Text(
                          textAlign: TextAlign.center,
                          (_duration.inHours % 24).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          textAlign: TextAlign.center,
                          'Hour',
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      textAlign: TextAlign.center,
                      ':',
                      style: TextStyle(
                        color: whiteColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    Column(
                      children: [
                        Text(
                          textAlign: TextAlign.center,
                          (_duration.inMinutes % 60).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          textAlign: TextAlign.center,
                          'Min',
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Spacer(),

              Text(
                '\$${widget.event.ticketPrice}',
                style: TextStyle(
                  color: whiteColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          height(0.06),

          Row(
            children: [
              ClipOval(
                child: ImageWidget(
                  url: '${widget.event.artist?.profileImage}',
                  height: 30,
                  width: 30,
                ),
              ),
              width(0.02),
              GestureDetector(
                onTap: () {
                  Get.to(
                    () => ArtistDetailScreen(artist: widget.event.artist!),
                  );
                },
                child: SizedBox(
                  width: Get.width * 0.35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.name ?? 'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      height(0.001),
                      Text(
                        widget.event.artist?.artistName ?? 'N/A',
                        style: TextStyle(
                          color: Color(0xffFFCCD3),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(),

              GestureDetector(
                onTap: () {
                  Get.to(() => FutureScreen(event: widget.event));
                },
                child: Container(
                  width: Get.width * 0.25,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Get.isDarkMode ? redColor : mainThemeColor,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    textAlign: TextAlign.center,
                    'Get Ticket',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.event});
  final Event event;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final eventController = Get.find<EventController>();
  List<Activity> activities = [];
  bool isLoading = true;
  bool isStarted = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final now = DateTime.now();
    // Re-calculating if it started based on widget.event
    if (widget.event.startDateTime != null &&
        now.isAfter(widget.event.startDateTime!)) {
      isStarted = true;
      final data = await eventController.getEventLogs(
        eventId: widget.event.id.toString(),
      );
      if (mounted) {
        setState(() {
          activities = data ?? [];
          isLoading = false;
        });
      }
    } else {
      isStarted = false;
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: MyAppbar(title: 'Analytics'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isStarted) {
      return Scaffold(
        appBar: MyAppbar(title: 'Analytics'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 80, color: greyColor),
              height(0.02),
              const Text(
                'Event hasn\'t started yet!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: greyColor,
                ),
              ),
              height(0.01),
              const Text(
                'Analytics will be available once the live begins.',
                style: TextStyle(color: greyColor),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate metrics
    final ticketsSold = widget.event.ticketBuyerIds?.length ?? 0;
    double giftRevenue = 0;
    for (var act in activities) {
      if (act.type == 'gift') {
        giftRevenue += double.tryParse(act.points?.toString() ?? '0') ?? 0;
      }
    }
    final ticketRevenue =
        ticketsSold * (double.tryParse(widget.event.ticketPrice ?? '0') ?? 0);
    final totalRevenue = ticketRevenue + giftRevenue;

    // Unique participants
    final participants = <int>{};
    for (var act in activities) {
      if (act.userInfo?.id != null) participants.add(act.userInfo!.id!);
    }
    final attendeeCount = participants.length;
    final conversion = attendeeCount > 0
        ? (ticketsSold / attendeeCount * 100).toStringAsFixed(1)
        : '0';

    List<Map<String, dynamic>> analyticsData = [
      {
        'image': 'assets/analytics_image1.png',
        'subTitle': 'Tickets Sold',
        'title': '$ticketsSold',
        'percentage': '+${(ticketsSold * 0.1).toStringAsFixed(0)}',
      },
      {
        'image': 'assets/analytics_image2.png',
        'subTitle': 'Total Revenue',
        'title': '\$${totalRevenue.toStringAsFixed(2)}',
        'percentage': 'LIVE',
      },
      {
        'image': 'assets/analytics_image3.png',
        'subTitle': 'Attendees',
        'title': '$attendeeCount',
        'percentage': '$conversion%',
      },
    ];

    // Chart Data
    List<ChartData> chartData = [];
    double cumulative = 0;
    final sorted = List<Activity>.from(activities)
      ..sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );

    for (var act in sorted) {
      if (act.type == 'gift') {
        cumulative += double.tryParse(act.points?.toString() ?? '0') ?? 0;
        chartData.add(ChartData(act.createdAt ?? DateTime.now(), cumulative));
      }
    }
    if (chartData.isEmpty) {
      chartData.add(ChartData(widget.event.startDateTime ?? DateTime.now(), 0));
    }

    return Scaffold(
      appBar: MyAppbar(title: 'Analytics'),
      body: SingleChildScrollView(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event.name ?? 'Event Analytics',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Image.asset('assets/button_image4.png', width: 40, height: 40),
              ],
            ),
            const Text(
              'Sales Performance',
              style: TextStyle(
                color: greyColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            height(0.01),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = analyticsData[index];
                return MyContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  widget: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.asset(item['image'], width: 40),
                    title: Text(
                      item['subTitle'],
                      style: const TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item['title'],
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: MyContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      color: const Color(0xffF0FDF4),
                      noWidth: true,
                      widget: Text(
                        item['percentage'],
                        style: const TextStyle(
                          color: Color(0xff00A63E),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => height(0.01),
              itemCount: analyticsData.length,
            ),
            height(0.02),
            const Text(
              'Revenue Growth',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            height(0.01),
            MyContainer(
              height: 250,
              widget: SfCartesianChart(
                primaryXAxis: DateTimeAxis(),
                series: <CartesianSeries<ChartData, DateTime>>[
                  SplineSeries<ChartData, DateTime>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.revenue,
                    color: mainThemeColor,
                    width: 3,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  ChartData(this.time, this.revenue);
  final DateTime time;
  final double revenue;
}

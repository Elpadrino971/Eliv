import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/shimmer_loaders.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ArtistHistroyScreen extends StatefulWidget {
  const ArtistHistroyScreen({super.key});

  @override
  State<ArtistHistroyScreen> createState() => _ArtistHistroyScreenState();
}

class _ArtistHistroyScreenState extends State<ArtistHistroyScreen> {
  final artistController = Get.find<ArtistController>();

  Future myInitMethod() async {
    await artistController.getEventStatsByUserId();
  }

  @override
  void initState() {
    myInitMethod();
    super.initState();
  }

  List<_ChartData> _prepareChartData(List<Event> events) {
    Map<String, int> monthData = {
      'Jan': 0,
      'Feb': 0,
      'Mar': 0,
      'Apr': 0,
      'May': 0,
      'Jun': 0,
      'Jul': 0,
      'Aug': 0,
      'Sep': 0,
      'Oct': 0,
      'Nov': 0,
      'Dec': 0,
    };

    for (var event in events) {
      if (event.activities != null) {
        for (var activity in event.activities!) {
          if (activity.createdAt != null) {
            String month = DateFormat('MMM').format(activity.createdAt!);
            if (monthData.containsKey(month)) {
              monthData[month] = monthData[month]! + 1;
            }
          }
        }
      }
    }

    return monthData.entries
        .map((e) => _ChartData(e.key, e.value.toDouble()))
        .toList();
  }

  String _calculateAvgSession(List<Event> events) {
    if (events.isEmpty) return '0m';
    int totalMinutes = 0;
    int count = 0;
    for (var event in events) {
      if (event.startDateTime != null && event.endDateTime != null) {
        totalMinutes += event.endDateTime!
            .difference(event.startDateTime!)
            .inMinutes;
        count++;
      }
    }
    if (count == 0) return '0m';
    return '${(totalMinutes / count).round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'History'),
      body: GetBuilder<ArtistController>(
        builder: (controller) {
          final events = controller.eventStats.value.data;

          if (events == null) {
            return SingleChildScrollView(
              child: Padding(
                padding: myPadding,
                child: Column(
                  children: List.generate(
                    6,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: EventTileShimmer(),
                    ),
                  ),
                ),
              ),
            );
          }

          final chartData = _prepareChartData(events);
          final avgSession = _calculateAvgSession(events);
          final growthGoal = 10; // Target shows
          final currentShows = events.length;
          final growthPercent = (currentShows / growthGoal).clamp(0.0, 1.0);

          return Padding(
            padding: myPadding,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  height(0.01),
                  Row(
                    children: [
                      Text(
                        ' Volume History',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'FY ${DateTime.now().year}',
                        style: const TextStyle(
                          color: mainThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  height(0.02),
                  SizedBox(
                    height: 200,
                    child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: CategoryAxis(
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: const TextStyle(color: greyColor),
                      ),
                      primaryYAxis: NumericAxis(
                        axisLine: const AxisLine(width: 0),
                        majorTickLines: const MajorTickLines(size: 0),
                        labelStyle: const TextStyle(color: greyColor),
                      ),
                      series: <CartesianSeries>[
                        AreaSeries<_ChartData, String>(
                          dataSource: chartData,
                          xValueMapper: (_ChartData data, _) => data.x,
                          yValueMapper: (_ChartData data, _) => data.y,
                          color: mainThemeColor.withValues(alpha: 0.3),
                          borderColor: mainThemeColor,
                          borderWidth: 2,
                          gradient: LinearGradient(
                            colors: [
                              mainThemeColor.withValues(alpha: 0.5),
                              mainThemeColor.withValues(alpha: 0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(enable: true),
                    ),
                  ),
                  height(0.02),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: MyContainer(
                            color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                            widget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyContainer(
                                  padding: const EdgeInsets.all(8),
                                  color: whiteColor.withValues(alpha: 0.2),
                                  noWidth: true,
                                  widget: const Icon(
                                    Icons.show_chart,
                                    color: whiteColor,
                                    size: 18,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Growth Goal',
                                  style: TextStyle(
                                    color: Color(0xffFFE4E6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$currentShows/$growthGoal Shows',
                                  style: const TextStyle(
                                    color: whiteColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                height(0.01),
                                LinearProgressIndicator(
                                  value: growthPercent,
                                  color: whiteColor,
                                  backgroundColor: whiteColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      width(0.02),
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: MyContainer(
                            widget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyContainer(
                                  padding: const EdgeInsets.all(8),
                                  border: Border.all(
                                    color: const Color(0xffF3E8FF),
                                  ),
                                  color: const Color(0xffFAF5FF),
                                  noWidth: true,
                                  widget: Image.asset(
                                    'assets/clock.png',
                                    color: const Color(0xffAD46FF),
                                    width: 15,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Avg Session',
                                  style: TextStyle(
                                    color: Color(0xffA1A1A1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  avgSession,
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  height(0.02),
                  Row(
                    children: [
                      Text(
                        ' Performance Log',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${events.length} Recorded',
                        style: const TextStyle(
                          color: Color(0xffD4D4D4),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  height(0.01),
                  ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (context, index) => height(0.015),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return MyContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        widget: ListTile(
                          minTileHeight: 0,
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: greyColor.withValues(alpha: 0.1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ImageWidget(
                                url: '${APIs.eventImageIP}${event.coverImage}',
                                width: 45,
                                height: 45,
                              ),
                            ),
                          ),
                          title: Text(
                            event.name ?? 'Untitled Show',
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 14,
                                color: mainThemeColor,
                              ),
                              width(0.01),
                              Text(
                                '${event.likesCount ?? 0} Likes',
                                style: const TextStyle(
                                  color: Color(0xffA1A1A1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              width(0.02),
                              const Icon(
                                Icons.people,
                                size: 14,
                                color: Color(0xff00C950),
                              ),
                              width(0.01),
                              Text(
                                '${event.joinedUsersCount ?? 0} Fans',
                                style: const TextStyle(
                                  color: Color(0xffA1A1A1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  height(0.03),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y);
  final String x;
  final double y;
}

import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.event, required this.activities});
  final Event event;
  final List<Activity> activities;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    // Calculate total earnings
    double totalEarn = 0;
    for (var act in widget.activities) {
      if (act.type == 'gift') {
        totalEarn += double.tryParse(act.points?.toString() ?? '0') ?? 0;
      }
    }

    // Prepare chart data (group gifts by time)
    List<ActivityChartData> chartData = [];
    double cumulative = 0;
    // Sort activities by creation time for the chart
    final sortedActivities = List<Activity>.from(widget.activities)
      ..sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );

    for (var act in sortedActivities) {
      if (act.type == 'gift') {
        cumulative += double.tryParse(act.points?.toString() ?? '0') ?? 0;
        chartData.add(
          ActivityChartData(act.createdAt ?? DateTime.now(), cumulative),
        );
      }
    }

    // Fallback if no gifts yet
    if (chartData.isEmpty) {
      chartData.add(
        ActivityChartData(widget.event.startDateTime ?? DateTime.now(), 0),
      );
    }

    // Get unique participants
    final participants = <int, User>{};
    for (var act in widget.activities) {
      if (act.userInfo != null && act.userInfo!.id != null) {
        participants[act.userInfo!.id!] = act.userInfo!;
      }
    }
    final participantList = participants.values.toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: GestureDetector(
            onTap: Get.back,
            child: Image.asset('assets/cros_icon.png', width: 20),
          ),
          title: Text(
            widget.event.name ?? 'ev_live_event'.tr,
            style: TextStyle(
              color: Get.isDarkMode ? whiteColor : blackColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Row(
            children: [
              Image.asset('assets/dots.png', color: goldPrimary),
              width(0.02),
              const Text(
                'Live',
                style: TextStyle(
                  color: goldPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // trailing: GestureDetector(
          //   onTap: Get.back,
          //   child: Image.asset('assets/end_image.png', width: 60, height: 60),
          // ),
        ),
      ),
      body: SingleChildScrollView(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'ev_event_stats'.tr,
                style: const TextStyle(
                  color: mainThemeColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            height(0.02),
            MyContainer(
              height: 250,
              widget: SfCartesianChart(
                primaryXAxis: DateTimeAxis(),
                title: ChartTitle(
                  text: 'rev_earnings_over_time'.tr,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<ActivityChartData, DateTime>>[
                  AreaSeries<ActivityChartData, DateTime>(
                    dataSource: chartData,
                    xValueMapper: (ActivityChartData data, _) => data.time,
                    yValueMapper: (ActivityChartData data, _) => data.points,
                    color: mainThemeColor.withValues(alpha: 0.3),
                    borderColor: mainThemeColor,
                    borderWidth: 2,
                    name: 'rev_earnings'.tr,
                  ),
                ],
              ),
            ),
            height(0.02),
            Row(
              children: [
                Expanded(
                  child: MyContainer(
                    widget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_total_points'.tr,
                          style: const TextStyle(
                            color: greyColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          totalEarn.toStringAsFixed(0),
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                width(0.03),
                Expanded(
                  child: MyContainer(
                    widget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'art_all_users'.tr,
                          style: const TextStyle(
                            color: greyColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${participantList.length}',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            height(0.03),
            Text(
              'ev_participants'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            height(0.01),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: participantList.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = participantList[index];
                final hasPhoto =
                    user.profileImage != null &&
                    user.profileImage!.startsWith('http');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  // Une vraie photo stock d'un visage humain était utilisée
                  // comme avatar "par défaut" -> icône générique à la place
                  // pour les participants sans photo de profil.
                  leading: hasPhoto
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(user.profileImage!),
                        )
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.fullName ?? 'art_hidden_name'.tr),
                  subtitle: Text(user.artistName ?? 'art_fan'.tr),
                  // trailing: const Icon(Icons.chevron_right, color: greyColor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityChartData {
  ActivityChartData(this.time, this.points);
  final DateTime time;
  final double points;
}

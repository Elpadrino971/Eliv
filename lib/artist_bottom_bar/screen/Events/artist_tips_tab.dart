import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';

class ArtistTipsScreen extends StatefulWidget {
  const ArtistTipsScreen({super.key, required this.activities});
  final List<Activity> activities;

  @override
  State<ArtistTipsScreen> createState() => _ArtistTipsScreenState();
}

class _ArtistTipsScreenState extends State<ArtistTipsScreen> {
  @override
  Widget build(BuildContext context) {
    final giftActivities = widget.activities
        .where((a) => a.type == 'gift')
        .toList();

    return Column(
      children: [
        height(0.02),
        if (giftActivities.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No gifts received yet',
                style: TextStyle(color: greyColor),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              separatorBuilder: (context, index) => height(0.015),
              itemCount: giftActivities.length,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemBuilder: (context, index) {
                giftActivities.sort(
                  (a, b) => b.createdAt!.compareTo(a.createdAt!),
                );
                final activity = giftActivities[index];
                return MyContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  color: const Color(0xffF0FDF4),
                  border: BoxBorder.all(color: const Color(0xffDCFCE7)),
                  widget: ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 0,
                    // trailing: Text(
                    //   '${activity.description}',
                    //   style: const TextStyle(color: greyColor, fontSize: 12),
                    // ),
                    leading: activity.gift != null
                        ? ImageWidget(
                            url: '${APIs.giftImageIP}/${activity.gift}',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          )
                        : Image.asset(
                            'assets/tips_image.png',
                            width: 40,
                            height: 40,
                          ),
                    title: Text(
                      activity.userInfo?.fullName ?? 'anonymous',
                      style: const TextStyle(
                        color: blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      activity.description ?? 'Sent a gift',
                      style: const TextStyle(
                        color: Color(0xff00A63E),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

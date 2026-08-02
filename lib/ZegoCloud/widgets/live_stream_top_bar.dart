import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveStreamTopBar extends StatelessWidget {
  const LiveStreamTopBar({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipOval(
            child: (event.artist?.profileImage != null)
                ? Image.network(
                    event.artist!.profileImage!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/artist_image2.png',
                      width: 50,
                      height: 50,
                    ),
                  )
                : Image.asset(
                    'assets/artist_image2.png',
                    width: 50,
                    height: 50,
                  ),
          ),
          title: Text(
            event.artist?.artistName ??
                event.artist?.fullName ??
                'live_artist_name_fallback'.tr,
            style: const TextStyle(
              color: whiteColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            const LiveStatusBadge(),
            const Spacer(),
            // const ViewerCountBadge(),
          ],
        ),
        height(0.01),
        LiveStreamEventInfo(eventName: event.name ?? 'live_event_fallback'.tr),
      ],
    );
  }
}

/// Indicateur "en direct" : un cercle doré plein avec un halo lumineux qui
/// pulse (clignotement doux), au lieu de l'ancienne pilule rouge/blanche.
class LiveStatusBadge extends StatefulWidget {
  const LiveStatusBadge({super.key});

  @override
  State<LiveStatusBadge> createState() => _LiveStatusBadgeState();
}

class _LiveStatusBadgeState extends State<LiveStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value; // 0 -> 1 -> 0
            return Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goldPrimary,
                boxShadow: [
                  BoxShadow(
                    color: goldPrimary.withValues(alpha: 0.35 + 0.5 * t),
                    blurRadius: 6 + 14 * t,
                    spreadRadius: 1 + 3 * t,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          'live_badge'.tr,
          style: const TextStyle(
            color: goldPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// class ViewerCountBadge extends StatelessWidget {
//   const ViewerCountBadge({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final ZegoController controller = Get.find<ZegoController>();

//     return Container(
//       width: Get.width * 0.3,
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: whiteColor.withValues(alpha: 0.0),
//         borderRadius: BorderRadius.circular(50),
//         border: Border.all(color: whiteColor.withValues(alpha: 0.1), width: 2),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Image.asset('assets/user_icon3.png', width: 18),
//           width(0.02),
//           Obx(
//             () => Text(
//               controller.viewerCount.value.toString(),
//               style: const TextStyle(
//                 color: whiteColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class LiveStreamEventInfo extends StatelessWidget {
  const LiveStreamEventInfo({super.key, required this.eventName});
  final String eventName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/music_icon.png', width: 40, height: 40),
        width(0.02),
        Container(
          width: Get.width * 0.75,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: greyColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: whiteColor.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Text(
            'live_prefix'.trParams({'name': eventName}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: whiteColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

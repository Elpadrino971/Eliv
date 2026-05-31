import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/homeScreen/check_out_screen.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/join_stream.dart';
import 'package:artist/ZegoCloud/pre_stream_screen.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class FutureScreen extends StatefulWidget {
  const FutureScreen({super.key, required this.event});
  final Event event;

  @override
  State<FutureScreen> createState() => _FutureScreenState();
}

class _FutureScreenState extends State<FutureScreen> {
  final eventController = Get.find<EventController>();
  List<Map> futureList = [
    {'name': '4K Ultra HD Streaming', 'icon': Icons.high_quality_rounded},
    {'name': 'Dolby Atmos Spatial Audio', 'icon': Icons.surround_sound_rounded},
    {'name': 'Exclusive Digital Merch', 'icon': Icons.shopping_bag_outlined},
    {'name': 'Live Chat with VIP Fans', 'icon': Icons.chat_bubble_outline_rounded},
  ];
  Event event = Event();
  var selectedAccess = '';

  var like = false;

  Future myInitMethod() async {
    await eventController.getUserJoinedEvents();
  }

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  /// Bouton circulaire "glass" premium (bleu nuit + contour or).
  Widget _glassButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: midnightPrimary.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: goldSecondary.withValues(alpha: 0.5)),
        ),
        child: child,
      ),
    );
  }

  /// Carte d'info (date / heure) bleu nuit + accent or.
  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldSecondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: goldPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: goldPrimary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: ivory,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLive = event.status == 'live';
    return Scaffold(
      backgroundColor: midnightPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Héro : image + dégradé bleu nuit + contenu
          SizedBox(
            width: Get.width,
            height: Get.height * 0.42,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageWidget(
                  url: '${APIs.eventImageIP}/${event.coverImage}',
                  fit: BoxFit.cover,
                ),
                // Dégradé pour la lisibilité du texte
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66071426), Color(0xF2071426)],
                      stops: [0.35, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: myPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      height(0.03),
                      Row(
                        children: [
                          _glassButton(
                            onTap: () => Get.back(),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                          const Spacer(),
                          _glassButton(
                            onTap: () async {
                              await myShare(message: APIs.mainIP);
                            },
                            child: const Icon(
                              Icons.ios_share_rounded,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                          width(0.02),
                          _glassButton(
                            onTap: _showReportSheet,
                            child: const Icon(
                              Icons.more_vert,
                              color: ivory,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Badge LIVE si en direct
                      if (isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: liveRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '● LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        height(0.012),
                      ],
                      Text(
                        event.name?.capitalize ?? 'N/A',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ivory,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.1,
                          fontFamily: 'Google Sans',
                        ),
                      ),
                      height(0.015),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: goldSecondary.withValues(alpha: 0.7),
                                width: 1.4,
                              ),
                            ),
                            child: ClipOval(
                              child: ImageWidget(
                                url: '${event.artist?.profileImage}',
                                fit: BoxFit.cover,
                                width: 42,
                                height: 42,
                              ),
                            ),
                          ),
                          width(0.025),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PERFORMING ARTIST',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                event.artist?.artistName ?? 'N/A',
                                style: const TextStyle(
                                  color: ivory,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      height(0.02),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: myPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    height(0.02),
                    // ── Cartes date / heure
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard(
                            icon: Icons.calendar_month_rounded,
                            label: 'Live Date',
                            value: DateFormat(
                              'MMM dd, HH:mm a',
                            ).format(event.startDateTime!),
                          ),
                        ),
                        width(0.03),
                        Expanded(
                          child: _infoCard(
                            icon: Icons.schedule_rounded,
                            label: 'Kick Off',
                            value: DateFormat(
                              'HH:mm a',
                            ).format(event.endDateTime!),
                          ),
                        ),
                      ],
                    ),
                    height(0.025),

                    // ── Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    height(0.01),
                    Text(
                      event.description ?? 'N/A',
                      style: const TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    height(0.025),

                    // ── Ce qui est inclus
                    const Text(
                      "What's Included",
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    height(0.015),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: goldPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                futureList[index]['icon'] as IconData,
                                color: goldPrimary,
                                size: 20,
                              ),
                            ),
                            width(0.035),
                            Expanded(
                              child: Text(
                                futureList[index]['name'],
                                style: const TextStyle(
                                  color: ivory,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (context, index) => height(0.018),
                      itemCount: futureList.length,
                    ),
                    height(0.03),

                    // ── Sélection d'accès
                    const Text(
                      'Select Access Tier',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    height(0.02),
                    if (canJoinRoom()) ...[
                      MyButton(
                        label: 'Join Room',
                        onTap: () async {
                          await Get.to(() => PreStreamScreen(event: event));
                          await myInitMethod();
                          final data = eventController
                              .userJoinedEvents
                              .value
                              .data
                              ?.firstWhere((element) => element.id == event.id);
                          data != null ? event = data : null;
                          setState(() {});
                        },
                      ),
                      height(0.01),
                    ],
                    (event.ticketBuyerIds ?? []).contains(
                          userModel.value.user?.id ?? 1,
                        )
                        ? MyButton(
                            label: isLive
                                ? 'Join Event'
                                : event.status == 'completed'
                                ? 'Event Completed'
                                : 'Wait for Live',
                            onTap: !isLive
                                ? () {}
                                : event.status == 'completed'
                                ? () {}
                                : () async {
                                    await Get.to(
                                      () => JoinStream(event: event),
                                    );
                                    await myInitMethod();
                                    final data = eventController
                                        .userJoinedEvents
                                        .value
                                        .data
                                        ?.firstWhere(
                                          (element) => element.id == event.id,
                                        );
                                    data != null ? event = data : null;
                                    setState(() {});
                                  },
                            image: 'assets/arrow.png',
                            imageColor: whiteColor,
                            labelColor: whiteColor,
                          )
                        : MyButton(
                            label: 'Continue to Checkout',
                            onTap: () async {
                              final value = await Get.to(
                                () => CheckOutScreen(event: event),
                              );
                              if (value != null) {
                                event = event.copyWith(
                                  ticketBuyerIds: [
                                    ...(event.ticketBuyerIds ?? []),
                                    userModel.value.user?.id ?? 1,
                                  ],
                                );
                                setState(() {});
                              }
                            },
                            image: 'assets/arrow.png',
                            imageColor: whiteColor,
                            labelColor: whiteColor,
                          ),
                    height(0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportSheet() {
    String selectedReason = '';
    final otherReasonController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: cardDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: goldSecondary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    height(0.02),
                    const Text(
                      'Report Event',
                      style: TextStyle(
                        color: ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Please select a reason for reporting this event.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    height(0.02),
                    ...[
                      'Spam',
                      'Inappropriate Content',
                      'Harassment',
                      'Copyright Issue',
                      'Other',
                    ].map((reason) {
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          reason,
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: goldPrimary,
                        onChanged: (value) {
                          setModalState(() {
                            selectedReason = value!;
                          });
                        },
                      );
                    }),
                    if (selectedReason == 'Other') ...[
                      height(0.01),
                      MyTextField(
                        hintText: 'Enter your reason...',
                        controller: otherReasonController,
                      ),
                    ],
                    height(0.02),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    height(0.01),
                    MyTextField(
                      hintText: 'Provide more details...',
                      controller: descController,
                      maxLines: 4,
                    ),
                    height(0.03),
                    MyButton(
                      label: 'Submit Report',
                      onTap: () async {
                        String finalReason = selectedReason == 'Other'
                            ? otherReasonController.text.trim()
                            : selectedReason;

                        if (finalReason.isEmpty) {
                          myWarningDialog(
                            subtitle: 'Please select or enter a reason.',
                          );
                          return;
                        }

                        myLoadingDialog();
                        await eventController.reportEvent(
                          eventId: '${event.id}',
                          reason: finalReason,
                          description: descController.text.trim(),
                        );
                        Get.back(); // close loading
                        Get.back(); // close sheet

                        mySuccessDialog(
                          subtitle:
                              'Report submitted. We will review it shortly.',
                          ontap: () => Get.back(),
                        );
                      },
                      labelColor: whiteColor,
                    ),
                    height(0.01),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool canJoinRoom() {
    return (event.startDateTime != null &&
        DateTime.now().year == event.startDateTime!.year &&
        DateTime.now().month == event.startDateTime!.month &&
        DateTime.now().day == event.startDateTime!.day &&
        DateTime.now().isBefore(event.startDateTime!));
  }
}

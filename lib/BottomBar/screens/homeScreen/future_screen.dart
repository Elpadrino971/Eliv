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
    {'name': '4K Ultra HD Streaming', 'image': 'assets/icon3.png'},
    {'name': 'Dolby Atmos Spatial Audio', 'image': 'assets/icon4.png'},
    {'name': 'Exclusive Digital Merch', 'image': 'assets/icon3.png'},
    {'name': 'Live Chat with VIP Fans', 'image': 'assets/icon5.png'},
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

  @override
  Widget build(BuildContext context) {
    bool isLive = event.status == 'live';
    return Scaffold(
      backgroundColor: Get.isDarkMode ? blackColor : scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: myPadding,
            width: Get.width,
            height: Get.height * 0.42,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('${APIs.eventImageIP}/${event.coverImage}'),
                fit: BoxFit.fill,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height(0.03),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greyColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: whiteColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Image.asset(
                          'assets/arrow2.png',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),

                    Spacer(),

                    GestureDetector(
                      onTap: () async {
                        await myShare(message: APIs.mainIP);
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greyColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: whiteColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/share.png',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                height(0.01),
                Row(
                  children: [
                    Spacer(),

                    InkWell(
                      onTap: () {
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
                                    bottom:
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom +
                                        20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Get.isDarkMode
                                        ? const Color(0xff141821)
                                        : whiteColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(30),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 50,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: greyColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        height(0.02),
                                        const Text(
                                          'Report Event',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text(
                                          'Please select a reason for reporting this event.',
                                          style: TextStyle(
                                            color: greyColor,
                                            fontSize: 13,
                                          ),
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
                                              style: TextStyle(
                                                color: Get.isDarkMode
                                                    ? whiteColor
                                                    : blackColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            value: reason,
                                            groupValue: selectedReason,
                                            activeColor: mainThemeColor,
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
                                            String finalReason =
                                                selectedReason == 'Other'
                                                ? otherReasonController.text
                                                      .trim()
                                                : selectedReason;

                                            if (finalReason.isEmpty) {
                                              myWarningDialog(
                                                subtitle:
                                                    'Please select or enter a reason.',
                                              );
                                              return;
                                            }

                                            myLoadingDialog();
                                            await eventController.reportEvent(
                                              eventId: '${event.id}',
                                              reason: finalReason,
                                              description: descController.text
                                                  .trim(),
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
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greyColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: whiteColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.more_vert, color: whiteColor),
                        ),
                      ),
                    ),
                  ],
                ),
                height(0.02),

                height(0.01),
                SizedBox(
                  width: Get.width * 0.4,
                  child: Text(
                    event.name?.capitalize ?? 'N/A',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,

                      fontFamily: 'Google Sans',
                    ),
                  ),
                ),
                height(0.02),
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipOval(
                        child: ImageWidget(
                          url: '${event.artist?.profileImage}',
                          fit: BoxFit.fill,
                          width: 50,
                          height: 50,
                        ),
                      ),
                    ),
                    width(0.02),

                    Text(
                      event.artist?.artistName ?? 'N/A',
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                    Row(
                      children: [
                        SizedBox(
                          width: Get.width * 0.48,
                          child: Container(
                            padding: myPadding,
                            decoration: BoxDecoration(
                              color: Get.isDarkMode
                                  ? darkmodeColor
                                  : whiteColor,
                              border: Border.all(
                                color: Get.isDarkMode
                                    ? darkmodeColor
                                    : borderGreyColor,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xffF3E3E5),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Image.asset('assets/date_icon2.png'),
                                ),
                                height(0.01),
                                Text(
                                  'Live Date',
                                  style: TextStyle(
                                    color: Color(0xff737373),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'MMM dd, HH:mm a',
                                  ).format(event.startDateTime!),
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? greyColor
                                        : blackColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Spacer(),

                        SizedBox(
                          width: Get.width * 0.4,
                          child: Container(
                            padding: myPadding,
                            decoration: BoxDecoration(
                              color: Get.isDarkMode
                                  ? darkmodeColor
                                  : borderGreyColor,
                              border: Border.all(
                                color: Get.isDarkMode
                                    ? darkmodeColor
                                    : borderGreyColor,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xffE5EEFB),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Image.asset('assets/clock.png'),
                                ),
                                height(0.01),
                                Text(
                                  'Kick Off',
                                  style: TextStyle(
                                    color: Color(0xff737373),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'HH:mm a',
                                  ).format(event.endDateTime!),
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? greyColor
                                        : blackColor,
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
                    height(0.01),
                    Text(
                      'Description',
                      style: TextStyle(
                        color: Color(0xff262626),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(
                      width: Get.width * 0.8,
                      child: Text(
                        event.description ?? 'N/A',
                        style: TextStyle(
                          color: greyColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    height(0.02),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.all(0),
                      itemBuilder: (context, index) {
                        String title = futureList[index]['name'];
                        return Row(
                          children: [
                            Image.asset(futureList[index]['image']),
                            width(0.02),
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                color: Color(0xff525252),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (context, index) {
                        return height(0.03);
                      },
                      itemCount: futureList.length,
                    ),

                    height(0.01),

                    Text(
                      'Select Access Tier',
                      style: TextStyle(
                        color: Color(0xff262626),
                        fontWeight: FontWeight.w400,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

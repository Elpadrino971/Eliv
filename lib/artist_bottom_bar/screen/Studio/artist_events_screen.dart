import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/ZegoCloud/start_stream.dart';
import 'package:artist/artist_bottom_bar/screen/Events/analytics_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Events/gift_tickets_screen.dart';
// import 'package:artist/artist_bottom_bar/screen/Events/artist_live_screen.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:artist/Global/app_date.dart';

class ArtistEventsScreen extends StatefulWidget {
  const ArtistEventsScreen({super.key});

  @override
  State<ArtistEventsScreen> createState() => _ArtistEventsScreenState();
}

class _ArtistEventsScreenState extends State<ArtistEventsScreen> {
  final artistController = Get.find<ArtistController>();
  final eventController = Get.find<EventController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Cet écran sert AUSSI d'onglet de la barre du bas du mode artiste.
        // Dans ce cas Get.back() ne revenait pas au Studio : il dépilait la
        // route qui porte toute la barre, et renvoyait en mode fan ou sur une
        // route vide. La flèche n'apparaît donc qu'en page empilée.
        automaticallyImplyLeading: false,
        leading: !Navigator.of(context).canPop()
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  size: 20,
                ),
                onPressed: () => Get.back(),
              ),
        title: Row(
          children: [
            Get.isDarkMode
                ? Image.asset('assets/logo6.png', width: 110)
                : Image.asset('assets/logo3.png', width: 110),

            Spacer(),

            // Image.asset('assets/bell_icon2.png', width: 22, color: blackColor),
          ],
        ),
      ),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ev_my_events'.tr,
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : blackColor,

                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),

            Text(
              'studio_manage_perf'.tr,
              style: TextStyle(
                color: Color(0xff737373),

                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            height(0.01),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GetBuilder<ArtistController>(
                      builder: (controller) {
                        final events = controller.artistEvents.value.data ?? [];
                        // "Mes events" doit aussi montrer les events en cours
                        // de live (pas seulement "published"), sinon un
                        // artiste perd de vue son propre concert dès qu'il
                        // l'a démarré.
                        // Les concerts sans date sont écartés : le tri
                        // ci-dessous compare les dates sans `!` sur null.
                        final published = events
                            .where(
                              (e) =>
                                  (e.status == 'published' ||
                                      e.status == 'live' ||
                                      e.status == 'postponed') &&
                                  e.startDateTime != null,
                            )
                            .toList()
                          ..sort(
                            (a, b) =>
                                a.startDateTime!.compareTo(b.startDateTime!),
                          );
                        if (published.isEmpty) {
                          return Center(
                            child: Text(
                              'ev_no_events'.tr,
                              style: TextStyle(
                                color: Get.isDarkMode ? whiteColor : blackColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          separatorBuilder: (context, index) {
                            return height(0.01);
                          },
                          itemCount: published.length,
                          shrinkWrap: true,
                          padding: EdgeInsets.all(0),
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final event = published[index];
                            return MyContainer(
                              widget: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ClipOval(
                                        child: ImageWidget(
                                          url:
                                              event.artist?.artistProfile ??
                                              '${APIs.profileIP}/default.png',
                                          width: 50,
                                          height: 50,
                                        ),
                                      ),
                                      width(0.02),

                                      Expanded(
                                        child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            event.name ?? 'N/A',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Get.isDarkMode
                                                  ? whiteColor
                                                  : blackColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),

                                          SizedBox(
                                            width: Get.width * 0.3,
                                            child: Container(
                                              width: Get.width,

                                              padding: EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: Color(0xffDCFCE7),
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                              child: Text(
                                                event.status?.capitalize ??
                                                    'N/A',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Color(0xff00A63E),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  height(0.01),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ev_schedule'.tr,
                                            style: TextStyle(
                                              color: Color(0xffA1A1A1),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          height(0.01),

                                          Row(
                                            children: [
                                              Image.asset(
                                                'assets/date_icon.png',
                                                color: Get.isDarkMode
                                                    ? goldPrimary
                                                    : mainThemeColor,
                                                width: 15,
                                              ),
                                              width(0.01),

                                              Text(
                                                AppDate.format(
                                                  event.startDateTime,
                                                  ' yyyy-MM-dd',
                                                ),
                                                style: TextStyle(
                                                  color: Get.isDarkMode
                                                      ? whiteColor
                                                      : blackColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
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
                                              ),
                                              width(0.01),

                                              Text(
                                                AppDate.format(
                                                  event.startDateTime,
                                                  ' HH:mm a',
                                                ),
                                                style: TextStyle(
                                                  color: Color(0xffA1A1A1),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ev_ticket_price'.tr,
                                            style: TextStyle(
                                              color: Color(0xffA1A1A1),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          height(0.01),
                                          Text(
                                            priceLabel(event.ticketPrice),
                                            style: TextStyle(
                                              color: Get.isDarkMode
                                                  ? whiteColor
                                                  : blackColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  height(0.02),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: MyButton(
                                          label: 'ev_analytics'.tr,
                                          onTap: () {
                                            Get.to(
                                              () =>
                                                  AnalyticsScreen(event: event),
                                            );
                                          },

                                          image: 'assets/chart_icon.png',
                                          imageHeight: 15,
                                          imageWidth: 15,
                                          imageColor: mainThemeColor,
                                          buttonColor: Color(0xFFDADADA),
                                          borderColor: Color(0xff223046),
                                        ),
                                      ),

                                      width(0.02),

                                      Expanded(
                                        child: MyButton(
                                          label: 'ev_go_live'.tr,
                                          onTap: () async {
                                            // L'artiste lance quand il veut,
                                            // même avant l'heure annoncée :
                                            // plus de fenêtre de compte à
                                            // rebours qui bloquait le départ.
                                            // Seul un concert déjà terminé
                                            // est refusé.
                                            final end = event.endDateTime;
                                            if (end != null &&
                                                DateTime.now().isAfter(end)) {
                                              myWarningDialog(
                                                subtitle:
                                                    'ev_already_ended'.tr,
                                              );
                                              return;
                                            }
                                            await Get.to(
                                              () => StartStream(event: event),
                                            );
                                            await completeEvent(event);
                                          },

                                          image: 'assets/play_icon.png',
                                          imageHeight: 15,
                                          imageWidth: 15,
                                          imageColor: whiteColor,
                                          buttonColor: Get.isDarkMode
                                              ? goldPrimary
                                              : mainThemeColor,
                                          borderColor: Color(0xff223046),
                                          labelColor: whiteColor,
                                        ),
                                      ),
                                    ],
                                  ),

                                  height(0.01),

                                  // Places offertes : l'artiste invite des
                                  // proches par e-mail (quota côté serveur).
                                  MyButton(
                                    label: 'gift_offer_seats'.tr,
                                    onTap: () {
                                      Get.to(
                                        () => GiftTicketsScreen(event: event),
                                      );
                                    },
                                    image: 'assets/gift_icon.png',
                                    imageHeight: 15,
                                    imageWidth: 15,
                                    imageColor: goldPrimary,
                                    buttonColor: Colors.transparent,
                                    borderColor: goldSecondary,
                                    labelColor: goldPrimary,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    height(0.08),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future completeEvent(Event event) async {
    final endDateTime = event.endDateTime;
    if (endDateTime == null || endDateTime.isAfter(DateTime.now())) {
      await eventController.updateEventStatus(
        eventId: event.id.toString(),
        status: 'completed',
      );
    }
  }
}

import 'package:artist/BottomBar/screens/homeScreen/home_screen.dart';
import 'package:artist/BottomBar/screens/profile/profile.dart';
import 'package:artist/BottomBar/screens/LiveScreen/vybz_live_screen.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Controllers/theme_controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/BottomBar/screens/Disscover/disscover_screen.dart';
import 'package:artist/BottomBar/screens/my_tIckets/my_tickets_screen.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/services/share_receiver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Préchargement du feed « Pour toi » de l'onglet Live (clips gérés depuis
/// l'admin + concerts à venir). L'onglet Live est le premier écran affiché
/// après le splash / la connexion (index 2) : sans ce préchargement, son feed
/// restait vide tant que l'Accueil (qui charge ces données) n'avait pas été
/// ouvert. Une seule séquence de requêtes en vol, quel que soit le nombre
/// d'appelants (splash, barre de navigation…).
Future<void>? _liveFeedPreload;
bool _liveFeedReady = false;

Future<void> preloadLiveFeed() {
  return _liveFeedPreload ??= _runLiveFeedPreload();
}

Future<void> _runLiveFeedPreload() async {
  try {
    final eventController = Get.isRegistered<EventController>()
        ? Get.find<EventController>()
        : Get.put(EventController(), permanent: true);
    final alreadyLoaded = eventController.forYouClipUrls.isNotEmpty ||
        (eventController.allEvents.value.data?.isNotEmpty ?? false);
    if (!alreadyLoaded) {
      try {
        await eventController.loadFeedClips();
      } catch (e) {
        myPrint(e);
      }
      try {
        await eventController.getEventsByStatus(
          status: EventStatus.published,
          dateStatus: EventDateStatus.future,
        );
      } catch (e) {
        myPrint(e);
      }
    }
  } catch (e) {
    myPrint(e);
  } finally {
    _liveFeedReady = true;
  }
}

/// Écran d'attente (fond noir + spinner or) affiché à la place de l'onglet
/// Live pendant le préchargement du feed.
class _LiveFeedLoading extends StatelessWidget {
  const _LiveFeedLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: blackColor,
      child: Center(child: CircularProgressIndicator(color: goldPrimary)),
    );
  }
}

class MyBottomBar extends StatefulWidget {
  final int index;
  const MyBottomBar({super.key, this.index = 0});

  @override
  State<MyBottomBar> createState() => _MyBottomBarState();
}

class _MyBottomBarState extends State<MyBottomBar> {
  final themeController = Get.put(ThemeController());

  int? currentIndex;
  List screenList = [
    HomeScreen(),
    DisscoverScreen(),
    VybzLiveScreen(),
    MyTicketsScreen(),
    Profile(),
  ];

  Future myInitMethod() async {
    currentIndex = widget.index;
    await PushNotificationSystem().requestIOSPermissions();
    try {
      await PushNotificationSystem().generateAndGetToken();
      await PushNotificationSystem().initialingCloudMessaging();
    } catch (e) {
      myPrint(e);
    }
  }

  // Vrai quand le feed « Pour toi » est prêt (ou que l'attente a expiré) :
  // l'onglet Live n'est construit qu'à ce moment-là, pour démarrer
  // directement sur le premier clip.
  bool _liveReady = _liveFeedReady;

  @override
  void initState() {
    myInitMethod();
    // « Partager → VYBZZZ » : écoute les vidéos partagées vers l'app (cold +
    // warm) et ouvre la création de clip. Idempotent.
    ShareReceiver.init();
    if (!_liveReady) {
      preloadLiveFeed()
          .timeout(const Duration(seconds: 6), onTimeout: () {})
          .whenComplete(() {
        if (mounted) setState(() => _liveReady = true);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (currentIndex ?? 0) == 2 && !_liveReady
          ? const _LiveFeedLoading()
          : screenList[currentIndex ?? 0],

      bottomNavigationBar: (currentIndex ?? 0) == 2
          ? null
          : Obx(
        () => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 5),
          decoration: BoxDecoration(
            color: themeController.isDark.value
                ? midnightSecondary
                : whiteColor,
            borderRadius: BorderRadius.circular(35),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Theme(
            data: ThemeData(
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              currentIndex: currentIndex??0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
              selectedItemColor: themeController.isDark.value
                  ? goldPrimary
                  : mainThemeColor,
              unselectedItemColor: const Color(0xff737373),
              elevation: 0,
              onTap: (value) {
                setState(() {
                  currentIndex = value;
                });
              },
              items: [
                /// HOME
                BottomNavigationBarItem(
                  label: 'nav_home'.tr,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: currentIndex == 0
                        ? BoxDecoration(
                            color: themeController.isDark.value
                                ? goldPrimary.withValues(alpha: 0.2)
                                : mainThemeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: themeController.isDark.value
                                  ? goldPrimary
                                  : mainThemeColor,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      'assets/home.png',
                      width: 18,
                      height: 18,
                      color: currentIndex == 0
                          ? (themeController.isDark.value
                                ? goldPrimary
                                : mainThemeColor)
                          : const Color(0xff737373),
                    ),
                  ),
                ),

                /// EXPLORE
                BottomNavigationBarItem(
                  label: 'nav_explore'.tr,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: currentIndex == 1
                        ? BoxDecoration(
                            color: themeController.isDark.value
                                ? goldPrimary.withValues(alpha: 0.2)
                                : mainThemeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: themeController.isDark.value
                                  ? goldPrimary
                                  : mainThemeColor,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      'assets/EXPLORE_ICON.png',
                      width: 18,
                      height: 18,
                      color: currentIndex == 1
                          ? (themeController.isDark.value
                                ? goldPrimary
                                : mainThemeColor)
                          : const Color(0xff737373),
                    ),
                  ),
                ),

                /// LIVE
                BottomNavigationBarItem(
                  label: 'nav_live'.tr,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: currentIndex == 2
                        ? BoxDecoration(
                            color: themeController.isDark.value
                                ? goldPrimary.withValues(alpha: 0.2)
                                : mainThemeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: themeController.isDark.value
                                  ? goldPrimary
                                  : mainThemeColor,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      'assets/live_icon2.png',
                      width: 18,
                      height: 18,
                      color: currentIndex == 2
                          ? (themeController.isDark.value
                                ? goldPrimary
                                : mainThemeColor)
                          : const Color(0xff737373),
                    ),
                  ),
                ),

                /// TICKETS
                BottomNavigationBarItem(
                  label: 'nav_tickets'.tr,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: currentIndex == 3
                        ? BoxDecoration(
                            color: themeController.isDark.value
                                ? goldPrimary.withValues(alpha: 0.2)
                                : mainThemeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: themeController.isDark.value
                                  ? goldPrimary
                                  : mainThemeColor,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      'assets/ticket_icon.png',
                      width: 18,
                      height: 18,
                      color: currentIndex == 3
                          ? (themeController.isDark.value
                                ? goldPrimary
                                : mainThemeColor)
                          : const Color(0xff737373),
                    ),
                  ),
                ),

                /// PROFILE
                BottomNavigationBarItem(
                  label: 'nav_profile'.tr,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: currentIndex == 4
                        ? BoxDecoration(
                            color: themeController.isDark.value
                                ? goldPrimary.withValues(alpha: 0.2)
                                : mainThemeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: themeController.isDark.value
                                  ? goldPrimary
                                  : mainThemeColor,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      'assets/profile.png',
                      width: 18,
                      height: 18,
                      color: currentIndex == 4
                          ? (themeController.isDark.value
                                ? goldPrimary
                                : mainThemeColor)
                          : const Color(0xff737373),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:artist/BottomBar/screens/homeScreen/notification_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/BottomBar/screens/profile/all_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/artist_onboarding_screen.dart';
import 'package:artist/BottomBar/screens/profile/contant_page.dart';
import 'package:artist/BottomBar/screens/profile/following_artists.dart';
import 'package:artist/BottomBar/screens/profile/history.dart';
import 'package:artist/BottomBar/screens/profile/idea_box_screen.dart';
import 'package:artist/BottomBar/screens/profile/manage_subscription_screen.dart';
import 'package:artist/BottomBar/screens/profile/user_wallet.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_clips_grid.dart';
import 'package:artist/Controllers/controller.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/travis_scott/events_screen.dart';
// import 'package:artist/BottomBar/screens/profile/my_tickets.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/settings.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/artist_bottom_bar/artist_bottom_bar.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.fromArtist = false});
  final bool fromArtist;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final authController = Get.find<AuthController>();
  final eventController = Get.find<EventController>();

  List<UserSubscription> userActiveSubscriptions = [];

  /// Stats du dashboard artiste (gains, fans, concerts, billets) — null tant
  /// que non chargées ou si l'appel échoue (l'écran dégrade gracieusement).
  Map<String, dynamic>? artistStats;
  bool loadingArtistStats = false;

  Future myInitMethod() async {
    final data = userModel.value.user?.userSubscription;
    if (data != null && data.isNotEmpty) {
      userActiveSubscriptions = data
          .where((e) => e.status == 'active')
          .toList();
    }
    await authController.getSettings();
    // Charge MON propre contenu (vidéos, concerts, abonnés) pour la grille du
    // profil — même pipeline que la fiche artiste, sur mon id.
    final myId = '${userModel.value.user?.id ?? 1}';
    unawaited(eventController.getArtistClips(artistId: myId));
    unawaited(eventController.getArtistEvents(artistId: myId));
    unawaited(eventController.getArtistFollowers(artistId: myId));
    if (widget.fromArtist) unawaited(_loadArtistStats());
    if (mounted) setState(() {});
  }

  Future<void> _loadArtistStats() async {
    if (mounted) setState(() => loadingArtistStats = true);
    try {
      final response = ApiResponse();
      response.typeSetter = 'get';
      response.urlSetter = APIs.artistDashboardStatsAPI;
      final value = await response.hitAPI();
      if (value is String && value.split(' ').first != 'error') {
        final decoded = jsonDecode(value);
        if (mounted) {
          setState(() {
            artistStats = decoded['data'] as Map<String, dynamic>?;
          });
        }
      }
    } catch (e) {
      myPrint('artist dashboard-stats: $e');
    } finally {
      if (mounted) setState(() => loadingArtistStats = false);
    }
  }

  List<Map> get acountList => [
      widget.fromArtist
          ? {
              'icon': Icons.swap_horiz_rounded,
              'title': 'prof_switch_user'.tr,
              'subTitle': 'prof_switch_user_sub'.tr,
              'onTap': () {
                Get.offAll(() => MyBottomBar(index: 2));
              },
            }
          : {
              'icon': Icons.mic_none_rounded,
              'title': 'prof_become_artist'.tr,
              'subTitle': 'prof_do_live'.tr,
              'onTap': () async {
                // Modèle gratuit : devenir artiste ne nécessite AUCUN
                // abonnement ni paiement. On rafraîchit le profil puis on
                // route directement vers l'accueil artiste (déjà artiste) ou
                // le parcours d'inscription artiste GRATUIT (ArtistOnboarding
                // -> BasicInfo -> BankInfo -> updateProfile => is_artist=1).
                myLoadingDialog();
                await authController.getUserModel();
                Get.back();
                if (userModel.value.user?.isArtist == true) {
                  Get.to(() => ArtistBottomBar());
                } else {
                  Get.to(() => ArtistOnboardingScreen());
                }
              },
            },
      {
        'icon': Icons.favorite_border_rounded,
        'title': 'prof_following_artists'.tr,
        'subTitle': 'prof_following_artists_sub'.tr,
        'onTap': () => Get.to(() => FollowingArtists()),
      },
      {
        'icon': Icons.history_rounded,
        'title': 'prof_stream_history'.tr,
        'subTitle': 'prof_stream_history'.tr,
        'onTap': () => Get.to(() => History()),
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'prof_wallet'.tr,
        'subTitle': 'prof_wallet_sub'.tr,
        'onTap': () => Get.to(() => const UserWallet()),
      },
      // Achat d'abonnement artiste : in-app via Apple IAP (produits vybzz_XX_1m
      // approuvés sur l'App Store, conforme 3.1.1). Le paiement web/Stripe
      // reste proposé côté site et masqué dans l'app iOS (anti-steering).
      {
        'icon': Icons.workspace_premium_outlined,
        'title': 'prof_purchase_sub'.tr,
        'subTitle': 'prof_become_artist_sub'.tr,
        'onTap': () => Get.to(() => const AllSubscriptionScreen()),
      },
      {
        'icon': Icons.card_membership_outlined,
        'title': 'prof_manage_sub'.tr,
        'subTitle': 'prof_manage_sub_sub'.tr,
        'onTap': () => Get.to(() => const ManageSubscriptionScreen()),
      },
      {
        'icon': Icons.lightbulb_outline_rounded,
        'title': 'idea_box_title'.tr,
        'subTitle': 'idea_box_subtitle'.tr,
        'onTap': () => Get.to(() => const IdeaBoxScreen()),
      },
      {
        'icon': Icons.shield_outlined,
        'title': 'prof_privacy'.tr,
        'subTitle': 'prof_privacy_sub'.tr,
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'prof_privacy'.tr,
            content: authController.settings['privacy_policy'],
          ),
        ),
      },
      {
        'icon': Icons.description_outlined,
        'title': 'prof_terms'.tr,
        'subTitle': 'prof_terms_sub'.tr,
        'onTap': () => Get.to(
          () => ContantPage(
            title: 'prof_terms'.tr,
            content: authController.settings['terms_and_conditions'],
          ),
        ),
      },
  ];

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.04),
            Row(
              children: [
                Text(
                  'nav_profile'.tr,
                  style: TextStyle(
                    color: goldPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),

                // Bascule Fan/Artiste : visible seulement si le compte est déjà
                // artiste (sinon "Devenir artiste" plus bas reste le point
                // d'entrée pour lancer l'abonnement + l'onboarding).
                // Obx : sans lui, le bouton n'apparaissait qu'après avoir
                // quitté puis rouvert l'écran, même une fois le statut
                // artiste obtenu.
                if (true)
                  Obx(() => userModel.value.user?.isArtist != true
                      ? const SizedBox.shrink()
                      : GestureDetector(
                    onTap: () {
                      // Retour sur le Profil fan (index 4) et non sur le plein
                      // écran live (index 2), qui n'a pas de barre de
                      // navigation : l'aller-retour est ainsi symétrique.
                      if (widget.fromArtist) {
                        Get.offAll(() => MyBottomBar(index: 4));
                      } else {
                        Get.offAll(() => ArtistBottomBar());
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cardDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: goldSecondary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.fromArtist
                                ? Icons.person_outline_rounded
                                : Icons.mic_none_rounded,
                            color: goldPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.fromArtist
                                ? 'prof_mode_fan'.tr
                                : 'prof_mode_artist'.tr,
                            style: TextStyle(
                              color: goldPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),

                GestureDetector(
                  onTap: () async {
                    await Get.to(() => Settings());
                    setState(() {});
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: goldSecondary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: goldPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            height(0.01),
            _ownHero(widget.fromArtist),
            height(0.014),
            _ownStatsRow(),
            height(0.012),
            // Capsule "Devenir artiste" (mode fan). La déconnexion + les autres
            // items sont dans ⚙ Réglages ; les outils artiste dans la nav du bas.
            if (!widget.fromArtist) ...[
              GestureDetector(
                onTap: acountList[0]['onTap'] as VoidCallback,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [goldSecondary, goldPrimary]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: goldPrimary.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mic_none_rounded,
                          color: midnightPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'prof_become_artist'.tr,
                        style: const TextStyle(
                          color: midnightPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              height(0.012),
            ],
            // Grille de MES vidéos (onglets Shorts / Clips / Concerts), même
            // structure éprouvée que la fiche artiste.
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Get.isDarkMode ? whiteColor : blackColor,
                      dividerColor: greyColor.withValues(alpha: 0.15),
                      indicatorColor: goldPrimary,
                      unselectedLabelColor: const Color(0xff737373),
                      tabs: const [
                        Tab(text: 'Shorts'),
                        Tab(text: 'Clips'),
                        Tab(text: 'Concerts'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          const ArtistClipsGrid(feed: 'for_you'),
                          const ArtistClipsGrid(feed: 'clips'),
                          Obx(() => EventsScreen(
                                events:
                                    eventController.artistEvents.value.data ?? [],
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hero image plein cadre du profil (fan ou artiste), plus court que la fiche
  // pour laisser la place à la grille.
  Widget _ownHero(bool isArtist) {
    final w = Get.width;
    final u = userModel.value.user;
    final img = (isArtist ? u?.artistProfile : u?.profileImage) ?? '';
    final name = (isArtist ? u?.artistName : u?.fullName) ?? 'N/A';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: w,
        height: w * 0.44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageWidget(url: img, width: w, height: w * 0.44, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Get.to(() => const NotificationScreen()),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 19),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'prof_welcome_back'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 23,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stats du profil (Abonnés / Vidéos / Concelts) à partir de MON contenu.
  Widget _ownStatsRow() {
    final txt = Get.isDarkMode ? whiteColor : blackColor;
    Widget stat(String v, String l) => Expanded(
          child: Column(
            children: [
              Text(v,
                  style: TextStyle(
                      color: txt, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(l, style: const TextStyle(color: Color(0xff737373), fontSize: 12)),
            ],
          ),
        );
    return Obx(() {
      final followers =
          eventController.artistFollowers.value.data?.followersCount ?? 0;
      final clips = eventController.artistClips.value.count;
      final concerts = (eventController.artistEvents.value.data ?? []).length;
      return Row(
        children: [
          stat('$followers', 'Abonnés'),
          stat('$clips', 'Vidéos'),
          stat('$concerts', 'Concerts'),
        ],
      );
    });
  }

}
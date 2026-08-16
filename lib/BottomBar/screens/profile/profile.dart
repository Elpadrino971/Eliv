import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:artist/Auth/login_screen.dart';
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
import 'package:artist/Controllers/controller.dart';
import 'package:artist/Controllers/subscription_controller.dart';
// import 'package:artist/BottomBar/screens/profile/my_tickets.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/settings.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/artist_bottom_bar/artist_bottom_bar.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_events_screen.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/revenue_screen.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, this.fromArtist = false});
  final bool fromArtist;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final authController = Get.find<AuthController>();

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
                Get.offAll(() => MyBottomBar());
              },
            }
          : {
              'icon': Icons.mic_none_rounded,
              'title': 'prof_become_artist'.tr,
              'subTitle': 'prof_do_live'.tr,
              'onTap': () async {
                // Re-vérifie l'abonnement en direct (pas le cache local
                // userActiveSubscriptions, calculé une seule fois à
                // l'ouverture de l'onglet -> restait périmé après un achat
                // réussi ailleurs tant que l'app n'était pas relancée).
                myLoadingDialog();
                await authController.getUserModel();
                Get.back();
                final freshActiveSubs = (userModel.value.user?.userSubscription ?? [])
                    .where((e) => e.status == 'active')
                    .toList();
                userActiveSubscriptions = freshActiveSubs;
                if (freshActiveSubs.isEmpty) {
                  // Pas d'abonnement actif -> on propose de s'abonner.
                  // In-app = achat Apple IAP (produits vybzz_XX_1m approuvés,
                  // conforme 3.1.1). Le lien web/Stripe reste masqué sur iOS
                  // (anti-steering) dans l'écran d'achat lui-même.
                  myWarningDialog(
                    title: 'common_warning'.tr,
                    subtitle:
                        'prof_no_sub_become_artist'.tr,
                    ontap: () {
                      Get.back();
                      Get.to(
                        () => AllSubscriptionScreen(
                          fromArtist: widget.fromArtist,
                        ),
                      );
                    },
                  );
                } else {
                  if (userModel.value.user?.isArtist == true) {
                    Get.to(() => ArtistBottomBar());
                  } else {
                    Get.to(() => ArtistOnboardingScreen());
                  }
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
                if (userModel.value.user?.isArtist == true)
                  GestureDetector(
                    onTap: () {
                      if (widget.fromArtist) {
                        Get.offAll(() => MyBottomBar());
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
                  ),

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

            // Mode artiste : le dashboard (bannière + gains + croissance) scrolle
            // avec le reste de la page au lieu d'être figé en haut -> sinon, sur
            // petit écran, il ne reste presque plus de place pour naviguer vers
            // le bas (outils, portefeuille, déconnexion...).
            if (!widget.fromArtist) ...[_fanHeaderCard(), height(0.02)],

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.fromArtist) ...[
                      _artistDashboardHeader(),
                      height(0.02),
                      _toolsAndResources(),
                      height(0.02),
                    ],
                    // Bouton "Devenir artiste" en capsule (mode fan uniquement).
                    // Les autres items de compte sont dans ⚙ Réglages.
                    if (!widget.fromArtist) ...[
                      height(0.01),
                      GestureDetector(
                        onTap: acountList[0]['onTap'] as VoidCallback,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [goldSecondary, goldPrimary],
                            ),
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
                    ],
                    height(0.02),
                    GestureDetector(
                      onTap: () async {
                        await myAlertDialog(
                          title: 'prof_logout'.tr,
                          content: 'prof_logout_confirm'.tr,
                          onTap: () async {
                            myLoadingDialog();
                            await unSub('00${userModel.value.user?.id}');
                            await unSub('users');
                            await unSub('artist');
                            if (userModel.value.user?.registrationType ==
                                'social') {
                              await GoogleSignIn.instance.signOut();
                            }
                            await SubscriptionController.clearIdentity();
                            await box.remove('user');
                            await Future.delayed(Duration(seconds: 1));
                            Get.offAll(() => LoginScreen());
                          },
                        );
                      },
                      child: Container(
                        padding: myPadding,
                        decoration: BoxDecoration(
                          color: Color(0xffFFF1F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/logout.png'),
                            width(0.02),
                            Text(
                              ' Logout Securely',
                              style: TextStyle(
                                color: Color(0xffFF2056),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    height(0.02),

                    Center(
                      child: Text(
                        textAlign: TextAlign.center,
                        'VybzzZ Mobile App ',
                        style: TextStyle(
                          color: Color(0xffA1A1A1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  /// Carte profil "fan" — MÊME design que l'en-tête artiste : grande photo en
  /// bannière (fondue dans le thème) + "Bon retour" + nom + solde de points.
  Widget _fanHeaderCard() {
    final w = Get.width;
    final img = '${userModel.value.user?.profileImage ?? ''}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: w,
        height: w * 0.6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Grande photo plein cadre (visage), façon fiche artiste.
            ImageWidget(url: img, width: w, height: w * 0.6, fit: BoxFit.cover),
            // Voiles pour lisibilité du texte.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Cloche notifications (haut droite).
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Get.to(() => const NotificationScreen()),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
            // Bon retour + nom + points (bas gauche, par-dessus l'image).
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'prof_welcome_back'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    userModel.value.user?.fullName ?? 'N/A',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: goldPrimary),
                    ),
                    child: Text(
                      '★ ${userModel.value.user?.points?.toString() ?? '0'} ${'prof_total_points'.tr}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: goldPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
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

  /// Petit badge % de variation (vert si positif, rouge si négatif).
  Widget _changeBadge(num? pct) {
    final value = pct ?? 0;
    final positive = value >= 0;
    return Text(
      '${positive ? '+' : ''}${value.toStringAsFixed(1)}%',
      style: TextStyle(
        color: positive ? const Color(0xff4ADE80) : const Color(0xffFF6B6B),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );
  }

  Widget _statIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: goldPrimary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: goldPrimary, size: 18),
    );
  }

  /// Dashboard artiste (style "GROW AS AN ARTIST") : bannière + gains totaux
  /// + croissance (fans / concerts / billets) avec variation vs période
  /// précédente. Les stats se chargent en tâche de fond (myInitMethod) ;
  /// tant qu'elles ne sont pas là, les cartes affichent "…" sans bloquer l'UI.
  Widget _artistDashboardHeader() {
    final stats = artistStats;
    final totalEarnings = stats?['total_earnings'];
    final earningsChange = stats?['total_earnings_change_pct'];
    final fansTotal = stats?['fans_total'];
    final fansChange = stats?['fans_change_pct'];
    final showsThisMonth = stats?['shows_this_month'];
    final showsChange = stats?['shows_change_pct'];
    final ticketsTotal = stats?['tickets_total'];
    final ticketsChange = stats?['tickets_change_pct'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bannière : sans cadre (pas de bordure/carte), juste la photo
        // artiste + bienvenue + badge + notifications, à même le fond de l'écran.
        // Hauteur généreuse (156, pas 130) pour laisser de la marge au texte
        // sur les noms d'artiste longs + réglages d'accessibilité (police
        // agrandie) sans déborder.
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: Get.width,
            height: Get.width * 0.58,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Grande photo artiste plein cadre (visage).
                ImageWidget(
                  url: '${userModel.value.user?.artistProfile ?? ''}',
                  width: Get.width,
                  height: Get.width * 0.58,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'prof_welcome_back'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                        ),
                      ),
                      Text(
                        userModel.value.user?.artistName ?? 'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: goldPrimary),
                        ),
                        child: Text(
                          '★ ${'prof_artist_account'.tr}',
                          style: TextStyle(
                            color: goldPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        height(0.02),

        // ── Total des gains
        Container(
          width: Get.width,
          padding: myPadding,
          decoration: BoxDecoration(
            color: cardDeep,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: goldSecondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'prof_total_earnings'.tr,
                      style: TextStyle(color: textMuted, fontSize: 12.5),
                    ),
                    height(0.005),
                    Text(
                      totalEarnings != null
                          ? '${(totalEarnings as num).toStringAsFixed(2)} €'
                          : '…',
                      style: TextStyle(
                        color: goldPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    if (totalEarnings != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _changeBadge(earningsChange as num?),
                          const SizedBox(width: 6),
                          Text(
                            'prof_vs_last_30_days'.tr,
                            style: TextStyle(color: textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _statIcon(Icons.euro_rounded),
            ],
          ),
        ),
        height(0.015),

        // ── Croissance : fans / concerts (ce mois) / billets vendus
        Container(
          width: Get.width,
          padding: myPadding,
          decoration: BoxDecoration(
            color: cardDeep,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: goldSecondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'prof_your_growth'.tr,
                    style: TextStyle(
                      color: ivory,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'prof_this_month'.tr,
                    style: TextStyle(color: textMuted, fontSize: 11.5),
                  ),
                ],
              ),
              height(0.015),
              Row(
                children: [
                  Expanded(
                    child: _growthStat(
                      icon: Icons.confirmation_number_outlined,
                      label: 'prof_tickets_sold'.tr,
                      value: ticketsTotal?.toString(),
                      changePct: ticketsChange as num?,
                    ),
                  ),
                  Expanded(
                    child: _growthStat(
                      icon: Icons.favorite_border_rounded,
                      label: 'prof_fans'.tr,
                      value: fansTotal != null
                          ? _compactNumber(fansTotal as num)
                          : null,
                      changePct: fansChange as num?,
                    ),
                  ),
                  Expanded(
                    child: _growthStat(
                      icon: Icons.graphic_eq_rounded,
                      label: 'prof_live_shows'.tr,
                      value: showsThisMonth?.toString(),
                      changePct: showsChange as num?,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _growthStat({
    required IconData icon,
    required String label,
    required String? value,
    required num? changePct,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statIcon(icon),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: textMuted, fontSize: 11.5),
        ),
        Text(
          value ?? '…',
          style: TextStyle(
            color: ivory,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (value != null) _changeBadge(changePct),
      ],
    );
  }

  String _compactNumber(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  /// Section "Outils & Ressources" : raccourcis vers les écrans artiste déjà
  /// existants (revenus, événements/analytics) — rien de nouveau à créer.
  Widget _toolsAndResources() {
    final tools = [
      {
        'icon': Icons.event_available_outlined,
        'title': 'prof_tool_live_manager'.tr,
        'subtitle': 'prof_tool_live_manager_sub'.tr,
        'onTap': () => Get.to(() => const ArtistEventsScreen()),
      },
      {
        'icon': Icons.insights_outlined,
        'title': 'prof_tool_analytics'.tr,
        'subtitle': 'prof_tool_analytics_sub'.tr,
        'onTap': () => Get.to(() => const ArtistEventsScreen()),
      },
      {
        'icon': Icons.payments_outlined,
        'title': 'prof_tool_monetization'.tr,
        'subtitle': 'prof_tool_monetization_sub'.tr,
        'onTap': () => Get.to(() => const RevenueScreen()),
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'prof_tools_resources'.tr,
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        height(0.015),
        ...tools.map(
          (t) => GestureDetector(
            onTap: t['onTap'] as VoidCallback,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _statIcon(t['icon'] as IconData),
                  width(0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['title'] as String,
                          style: TextStyle(
                            color: ivory,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          t['subtitle'] as String,
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_sharp,
                    size: 14,
                    color: goldSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future unSub(String topic) async =>
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

/// Traînée de paillettes dorées en diagonale, à forte opacité,
/// pour habiller la carte profil (style comète).
class _SparkleTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final paint = Paint()
      ..color = goldPrimary
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);

    const count = 70;
    for (int i = 0; i < count; i++) {
      final t = i / count;
      // Axe diagonal : du centre-haut vers le bas-droite
      final baseX = size.width * (0.40 + t * 0.62);
      final baseY = size.height * (0.02 + t * 1.0);
      final jitterX = (rnd.nextDouble() - 0.5) * size.width * 0.28;
      final jitterY = (rnd.nextDouble() - 0.5) * size.height * 0.32;
      final x = baseX + jitterX;
      final y = baseY + jitterY;

      // Plus dense / opaque vers la fin de la traînée
      final r = 0.6 + rnd.nextDouble() * 2.4;
      final op = (0.25 + rnd.nextDouble() * 0.45 + t * 0.25).clamp(0.0, 0.85);
      paint.color = goldPrimary.withValues(alpha: op);
      canvas.drawCircle(Offset(x, y), r, paint);

      // Quelques éclats en étoile à 4 branches
      if (rnd.nextDouble() > 0.82) {
        final s = 3.0 + rnd.nextDouble() * 3.0;
        final star = Paint()
          ..color = goldPrimary.withValues(alpha: op.clamp(0.0, 0.8))
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), star);
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), star);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkleTrailPainter oldDelegate) => false;
}

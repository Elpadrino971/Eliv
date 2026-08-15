import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_clips_grid.dart';
import 'package:artist/travis_scott/events_screen.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ArtistDetailScreen extends StatefulWidget {
  ArtistDetailScreen({super.key, this.artist, this.iD});
  User? artist;
  final int? iD;

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final eventController = Get.find<EventController>();

  Future myInitMethod() async {
    if (widget.iD != null) {
      await eventController.getUserModel(id: '${widget.iD ?? 1}');
      widget.artist = eventController.artistProfile.value.user!;
      setState(() {});
    }
    final id = '${widget.artist?.id ?? 1}';
    await eventController.getArtistEvents(artistId: id);
    await eventController.getArtistFollowers(artistId: id);
    await eventController.getArtistClips(artistId: id);
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  String get _handle {
    final n = (widget.artist?.artistName ?? widget.artist?.fullName ?? 'artiste');
    return '@${n.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
  }

  bool get _isFollowing {
    final ids = eventController.artistFollowers.value.data?.followers
            ?.map((e) => e.id)
            .toList() ??
        [];
    return ids.contains(userModel.value.user?.id);
  }

  Future<void> _toggleFollow() async {
    eventController.isLoading.value = true;
    eventController.update();
    try {
      if (_isFollowing) {
        await eventController.unfollowArtist(artistId: '${widget.artist?.id ?? 1}');
      } else {
        await eventController.followArtist(artistId: '${widget.artist?.id ?? 1}');
      }
    } catch (_) {}
    await eventController.getArtistFollowers(artistId: '${widget.artist?.id ?? 1}');
    eventController.isLoading.value = false;
    eventController.update();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Get.isDarkMode;
    final txt = dark ? whiteColor : blackColor;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _identity(txt)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBar(
                bg: bg,
                tabBar: TabBar(
                  labelColor: txt,
                  dividerColor: greyColor.withValues(alpha: 0.15),
                  indicatorColor: dark ? goldPrimary : mainThemeColor,
                  unselectedLabelColor: const Color(0xff737373),
                  tabs: const [
                    Tab(text: 'Shorts'),
                    Tab(text: 'Clips'),
                    Tab(text: 'Concerts'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              const ArtistClipsGrid(feed: 'for_you'),
              const ArtistClipsGrid(feed: 'clips'),
              Obx(() => EventsScreen(
                    events: eventController.artistEvents.value.data ?? [],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── PARTIE 1 : grande image plein cadre (façon Netflix/Spotify) ──
  Widget _identity(Color txt) {
    final dark = Get.isDarkMode;
    final w = Get.width;
    final img = widget.artist?.profileImage ?? widget.artist?.artistProfile ?? '';
    final bio = (widget.artist?.artistBio?.trim().isNotEmpty ?? false)
        ? widget.artist!.artistBio!
        : (widget.artist?.bio ?? '');
    final top = MediaQuery.of(context).padding.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grande image du visage, plein cadre, sans bord ni arrondi.
        Stack(
          children: [
            SizedBox(
              width: w,
              height: w * 1.08,
              child: ImageWidget(url: img, width: w, height: w * 1.08, fit: BoxFit.cover),
            ),
            // Voiles pour lisibilité (haut sombre pour les boutons, bas pour le texte).
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.32),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            // Barre du haut (retour / partager / menu).
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _circleBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
                  const Spacer(),
                  _circleBtn(Icons.share_outlined, () {}),
                  const SizedBox(width: 8),
                  _circleBtn(Icons.more_horiz_rounded, () {}),
                ],
              ),
            ),
            // Identité par-dessus le bas de l'image.
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.artist?.artistName ?? widget.artist?.fullName ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _handle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13.5,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(() {
                    final followers =
                        eventController.artistFollowers.value.data?.followersCount ?? 0;
                    final clips = eventController.artistClips.value.count;
                    final concerts =
                        (eventController.artistEvents.value.data ?? []).length;
                    return Row(
                      children: [
                        _statLight('$followers', 'Abonnés'),
                        _vsep(),
                        _statLight('$clips', 'Vidéos'),
                        _vsep(),
                        _statLight('$concerts', 'Concerts'),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        // Boutons + bio, sous l'image.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GetBuilder<EventController>(
                      init: eventController,
                      builder: (_) => GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isFollowing
                                ? Colors.transparent
                                : (dark ? goldPrimary : mainThemeColor),
                            border: Border.all(color: goldPrimary, width: 1.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: eventController.isLoading.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isFollowing
                                      ? 'live_following'.tr
                                      : 'live_follow_artist'.tr,
                                  style: TextStyle(
                                    color: _isFollowing ? goldPrimary : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _ghostBtn(
                    icon: Icons.playlist_add,
                    label: 'Ma liste',
                    onTap: () => Get.snackbar(
                      'Bientôt',
                      'La liste arrive très vite 🎬',
                      snackPosition: SnackPosition.BOTTOM,
                    ),
                  ),
                ],
              ),
              if (bio.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  bio,
                  style: TextStyle(color: txt.withValues(alpha: 0.85), fontSize: 13, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _statLight(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)])),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 6)])),
        ],
      );

  Widget _vsep() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.white.withValues(alpha: 0.28),
      );

  Widget _ghostBtn({required IconData icon, String? label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: goldPrimary.withValues(alpha: 0.55), width: 1.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: goldPrimary, size: 19),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: goldPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// En-tête persistant (épinglé) qui garde la TabBar visible au scroll.
class _StickyTabBar extends SliverPersistentHeaderDelegate {
  _StickyTabBar({required this.tabBar, required this.bg});
  final TabBar tabBar;
  final Color bg;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: bg, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBar oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.bg != bg;
}

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
      body: SafeArea(
        bottom: false,
        child: DefaultTabController(
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
      ),
    );
  }

  // ── PARTIE 1 : identité centrée (façon TikTok) ──
  Widget _identity(Color txt) {
    final dark = Get.isDarkMode;
    final bio = (widget.artist?.artistBio?.trim().isNotEmpty ?? false)
        ? widget.artist!.artistBio!
        : (widget.artist?.bio ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Image.asset('assets/button_image3.png', width: 30, height: 30),
              ),
              const Spacer(),
              Image.asset('assets/button_image2.png', width: 30, height: 30),
              width(0.02),
              Image.asset('assets/button_image1.png', width: 30, height: 30),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldPrimary, width: 2),
            ),
            child: ClipOval(
              child: ImageWidget(
                url: widget.artist?.profileImage ?? widget.artist?.artistProfile ?? '',
                width: 92,
                height: 92,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.artist?.artistName ?? widget.artist?.fullName ?? 'N/A',
            style: TextStyle(color: txt, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(_handle, style: const TextStyle(color: Color(0xff737373), fontSize: 13.5)),
          const SizedBox(height: 10),
          // Stats
          Obx(() {
            final followers =
                eventController.artistFollowers.value.data?.followersCount ?? 0;
            final clips = eventController.artistClips.value.count;
            final concerts =
                (eventController.artistEvents.value.data ?? []).length;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat('$followers', 'Abonnés', txt),
                _divider(),
                _stat('$clips', 'Vidéos', txt),
                _divider(),
                _stat('$concerts', 'Concerts', txt),
              ],
            );
          }),
          const SizedBox(height: 16),
          // Boutons : Suivre + Ma liste + Partager
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
              const SizedBox(width: 9),
              _ghostBtn(
                icon: Icons.share_outlined,
                onTap: () {},
              ),
            ],
          ),
          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffcbd8ea), fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color txt) => Column(
        children: [
          Text(value, style: TextStyle(color: txt, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xff737373), fontSize: 12)),
        ],
      );

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: greyColor.withValues(alpha: 0.25),
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

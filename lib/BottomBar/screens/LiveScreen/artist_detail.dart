import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/guest_gate.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/bio_links.dart';
import 'package:artist/BottomBar/screens/LiveScreen/artist_clips_grid.dart';
import 'package:artist/travis_scott/about_screen.dart';
import 'package:artist/travis_scott/events_screen.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/services/moderation_service.dart';
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
    eventController.checkArtistSaved(artistId: id);
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

  // Partage de l'artiste (tout sauf les concerts, qui ont leur propre
  // partage "invitation" côté écran concert).
  void _shareArtist() {
    final name = widget.artist?.artistName ?? widget.artist?.fullName ?? 'cet artiste';
    myShare(
      message:
          'Découvre $name sur VybzzZ 🎤🔥\nLives, clips & concerts exclusifs.\nhttps://vybzzz.online',
    );
  }

  void _openAbout() {
    Get.to(() => AboutScreen(artist: widget.artist ?? User()));
  }

  /// Menu « … » : à propos, signaler, bloquer.
  /// Le signalement et le blocage sont exigés par la règle 1.2 de l'App Store
  /// pour toute application qui affiche du contenu publié par des utilisateurs.
  void _openMenu() {
    final a = widget.artist;
    final id = a?.id;
    final name = a?.artistName ?? a?.fullName ?? 'cet artiste';
    final isMe = id != null && id == userModel.value.user?.id;
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          decoration: const BoxDecoration(
            color: midnightSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded, color: goldPrimary),
                title: Text('about_title'.tr, style: const TextStyle(color: ivory, fontWeight: FontWeight.w600)),
                onTap: () {
                  Get.back();
                  _openAbout();
                },
              ),
              if (!isMe && id != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: goldPrimary),
                  title: Text('mod_report'.tr, style: const TextStyle(color: ivory, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Get.back();
                    ModerationService.showActions(context, userId: id, name: name);
                  },
                ),
              if (!isMe && id != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded, color: Color(0xffE2584A)),
                  title: Text('mod_block'.tr, style: const TextStyle(color: Color(0xffE2584A), fontWeight: FontWeight.w600)),
                  onTap: () {
                    Get.back();
                    ModerationService.showActions(context, userId: id, name: name);
                  },
                ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _toggleFollow() async {
    if (!await requireAccount(reason: 'guest_reason_follow'.tr)) return;
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
    // Structure éprouvée : identité fixe en haut + TabBar + Expanded(TabBarView).
    // (Pas de NestedScrollView : instable avec Obx + EventsScreen imbriqués.)
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            _identity(txt),
            TabBar(
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
            Expanded(
              child: TabBarView(
                children: [
                  const ArtistClipsGrid(feed: 'for_you'),
                  const ArtistClipsGrid(feed: 'clips'),
                  Obx(() => EventsScreen(
                        events: eventController.artistEvents.value.data ?? [],
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Identité : grande image plein cadre (façon Netflix/Spotify) ──
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
        SizedBox(
          width: w,
          height: w * 0.62,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageWidget(url: img, width: w, height: w * 0.62, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.32),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.74),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _circleBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
                    const Spacer(),
                    _circleBtn(Icons.share_outlined, _shareArtist),
                    const SizedBox(width: 8),
                    _circleBtn(Icons.more_horiz_rounded, _openMenu),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artist?.artistName ?? widget.artist?.fullName ?? 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _handle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 10),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                          height: 42,
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
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Obx(() {
                    final saved = eventController.artistSaved.value;
                    return _ghostBtn(
                      icon: saved
                          ? Icons.playlist_add_check_rounded
                          : Icons.playlist_add_rounded,
                      label: saved ? 'common_in_my_list'.tr : 'common_my_list'.tr,
                      onTap: () async {
                        if (!await requireAccount(
                          reason: 'guest_reason_follow'.tr,
                        )) {
                          return;
                        }
                        eventController.toggleSaveArtist(
                          artistId: '${widget.artist?.id ?? 0}',
                        );
                      },
                    );
                  }),
                ],
              ),
              if (bio.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: txt.withValues(alpha: 0.85), fontSize: 12.5, height: 1.4),
                ),
              ],
              // Liens en bio (contact + réseaux) — cliquables, façon TikTok.
              const SizedBox(height: 10),
              BioLinks(user: widget.artist),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openAbout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, color: goldPrimary, size: 16),
                    const SizedBox(width: 5),
                    Text('À propos de l\'artiste',
                        style: TextStyle(
                            color: goldPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Icon(Icons.chevron_right_rounded, color: goldPrimary, size: 18),
                  ],
                ),
              ),
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
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)])),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11.5,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 6)])),
        ],
      );

  Widget _vsep() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withValues(alpha: 0.28),
      );

  Widget _ghostBtn({required IconData icon, String? label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
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
                      color: goldPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

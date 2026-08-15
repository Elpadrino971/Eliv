import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/artist_clips_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Grille des vidéos d'un artiste pour UN feed donné, affichée dans un onglet
/// de la fiche profil (façon TikTok). Ne fait pas d'appel réseau : la fiche
/// charge les clips une fois (getArtistClips) et cette grille lit l'état.
///  • feed 'for_you' → Shorts : grille portrait 3 colonnes.
///  • feed 'clips'   → Clips  : cartes paysage 16:9, un tap = plein écran paysage.
class ArtistClipsGrid extends StatelessWidget {
  const ArtistClipsGrid({super.key, required this.feed});

  /// 'for_you' (Shorts) ou 'clips' (Clips musicaux).
  final String feed;

  bool get _isClipsFeed => feed == 'clips';

  void _open(ArtistClip clip) {
    final hasMux =
        clip.muxPlaybackId != null && clip.muxPlaybackId!.isNotEmpty;
    final hasUrl = clip.videoUrl != null && clip.videoUrl!.isNotEmpty;
    if (!hasMux && !hasUrl) return;
    Get.to(() => ReplayPlayerScreen(
          playbackId: hasMux ? clip.muxPlaybackId : null,
          url: hasMux ? null : clip.videoUrl,
          title: clip.title,
          forceLandscape: _isClipsFeed,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ec = Get.find<EventController>();
    return Obx(() {
      final model = ec.artistClips.value;
      final loading = ec.artistClipsLoading.value;
      final rows = model.list
          .where((c) => _isClipsFeed ? c.feed == 'clips' : c.feed == 'for_you')
          .toList();
      if (loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (rows.isEmpty) {
        return _empty(_isClipsFeed
            ? 'Aucun clip pour le moment'
            : 'Aucun short pour le moment');
      }
      return _isClipsFeed ? _clipsList(rows) : _shortsGrid(rows);
    });
  }

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Text(msg, style: TextStyle(color: greyColor)),
        ),
      );

  // ── Shorts : grille portrait 3 colonnes ──
  Widget _shortsGrid(List<ArtistClip> rows) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 9 / 16,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _open(rows[i]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _thumb(rows[i], centerIcon: false),
        ),
      ),
    );
  }

  // ── Clips musicaux : cartes paysage 16:9 pleine largeur ──
  Widget _clipsList(List<ArtistClip> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final clip = rows[i];
        return GestureDetector(
          onTap: () => _open(clip),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _thumb(clip, centerIcon: true),
                ),
              ),
              if (clip.title != null && clip.title!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    clip.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Vignette commune (fond + image Mux + voile + icône play).
  Widget _thumb(ArtistClip clip, {required bool centerIcon}) {
    final hasThumb = clip.thumbnail != null && clip.thumbnail!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xff1a1a1a)),
        if (hasThumb)
          ImageWidget(url: clip.thumbnail!, fit: BoxFit.cover)
        else
          Center(
            child: Icon(Icons.play_circle_outline,
                color: whiteColor.withValues(alpha: 0.85), size: 34),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        if (centerIcon)
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
            ),
          )
        else
          const Positioned(
            right: 6,
            bottom: 6,
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          ),
      ],
    );
  }
}

import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/artist_clips_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Contenu vidéo d'un artiste sur sa fiche, en 2 sous-onglets distincts :
///  • Shorts  = feed "Pour toi" (vertical / portrait, façon TikTok, 3 colonnes)
///  • Clips   = clips musicaux (paysage 16:9, cartes pleine largeur)
/// Un tap sur un short ouvre le lecteur portrait ; un clip s'ouvre en plein
/// écran paysage automatique.
class ArtistClipsGrid extends StatefulWidget {
  const ArtistClipsGrid({super.key, required this.artistId});

  final String artistId;

  @override
  State<ArtistClipsGrid> createState() => _ArtistClipsGridState();
}

class _ArtistClipsGridState extends State<ArtistClipsGrid> {
  final eventController = Get.find<EventController>();
  String _tab = 'shorts'; // shorts (for_you) | clips

  @override
  void initState() {
    super.initState();
    eventController.getArtistClips(artistId: widget.artistId);
  }

  void _open(ArtistClip clip, {required bool landscape}) {
    final hasMux =
        clip.muxPlaybackId != null && clip.muxPlaybackId!.isNotEmpty;
    final hasUrl = clip.videoUrl != null && clip.videoUrl!.isNotEmpty;
    if (!hasMux && !hasUrl) return;
    Get.to(() => ReplayPlayerScreen(
          playbackId: hasMux ? clip.muxPlaybackId : null,
          url: hasMux ? null : clip.videoUrl,
          title: clip.title,
          forceLandscape: landscape,
        ));
  }

  Widget _chip(String value, String label, int count) {
    final active = _tab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? goldPrimary : Colors.transparent,
            border: Border.all(
                color: active ? goldPrimary : greyColor.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              color: active
                  ? blackColor
                  : (Get.isDarkMode ? whiteColor : blackColor),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final model = eventController.artistClips.value;
      final loading = eventController.artistClipsLoading.value;
      final shorts =
          model.list.where((c) => c.feed == 'for_you').toList();
      final clips = model.list.where((c) => c.feed == 'clips').toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('shorts', 'Shorts', shorts.length),
              _chip('clips', 'Clips', clips.length),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (_tab == 'shorts'
                    ? _shortsGrid(shorts)
                    : _clipsList(clips)),
          ),
        ],
      );
    });
  }

  // ── Shorts : grille portrait 3 colonnes (façon TikTok) ──
  Widget _shortsGrid(List<ArtistClip> rows) {
    if (rows.isEmpty) {
      return _empty('Aucun short pour le moment');
    }
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 9 / 16,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => _portraitTile(rows[i]),
    );
  }

  // ── Clips musicaux : cartes paysage 16:9 pleine largeur ──
  Widget _clipsList(List<ArtistClip> rows) {
    if (rows.isEmpty) {
      return _empty('Aucun clip pour le moment');
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _landscapeCard(rows[i]),
    );
  }

  Widget _empty(String msg) => Center(
        child: Text(msg, style: TextStyle(color: greyColor)),
      );

  Widget _portraitTile(ArtistClip clip) {
    return GestureDetector(
      onTap: () => _open(clip, landscape: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _thumb(clip, const Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: 18)),
      ),
    );
  }

  Widget _landscapeCard(ArtistClip clip) {
    return GestureDetector(
      onTap: () => _open(clip, landscape: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _thumb(
                clip,
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
                ),
                centerIcon: true,
              ),
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
  }

  // Vignette commune (fond + image Mux + voile + icône play).
  Widget _thumb(ArtistClip clip, Widget playIcon, {bool centerIcon = false}) {
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
          Center(child: playIcon)
        else
          Positioned(right: 6, bottom: 6, child: playIcon),
      ],
    );
  }
}

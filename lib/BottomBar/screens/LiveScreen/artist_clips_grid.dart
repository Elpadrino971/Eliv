import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Models/artist_clips_model.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/replay_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Grille "façon TikTok" des posts d'un artiste (feeds "Pour toi" + "Clips").
/// Sous-onglets Tous / Pour toi / Clips, vignettes 3 colonnes en portrait.
/// Un tap ouvre le lecteur plein écran ([ReplayPlayerScreen]).
class ArtistClipsGrid extends StatefulWidget {
  const ArtistClipsGrid({super.key, required this.artistId});

  final String artistId;

  @override
  State<ArtistClipsGrid> createState() => _ArtistClipsGridState();
}

class _ArtistClipsGridState extends State<ArtistClipsGrid> {
  final eventController = Get.find<EventController>();
  String _tab = 'all'; // all | for_you | clips

  @override
  void initState() {
    super.initState();
    eventController.getArtistClips(artistId: widget.artistId);
  }

  List<ArtistClip> _rows(ArtistClipsModel m) {
    if (_tab == 'clips') {
      return m.list.where((c) => c.feed == 'clips').toList();
    }
    if (_tab == 'for_you') {
      return m.list.where((c) => c.feed == 'for_you').toList();
    }
    return m.list;
  }

  void _open(ArtistClip clip) {
    final hasMux =
        clip.muxPlaybackId != null && clip.muxPlaybackId!.isNotEmpty;
    final hasUrl = clip.videoUrl != null && clip.videoUrl!.isNotEmpty;
    if (!hasMux && !hasUrl) return; // rien à lire
    Get.to(() => ReplayPlayerScreen(
          playbackId: hasMux ? clip.muxPlaybackId : null,
          url: hasMux ? null : clip.videoUrl,
          title: clip.title,
        ));
  }

  Widget _chip(String value, String label, int count) {
    final active = _tab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
      final rows = _rows(model);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('all', 'Tous', model.count),
                _chip('for_you', 'Pour toi', model.counts.forYou),
                _chip('clips', 'Clips', model.counts.clips),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun post pour le moment',
                          style: TextStyle(color: greyColor),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 9 / 16,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (context, i) => _tile(rows[i]),
                      ),
          ),
        ],
      );
    });
  }

  Widget _tile(ArtistClip clip) {
    return GestureDetector(
      onTap: () => _open(clip),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xff1a1a1a)),
            if (clip.thumbnail != null && clip.thumbnail!.isNotEmpty)
              ImageWidget(url: clip.thumbnail!, fit: BoxFit.cover)
            else
              Center(
                child: Icon(Icons.play_circle_outline,
                    color: whiteColor.withValues(alpha: 0.85), size: 34),
              ),
            // Voile bas + play icon pour lisibilité.
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
            const Positioned(
              right: 6,
              bottom: 6,
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 18),
            ),
            // Petit badge feed en haut à gauche.
            Positioned(
              left: 5,
              top: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  clip.feed == 'clips' ? 'Clip' : 'Pour toi',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

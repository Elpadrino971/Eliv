import 'dart:io';

import 'package:artist/Controllers/ArtistController/artist_controller.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/ZegoCloud/start_stream.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Image par défaut d'un live sans affiche (servie par le backend).
const String kDefaultLiveCoverUrl =
    'https://api.vybzzz.online/defaults/live-cover.jpg';

/// Choix de la feuille « Lancer un live » : titre + image facultative.
class _QuickLiveChoice {
  const _QuickLiveChoice({required this.title, this.coverPath});
  final String title;
  final String? coverPath;
}

/// Live instantané : un titre, un bouton, et l'artiste est en direct.
///
/// Pas de date, de prix ni de genre à remplir : le concert est créé gratuit,
/// commence maintenant et dure au plus 4 heures. L'image est facultative
/// (image par défaut côté serveur). Pour un concert payant ou programmé, le
/// formulaire complet reste disponible (+).
Future<void> openQuickLive() async {
  final user = userModel.value.user;
  final name = (user?.artistName?.isNotEmpty ?? false)
      ? user!.artistName!
      : (user?.fullName ?? '');
  final controller = TextEditingController(
    text: name.isEmpty ? '' : 'quick_live_default_title'.trParams({'name': name}),
  );

  final choice = await Get.bottomSheet<_QuickLiveChoice>(
    _QuickLiveSheet(controller: controller),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  if (choice == null || choice.title.trim().isEmpty) return;

  final artistController = Get.isRegistered<ArtistController>()
      ? Get.find<ArtistController>()
      : Get.put(ArtistController(), permanent: true);
  final event = await artistController.createQuickLive(
    title: choice.title.trim(),
    coverPath: choice.coverPath,
  );
  if (event == null) return;

  if (!await ensureLivePermissions()) return;
  await Get.to(() => StartStream(event: event));

  // Fin du live. StartStream.dispose() appelle déjà /recording/stop, qui
  // passe le concert en « terminé » côté serveur SEULEMENT s'il était
  // réellement en direct (status = 'live'). On ne force plus 'completed' à
  // l'aveugle : un live jamais lancé (token Zego refusé, retour arrière…)
  // était sinon marqué terminé. Filet : si le serveur le voit encore 'live'
  // (appel de stop perdu), on clôt nous-mêmes.
  final eventController = Get.isRegistered<EventController>()
      ? Get.find<EventController>()
      : Get.put(EventController());
  final fresh = await eventController.getEventById(event.id.toString());
  if (fresh?.status == 'live') {
    await eventController.updateEventStatus(
      eventId: event.id.toString(),
      status: 'completed',
    );
  }
  await artistController.getArtistEvents(artistId: '${user?.id ?? ''}');
}

class _QuickLiveSheet extends StatefulWidget {
  const _QuickLiveSheet({required this.controller});
  final TextEditingController controller;

  @override
  State<_QuickLiveSheet> createState() => _QuickLiveSheetState();
}

class _QuickLiveSheetState extends State<_QuickLiveSheet> {
  final ImagePicker _picker = ImagePicker();
  // Image choisie dans la galerie (null = image par défaut du serveur).
  File? _cover;

  TextEditingController get controller => widget.controller;

  Future<void> _pickCover() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        setState(() => _cover = File(image.path));
      }
    } catch (e) {
      myPrint('quickLive: pickImage -> $e');
    }
  }

  void _submit() {
    final t = controller.text.trim();
    if (t.length < 2) return;
    Get.back(result: _QuickLiveChoice(title: t, coverPath: _cover?.path));
  }

  // Vignette « Image du live (facultatif) » : aperçu de l'image par défaut
  // ou de l'image choisie ; un tap ouvre la galerie.
  Widget _coverTile() {
    return GestureDetector(
      onTap: _pickCover,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 60,
              child: _cover != null
                  ? Image.file(_cover!, fit: BoxFit.cover)
                  : const ImageWidget(
                      url: kDefaultLiveCoverUrl,
                      width: 96,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'quick_cover_label'.tr,
                  style: const TextStyle(
                    color: ivory,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cover != null
                      ? 'quick_cover_change'.tr
                      : 'quick_cover_pick'.tr,
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_cover != null)
            IconButton(
              tooltip: 'quick_cover_remove'.tr,
              onPressed: () => setState(() => _cover = null),
              icon: const Icon(Icons.close_rounded, color: textMuted),
            )
          else
            const Icon(Icons.photo_library_outlined, color: goldPrimary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: cardDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ivory.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'quick_live_title'.tr,
                style: const TextStyle(
                  color: ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'quick_live_note'.tr,
                style: const TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: ivory, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'quick_live_hint'.tr,
                  hintStyle: const TextStyle(color: textMuted),
                  counterText: '',
                  filled: true,
                  fillColor: midnightPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _coverTile(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                  label: Text(
                    'quick_live_go'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0245E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

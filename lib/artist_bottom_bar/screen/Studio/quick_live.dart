import 'package:artist/Controllers/ArtistController/artist_controller.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/ZegoCloud/start_stream.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Live instantané : un titre, un bouton, et l'artiste est en direct.
///
/// Pas d'affiche, de date, de prix ni de genre à remplir : le concert est
/// créé gratuit, commence maintenant et dure au plus 4 heures. Pour un
/// concert payant ou programmé, le formulaire complet reste disponible (+).
Future<void> openQuickLive() async {
  final user = userModel.value.user;
  final name = (user?.artistName?.isNotEmpty ?? false)
      ? user!.artistName!
      : (user?.fullName ?? '');
  final controller = TextEditingController(
    text: name.isEmpty ? '' : 'quick_live_default_title'.trParams({'name': name}),
  );

  final title = await Get.bottomSheet<String>(
    _QuickLiveSheet(controller: controller),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  if (title == null || title.trim().isEmpty) return;

  final artistController = Get.isRegistered<ArtistController>()
      ? Get.find<ArtistController>()
      : Get.put(ArtistController(), permanent: true);
  final event = await artistController.createQuickLive(title: title.trim());
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

class _QuickLiveSheet extends StatelessWidget {
  const _QuickLiveSheet({required this.controller});
  final TextEditingController controller;

  void _submit() {
    final t = controller.text.trim();
    if (t.length < 2) return;
    Get.back(result: t);
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

import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Créer un short : n'importe quel utilisateur connecté peut soumettre une
/// vidéo pour le feed "Pour toi" ou "Clips". Elle reste invisible tant que
/// l'admin ne l'a pas approuvée (rubrique "Clips (Feeds)" du backend) —
/// pas de modération automatique, donc validation manuelle avant publication.
class CreateShortScreen extends StatefulWidget {
  const CreateShortScreen({super.key});

  @override
  State<CreateShortScreen> createState() => _CreateShortScreenState();
}

class _CreateShortScreenState extends State<CreateShortScreen> {
  final _picker = ImagePicker();
  final _response = ApiResponse();
  final _titleController = TextEditingController();
  XFile? _video;
  String _feed = 'clips';
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final v = await _picker.pickVideo(source: ImageSource.gallery);
    if (v != null) setState(() => _video = v);
  }

  Future<void> _publish() async {
    if (_video == null) return;
    setState(() => _busy = true);
    try {
      _response.typeSetter = 'post';
      _response.urlSetter = APIs.feedClipSubmitAPI;
      _response.bodySetter = {
        'feed': _feed,
        if (_titleController.text.trim().isNotEmpty)
          'title': _titleController.text.trim(),
      };
      final res = await _response.hitMultipartAPI(_video!.path, key: 'video');

      if (res.split(' ').first == 'error') {
        myWarningDialog(
          title: 'common_error'.tr,
          subtitle: "Échec de l'envoi. Réessaie.",
        );
        return;
      }

      mySuccessDialog(
        title: 'Envoyé !',
        subtitle:
            "Ton clip est en attente de validation avant d'apparaître dans le feed.",
        ontap: () {
          Get.back();
          Get.back();
        },
      );
    } catch (_) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: "Échec de l'envoi. Réessaie.",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _feedToggle() {
    Widget option(String value, String label) {
      final active = _feed == value;
      return Expanded(
        child: GestureDetector(
          onTap: _busy ? null : () => setState(() => _feed = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? goldPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? midnightPrimary : ivory,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardDeep,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [option('for_you', 'Pour toi'), option('clips', 'Clips')],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: midnightPrimary,
      appBar: MyAppbar(title: 'Créer un short'),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            height(0.02),
            _feedToggle(),
            height(0.015),
            Text(
              "En lien avec la scène : danse, stand-up, chant, sport, gospel… "
              "(le hors-sujet ne sera pas validé)",
              style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
            ),
            height(0.02),
            GestureDetector(
              onTap: _busy ? null : _pick,
              child: Container(
                height: Get.height * 0.42,
                decoration: BoxDecoration(
                  color: cardDeep,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: goldPrimary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _video == null
                            ? Icons.video_call_rounded
                            : Icons.check_circle_rounded,
                        color: goldPrimary,
                        size: 56,
                      ),
                      height(0.015),
                      Text(
                        _video == null
                            ? 'Choisir une vidéo verticale'
                            : 'Vidéo sélectionnée ✓',
                        style: TextStyle(
                          color: ivory,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_video != null) ...[
                        height(0.008),
                        Text(
                          _video!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            height(0.02),
            TextField(
              controller: _titleController,
              enabled: !_busy,
              style: TextStyle(color: ivory),
              decoration: InputDecoration(
                hintText: 'Titre / légende (optionnel)',
                hintStyle: TextStyle(color: textMuted),
                filled: true,
                fillColor: cardDeep,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
            _busy
                ? const Center(
                    child: CircularProgressIndicator(color: goldPrimary),
                  )
                : MyButton(
                    label: 'Publier',
                    onTap: _video == null ? () {} : _publish,
                  ),
            height(0.03),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Créer un short : n'importe quel utilisateur connecté peut soumettre une
/// vidéo pour le feed "Pour toi" ou "Clips". Elle reste invisible tant que
/// l'admin ne l'a pas approuvée (rubrique "Clips (Feeds)" du backend) —
/// pas de modération automatique, donc validation manuelle avant publication.
class CreateShortScreen extends StatefulWidget {
  const CreateShortScreen({super.key, this.sharedVideoPath});

  /// Vidéo reçue via « Partager → VYBZZZ » (partage natif). Si fournie, l'écran
  /// s'ouvre avec la vidéo déjà chargée : l'artiste n'a plus qu'à publier.
  final String? sharedVideoPath;

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
  void initState() {
    super.initState();
    // Pré-remplissage depuis un partage entrant (galerie / autre app).
    if (widget.sharedVideoPath != null && widget.sharedVideoPath!.isNotEmpty) {
      _video = XFile(widget.sharedVideoPath!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final v = await _picker.pickVideo(source: ImageSource.gallery);
    if (v != null) setState(() => _video = v);
  }

  /// Envoi direct vers Mux : le fichier PUT directement sur Mux, jamais sur
  /// notre serveur. Renvoie false (sans lever d'exception) si Mux n'est pas
  /// configuré côté serveur ou si l'upload échoue, pour laisser _publish()
  /// basculer sur l'ancien flux (upload vers notre serveur).
  Future<bool> _publishViaMuxDirect() async {
    final directResp = ApiResponse();
    directResp.typeSetter = 'post';
    directResp.urlSetter = APIs.feedClipSubmitDirectAPI;
    directResp.bodySetter = {
      'feed': _feed,
      if (_titleController.text.trim().isNotEmpty)
        'title': _titleController.text.trim(),
    };
    final res = await directResp.hitAPI();
    if (res is! String || res.split(' ').first == 'error') return false;

    final uploadUrl = jsonDecode(res)['data']?['upload_url'] as String?;
    if (uploadUrl == null) return false;

    final bytes = await File(_video!.path).readAsBytes();
    final put = await http.put(Uri.parse(uploadUrl), body: bytes);
    return put.statusCode >= 200 && put.statusCode < 300;
  }

  Future<void> _publish() async {
    if (_video == null) return;
    setState(() => _busy = true);
    try {
      bool sent = false;
      try {
        sent = await _publishViaMuxDirect();
      } catch (_) {
        sent = false;
      }

      if (!sent) {
        _response.typeSetter = 'post';
        _response.urlSetter = APIs.feedClipSubmitAPI;
        _response.bodySetter = {
          'feed': _feed,
          if (_titleController.text.trim().isNotEmpty)
            'title': _titleController.text.trim(),
        };
        final res = await _response.hitMultipartAPI(
          _video!.path,
          key: 'video',
        );
        sent = res.split(' ').first != 'error';
      }

      if (!sent) {
        myWarningDialog(
          title: 'common_error'.tr,
          subtitle: 'short_send_failed'.tr,
        );
        return;
      }

      mySuccessDialog(
        title: 'short_sent_title'.tr,
        subtitle: 'short_sent_sub'.tr,
        ontap: () {
          Get.back();
          Get.back();
        },
      );
    } catch (_) {
      myWarningDialog(
        title: 'common_error'.tr,
        subtitle: 'short_send_failed'.tr,
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
      appBar: MyAppbar(title: 'short_create_title'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            height(0.02),
            _feedToggle(),
            height(0.015),
            Text(
              'short_create_hint_desc'.tr,
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
                hintText: 'short_caption_hint'.tr,
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
                    label: 'short_publish'.tr,
                    onTap: _video == null ? () {} : _publish,
                  ),
            height(0.03),
          ],
        ),
      ),
    );
  }
}

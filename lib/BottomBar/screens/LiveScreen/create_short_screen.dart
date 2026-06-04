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

/// [SCAFFOLD UGC] Créer un short : l'utilisateur choisit/film une vidéo
/// verticale, l'app demande au backend une URL d'upload Mux (Direct Upload)
/// puis envoie le fichier. Le short apparaîtra dans le feed "Pour toi" après
/// traitement par Mux. Tant que l'endpoint backend n'existe pas, on informe
/// proprement ("bientôt disponible").
class CreateShortScreen extends StatefulWidget {
  const CreateShortScreen({super.key});

  @override
  State<CreateShortScreen> createState() => _CreateShortScreenState();
}

class _CreateShortScreenState extends State<CreateShortScreen> {
  final _picker = ImagePicker();
  final _response = ApiResponse();
  XFile? _video;
  bool _busy = false;

  Future<void> _pick() async {
    final v = await _picker.pickVideo(source: ImageSource.gallery);
    if (v != null) setState(() => _video = v);
  }

  Future<void> _publish() async {
    if (_video == null) return;
    setState(() => _busy = true);
    try {
      // 1) Demander une URL d'upload Mux au backend.
      _response.typeSetter = 'post';
      _response.urlSetter = APIs.createShortUploadAPI;
      _response.bodySetter = {'user_id': '${userModel.value.user?.id}'};
      final res = await _response.hitAPI();

      if (res.split(' ').first == 'error') {
        _comingSoon();
        return;
      }
      final data = jsonDecode(res);
      final uploadUrl = data['upload_url'];
      if (uploadUrl == null || '$uploadUrl'.isEmpty) {
        _comingSoon();
        return;
      }

      // 2) Envoyer la vidéo directement à Mux (PUT du fichier brut).
      final bytes = await File(_video!.path).readAsBytes();
      final put = await http.put(
        Uri.parse(uploadUrl),
        headers: const {'Content-Type': 'video/mp4'},
        body: bytes,
      );

      if (put.statusCode >= 200 && put.statusCode < 300) {
        mySuccessDialog(
          title: 'Short publié !',
          subtitle: 'Il apparaîtra dans le feed après traitement.',
          ontap: () {
            Get.back();
            Get.back();
          },
        );
      } else {
        myWarningDialog(
          title: 'common_error'.tr,
          subtitle: "Échec de l'envoi. Réessaie.",
        );
      }
    } catch (_) {
      _comingSoon();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _comingSoon() {
    myWarningDialog(
      title: 'Bientôt disponible',
      subtitle:
          "L'upload de shorts arrive très bientôt (branchement Mux côté serveur).",
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
            GestureDetector(
              onTap: _busy ? null : _pick,
              child: Container(
                height: Get.height * 0.5,
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

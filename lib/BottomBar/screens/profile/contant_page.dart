import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Page de texte légal (CGU, confidentialité…).
///
/// [content] peut être null : les textes viennent de `AuthController.settings`,
/// vide tant que `getSettings()` n'a pas répondu (ouverture depuis
/// l'inscription, réseau lent…). Avant, un null ici faisait planter la page.
/// Avec [settingsKey], la page redemande le texte au serveur si besoin et
/// propose « Réessayer ».
class ContantPage extends StatefulWidget {
  const ContantPage({
    super.key,
    required this.title,
    this.content,
    this.settingsKey,
  });
  final String title;
  final String? content;

  /// Clé dans `AuthController.settings` (ex. 'terms_and_conditions').
  final String? settingsKey;

  @override
  State<ContantPage> createState() => _ContantPageState();
}

class _ContantPageState extends State<ContantPage> {
  final authController = Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController(), permanent: true);
  bool _loading = false;

  String _text() {
    final raw = (widget.content ?? '').trim();
    if (raw.isNotEmpty) return raw;
    final key = widget.settingsKey;
    if (key == null) return '';
    return (authController.settings[key] ?? '').toString().trim();
  }

  @override
  void initState() {
    super.initState();
    if (_text().isEmpty && widget.settingsKey != null) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await authController.getSettings();
    } catch (e) {
      myPrint(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text();
    return Scaffold(
      appBar: MyAppbar(title: widget.title),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: CircularProgressIndicator(color: goldPrimary),
                ),
              )
            else if (text.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Column(
                    children: [
                      Text(
                        'content_unavailable'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: greyColor, fontSize: 16),
                      ),
                      if (widget.settingsKey != null) ...[
                        height(0.02),
                        MyButton(
                          label: 'common_retry'.tr,
                          onTap: _reload,
                          labelColor: midnightPrimary,
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontSize: 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w300,
                ),
              ),
            height(0.05),
          ],
        ),
      ),
    );
  }
}

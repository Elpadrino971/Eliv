import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/contant_page.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Écran « À propos » : numéro de version visible dans l'app (exigence App
/// Store / Play), + accès direct à la Politique de confidentialité et aux CGU
/// (RGPD). Aucune donnée sensible, purement informatif.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<String> _versionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version} (${info.buildNumber})';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: MyAppbar(title: 'about_title'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              height(0.03),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 88,
                  height: 88,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: cardDeep,
                    child: const Icon(Icons.music_note,
                        color: goldPrimary, size: 40),
                  ),
                ),
              ),
              height(0.015),
              Text(
                'VybzzZ',
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              FutureBuilder<String>(
                future: _versionLabel(),
                builder: (context, snap) {
                  return Text(
                    snap.data ?? '',
                    style: const TextStyle(
                      color: Color(0xff737373),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  );
                },
              ),
              height(0.03),

              MyContainer(
                widget: Column(
                  children: [
                    ListTile(
                      onTap: () => Get.to(
                        () => ContantPage(
                          title: 'prof_privacy'.tr,
                          content: authController.settings['privacy_policy'],
                        ),
                      ),
                      minTileHeight: 40,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shield_outlined,
                          color: goldPrimary, size: 26),
                      title: Text(
                        'prof_privacy'.tr,
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: greyColor),
                    ),
                    Divider(color: greyColor.withValues(alpha: 0.2)),
                    ListTile(
                      onTap: () => Get.to(
                        () => ContantPage(
                          title: 'prof_terms'.tr,
                          content:
                              authController.settings['terms_and_conditions'],
                        ),
                      ),
                      minTileHeight: 40,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined,
                          color: goldPrimary, size: 26),
                      title: Text(
                        'prof_terms'.tr,
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: greyColor),
                    ),
                  ],
                ),
              ),

              height(0.04),
              Text(
                '© 2026 VybzzZ',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              height(0.08),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:artist/Auth/create_acount.dart';
import 'package:artist/Auth/forgot_password.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Feuille douce affichée quand la connexion email / mot de passe échoue.
/// Remplace l'ancien dialogue "Warning" (rouge, en anglais, bloquant) par une
/// aide contextuelle : proposer de créer le compte s'il n'existe pas, ou de
/// réinitialiser le mot de passe s'il est faux.
///
/// [code] vient du backend (`no_account`, `bad_password`), ou vaut `network`
/// si l'appel n'a pas abouti. Tout autre code = message générique.
Future<void> showLoginFailedSheet({required String? code, required String email}) {
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback primaryTap;
  String? secondaryLabel;
  VoidCallback? secondaryTap;

  switch (code) {
    case 'no_account':
      title = 'login_no_account_title'.tr;
      body = 'login_no_account_body'.trParams({'email': email});
      primaryLabel = 'auth_create_account'.tr;
      primaryTap = () {
        Get.back();
        Get.to(() => CreateAcount(initialEmail: email));
      };
      secondaryLabel = 'login_retry'.tr;
      secondaryTap = Get.back;
      break;
    case 'bad_password':
      title = 'login_bad_password_title'.tr;
      body = 'login_bad_password_body'.tr;
      primaryLabel = 'auth_forgot_password_q'.tr;
      primaryTap = () {
        Get.back();
        Get.to(() => ForgotPassword());
      };
      secondaryLabel = 'login_retry'.tr;
      secondaryTap = Get.back;
      break;
    case 'network':
      title = 'login_network_title'.tr;
      body = 'login_network_body'.tr;
      primaryLabel = 'login_retry'.tr;
      primaryTap = Get.back;
      break;
    default:
      title = 'login_failed_title'.tr;
      body = 'login_failed_body'.tr;
      primaryLabel = 'auth_create_account'.tr;
      primaryTap = () {
        Get.back();
        Get.to(() => CreateAcount(initialEmail: email));
      };
      secondaryLabel = 'auth_forgot_password_q'.tr;
      secondaryTap = () {
        Get.back();
        Get.to(() => ForgotPassword());
      };
  }

  return Get.bottomSheet(
    SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        decoration: const BoxDecoration(
          color: midnightSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: goldPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ivory,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: textXolor, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 18),
            MyButton(
              label: primaryLabel,
              onTap: primaryTap,
              labelColor: midnightPrimary,
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: secondaryTap,
                child: Text(
                  secondaryLabel,
                  style: const TextStyle(
                    color: goldPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

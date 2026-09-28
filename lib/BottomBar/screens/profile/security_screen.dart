import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// « Mot de passe et sécurité » : changement de mot de passe (ancien,
/// nouveau, confirmation) + bouton Enregistrer -> AuthController.updatePassword.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final authController = Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController(), permanent: true);
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final conformPasswordController = TextEditingController();
  var showPassword = false;
  var showPassword2 = false;
  var showPassword3 = false;

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    conformPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldPassword = oldPasswordController.text;
    final newPassword = newPasswordController.text;
    final confirm = conformPasswordController.text;
    if (oldPassword.isEmpty) {
      myWarningDialog(subtitle: 'sec_old_required'.tr);
      return;
    }
    if (newPassword.length < 8) {
      myWarningDialog(subtitle: 'val_password_min'.tr);
      return;
    }
    if (newPassword != confirm) {
      myWarningDialog(subtitle: 'sec_pwd_mismatch'.tr);
      return;
    }
    FocusScope.of(context).unfocus();
    await authController.updatePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: greyColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  Widget _eye(bool visible, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        visible ? Icons.remove_red_eye : Icons.visibility_off,
        color: greyColor,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'sec_title'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.08),
              _label('sec_old_pwd'.tr),
              height(0.01),
              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: oldPasswordController,
                // Masqué tant que l'œil n'est pas activé (avant, la logique
                // était inversée : le mot de passe s'affichait en clair).
                isObscure: !showPassword,
                trailing: _eye(showPassword, () {
                  setState(() {
                    showPassword = !showPassword;
                  });
                }),
              ),

              height(0.01),

              _label('sec_new_pwd'.tr),
              height(0.01),
              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: newPasswordController,
                isObscure: !showPassword2,
                trailing: _eye(showPassword2, () {
                  setState(() {
                    showPassword2 = !showPassword2;
                  });
                }),
              ),

              height(0.01),

              _label('sec_confirm_pwd'.tr),
              height(0.01),
              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: conformPasswordController,
                isObscure: !showPassword3,
                trailing: _eye(showPassword3, () {
                  setState(() {
                    showPassword3 = !showPassword3;
                  });
                }),
              ),

              height(0.03),

              MyButton(
                label: 'sec_save'.tr,
                onTap: _save,
                labelColor: midnightPrimary,
              ),
              height(0.03),
            ],
          ),
        ),
      ),
    );
  }
}

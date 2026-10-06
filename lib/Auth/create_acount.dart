import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/contant_page.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateAcount extends StatefulWidget {
  const CreateAcount({super.key, this.initialEmail, this.closable = false});

  /// Ouvert depuis le mode visiteur (voir guest_gate.dart) : croix de retour.
  final bool closable;

  /// Email saisi sur l'écran de connexion, repris ici pour ne pas le retaper.
  final String? initialEmail;

  @override
  State<CreateAcount> createState() => _CreateAcountState();
}

class _CreateAcountState extends State<CreateAcount> {
  final authController = Get.find<AuthController>();

  late final emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final passwordController = TextEditingController();
  bool hiddinPassword = true;
  bool acceptedTerms = false;

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.closable
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: ivory),
                onPressed: () => Get.back(),
              ),
            )
          : null,
      body: Container(
        padding: myPadding,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.06),

              Text(
                'auth_create_account'.tr,
                style: TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(
                width: Get.width * 0.65,
                child: Text(
                  'signup_subtitle'.tr,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 212, 212, 212),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      MyTextField(
                        hintText: 'name@email.com',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validation: (value) {
                          if (value == null || value.isEmpty) {
                            return 'val_enter_email'.tr;
                          }
                          if (!GetUtils.isEmail(value)) {
                            return 'val_valid_email'.tr;
                          }
                          return null;
                        },
                        leading: Image.asset(
                          'assets/mail_icon.png',
                          width: 15,
                          height: 15,
                        ),
                      ),

                      MyTextField(
                        isObscure: hiddinPassword,
                        hintText: 'auth_password'.tr,
                        controller: passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        onChanged: (value) {
                          formKey.currentState!.validate();
                        },
                        validation: (value) {
                          if (value == null || value.isEmpty) {
                            return 'val_enter_password'.tr;
                          }
                          if (value.length < 8) {
                            return 'val_password_min'.tr;
                          }
                          return null;
                        },
                        leading: Image.asset(
                          'assets/lock_icon.png',
                          width: 15,
                          height: 15,
                        ),

                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              hiddinPassword = !hiddinPassword;
                            });
                          },
                          icon: hiddinPassword
                              ? Icon(
                                  Icons.remove_red_eye_rounded,
                                  color: Color(0xffD4D4D4),
                                )
                              : Icon(
                                  Icons.visibility_off_rounded,
                                  color: Color(0xffD4D4D4),
                                ),
                        ),
                      ),
                      height(0.02),

                      // Consentement RGPD : l'utilisateur accepte CGU +
                      // Politique de confidentialité avant de créer un compte.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: acceptedTerms,
                              activeColor: goldPrimary,
                              checkColor: midnightPrimary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) =>
                                  setState(() => acceptedTerms = v ?? false),
                            ),
                          ),
                          width(0.02),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  color: Color(0xff737373),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(text: 'auth_consent_prefix'.tr),
                                  TextSpan(
                                    text: 'prof_terms'.tr,
                                    style: const TextStyle(
                                      color: goldPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Get.to(
                                            () => ContantPage(
                                              title: 'prof_terms'.tr,
                                              content: (authController.settings['terms_and_conditions'] ?? '').toString(),
                                              settingsKey: 'terms_and_conditions',
                                            ),
                                          ),
                                  ),
                                  TextSpan(text: 'auth_consent_and'.tr),
                                  TextSpan(
                                    text: 'prof_privacy'.tr,
                                    style: const TextStyle(
                                      color: goldPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Get.to(
                                            () => ContantPage(
                                              title: 'prof_privacy'.tr,
                                              content: (authController.settings['privacy_policy'] ?? '').toString(),
                                              settingsKey: 'privacy_policy',
                                            ),
                                          ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      height(0.02),

                      MyButton(
                        label: 'auth_create_account'.tr,
                        onTap: () async {
                          if (!acceptedTerms) {
                            myWarningDialog(
                              subtitle: 'auth_consent_required'.tr,
                            );
                            return;
                          }
                          if (formKey.currentState!.validate()) {
                            final email = emailController.text.trim();
                            await authController.signupUser(
                              email: email,
                              password: passwordController.text,
                              // Plus de champ « nom » : le prénom se règle
                              // plus tard dans le profil. D'ici là, la partie
                              // avant le @ sert de nom affiché.
                              name: email.split('@').first,
                            );
                          }
                        },
                        image: 'assets/arrow.png',
                        imageColor: midnightPrimary,
                        labelColor: midnightPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: myPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'auth_have_account'.tr,
              style: TextStyle(
                color: Color(0xffA1A1A1),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            width(0.02),

            GestureDetector(
              onTap: () {
                Get.to(() => LoginScreen(closable: widget.closable));
              },
              child: Text(
                'auth_sign_in'.tr,
                style: TextStyle(
                  color: mainThemeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

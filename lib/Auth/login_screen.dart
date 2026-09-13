import 'dart:io';

import 'package:artist/Auth/create_acount.dart';
import 'package:artist/Auth/forgot_password.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/google_sign_in.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Message DOUX quand la connexion Google n'aboutit pas (annulation ou
/// indisponible). Remplace l'ancien gros « Warning » rouge, jugé agressif —
/// surtout qu'une simple annulation du choix de compte le déclenchait.
void _showGoogleUnavailable() {
  // Annulation par l'utilisateur : rien à dire.
  final reason = googleLastError;
  if (reason == null) return;
  Get.snackbar(
    'google_signin_title'.tr,
    '${'google_signin_failed'.tr} ($reason)',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: cardDeep,
    colorText: ivory,
    margin: const EdgeInsets.all(14),
    borderRadius: 14,
    duration: const Duration(seconds: 4),
    icon: const Icon(Icons.info_outline_rounded, color: goldPrimary),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authController = Get.put(AuthController());

  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var hiddinPassword = true;
  final formKey = GlobalKey<FormState>();

  // La permission de notifications n'est PLUS demandée ici : un visiteur sans
  // compte voyait surgir la fenêtre système "VybzzZ souhaite vous envoyer des
  // notifications" dès l'écran de connexion. Elle est demandée après
  // connexion, dans MyBottomBar.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? midnightPrimary : Color(0xfffffcf6),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/launch_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    midnightPrimary.withOpacity(0.55),
                    midnightPrimary.withOpacity(0.88),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: myPadding,

          child: Form(
            key: formKey,
            child: Column(
              children: [
                height(0.2),
                // Image.asset('assets/logo2.png'),
                Text(
                  textAlign: TextAlign.center,
                  'Welcome',
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),

                // height(0.01),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textAlign: TextAlign.center,
                      'To VyB',
                      style: TextStyle(
                        color: Get.isDarkMode ? whiteColor : blackColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      textAlign: TextAlign.center,
                      'zzZ',
                      style: TextStyle(
                        color: goldPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                height(0.01),

                SizedBox(
                  width: Get.width * 0.7,
                  child: Text(
                    textAlign: TextAlign.center,
                    'auth_tagline'.tr,
                    style: TextStyle(
                      color: greyColor,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                  ),
                ),

                height(0.01),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        MyTextField(
                          hintText: 'auth_email_address'.tr,
                          controller: emailController,
                          validation: (val) {
                            if (val == null || val.isEmpty) {
                              return 'val_enter_email'.tr;
                            } else if (!GetUtils.isEmail(val)) {
                              return 'val_valid_email'.tr;
                            }
                            return null;
                          },
                          leading: Image.asset(
                            'assets/mail_icon.png',
                            width: 15,
                            height: 15,
                            color: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                          textColor: Get.isDarkMode ? whiteColor : blackColor,
                        ),

                        MyTextField(
                          isObscure: hiddinPassword,
                          hintText: 'auth_password'.tr,
                          controller: passwordController,
                          validation: (val) {
                            if (val == null || val.isEmpty) {
                              return 'val_enter_password'.tr;
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
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                  )
                                : Icon(
                                    Icons.visibility_off_rounded,
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                  ),
                          ),
                          textColor: Get.isDarkMode ? whiteColor : blackColor,
                        ),

                        height(0.01),

                        Row(
                          children: [
                            Spacer(),
                            InkWell(
                              onTap: () async {
                                navigator?.push(
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return ForgotPassword();
                                    },
                                  ),
                                );
                              },
                              child: Text(
                                'auth_forgot_password_q'.tr,
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? goldPrimary
                                      : mainThemeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        height(0.02),

                        MyButton(
                          label: 'auth_sign_in'.tr,
                          onTap: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              // Get.to(() => BottomBar());
                              // Get.to(() => IntroScreen());
                              await authController.loginUser(
                                email: emailController.text,
                                password: passwordController.text,
                              );
                            }
                          },
                          image: 'assets/arrow.png',
                          imageColor: midnightPrimary,
                          labelColor: midnightPrimary,
                        ),
                        height(0.02),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: textXolor, thickness: 2),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'auth_or_continue_with'.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textXolor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Divider(color: textXolor, thickness: 2),
                            ),
                          ],
                        ),
                        height(0.02),

                        (Platform.isAndroid)
                            ? GestureDetector(
                                onTap: () async {
                                  final user = await signInWithGoogle();
                                  if (user != null) {
                                    await authController.socialLogin(
                                      email: user.email,
                                      name: user.name,
                                      idToken: user.idToken,
                                      provider: 'google',
                                    );
                                  } else {
                                    _showGoogleUnavailable();
                                  }
                                },
                                child: SizedBox(
                                  width: Get.width * 0.4,
                                  height: 60,
                                  child: Container(
                                    padding: myPadding,
                                    decoration: BoxDecoration(
                                      color: cardDeep,
                                      border: Border.all(
                                        color: Color(0xff223046),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Image.asset(
                                      'assets/google_icon.png',
                                      height: 40,
                                      width: Get.width * 0.1,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final user = await signInWithGoogle();
                                      if (user != null) {
                                        await authController.socialLogin(
                                          email: user.email,
                                          name: user.name,
                                          idToken: user.idToken,
                                          provider: 'google',
                                        );
                                      } else {
                                        _showGoogleUnavailable();
                                      }
                                    },
                                    child: SizedBox(
                                      width: Get.width * 0.43,
                                      height: 50,
                                      child: Container(
                                        padding: myPadding,
                                        decoration: BoxDecoration(
                                          color: cardDeep,
                                          border: Border.all(
                                            color: Color(0xff223046),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Image.asset(
                                          'assets/google_icon.png',
                                        ),
                                      ),
                                    ),
                                  ),

                                  Spacer(),

                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await SignInWithApple.getAppleIDCredential(
                                          scopes: [
                                            AppleIDAuthorizationScopes.email,
                                            AppleIDAuthorizationScopes.fullName,
                                          ],
                                        ).then((value) async {
                                          await authController.socialLogin(
                                            email:
                                                value.email?.toString() ??
                                                value.userIdentifier.toString(),
                                            name:
                                                value.givenName?.toString() ??
                                                'iOS User',
                                            identityToken: value.identityToken,
                                            provider: 'apple',
                                          );
                                        }).onError((error, stackTrace) {
                                          myPrint(
                                            'Apple sign in error: ${error.toString()}',
                                          );
                                          _showGoogleUnavailable();
                                        });
                                      } catch (e) {
                                        myPrint(e);
                                      }
                                    },
                                    child: SizedBox(
                                      width: Get.width * 0.43,
                                      height: 50,
                                      child: Container(
                                        padding: myPadding,
                                        decoration: BoxDecoration(
                                          color: cardDeep,
                                          border: Border.all(
                                            color: Color(0xff223046),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Image.asset(
                                          'assets/apple_icon.png',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        height(0.03),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'login_no_account_q'.tr,
                              style: TextStyle(
                                color: Color(0xffA1A1A1),
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                            width(0.02),

                            GestureDetector(
                              onTap: () {
                                Get.to(() => CreateAcount());
                              },
                              child: Text(
                                'login_join_now'.tr,
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? goldPrimary
                                      : mainThemeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}

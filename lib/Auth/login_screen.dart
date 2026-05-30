import 'dart:io';

import 'package:artist/Auth/create_acount.dart';
import 'package:artist/Auth/forgot_password.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/google_sign_in.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  Future<void> init() async {
    await PushNotificationSystem().requestIOSPermissions();
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? blackColor : Color(0xfffffcf6),

      body: Center(
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
                        color: yellowColor,
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
                    'Your front row seat to the future of music.',
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
                          hintText: 'Email Address',
                          controller: emailController,
                          validation: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your email';
                            } else if (!GetUtils.isEmail(val)) {
                              return 'Please enter a valid email';
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
                          hintText: 'Password',
                          controller: passwordController,
                          validation: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password';
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
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? redColor
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
                          label: 'Sign In  ',
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
                          imageColor: whiteColor,
                          labelColor: whiteColor,
                        ),
                        height(0.02),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: Get.width * 0.24,
                              child: Divider(color: textXolor, thickness: 2),
                            ),

                            Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                color: textXolor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            SizedBox(
                              width: Get.width * 0.24,
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
                                      email: user.email ?? '',
                                      name: user.displayName ?? 'Google User',
                                      phone: user.phoneNumber,
                                    );
                                  } else {
                                    myWarningDialog(
                                      subtitle: 'Please try again later',
                                    );
                                  }
                                },
                                child: SizedBox(
                                  width: Get.width * 0.4,
                                  height: 60,
                                  child: Container(
                                    padding: myPadding,
                                    decoration: BoxDecoration(
                                      color: Color(0xffFAFAFA),
                                      border: Border.all(
                                        color: Color(0xffF5F5F5),
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
                                  SizedBox(
                                    width: Get.width * 0.43,
                                    height: 50,
                                    child: Container(
                                      padding: myPadding,
                                      decoration: BoxDecoration(
                                        color: Color(0xffFAFAFA),
                                        border: Border.all(
                                          color: Color(0xffF5F5F5),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Image.asset(
                                        'assets/google_icon.png',
                                      ),
                                    ),
                                  ),

                                  Spacer(),

                                  SizedBox(
                                    width: Get.width * 0.43,
                                    height: 50,
                                    child: Container(
                                      padding: myPadding,
                                      decoration: BoxDecoration(
                                        color: Color(0xffFAFAFA),
                                        border: Border.all(
                                          color: Color(0xffF5F5F5),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Image.asset(
                                        'assets/apple_icon.png',
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
                              "Don't have an account?",
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
                                "Join Now",
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? redColor
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
    );
  }
}

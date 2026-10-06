import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreatePasswrod extends StatefulWidget {
  const CreatePasswrod({
    super.key,
    this.fromForget = false,
    this.email,
    this.otp,
  });
  final bool fromForget;
  final String? email;

  /// Code reçu par e-mail (mot de passe oublié) : envoyé avec le nouveau
  /// mot de passe à /reset-password.
  final String? otp;

  @override
  State<CreatePasswrod> createState() => _CreatePasswrodState();
}

class _CreatePasswrodState extends State<CreatePasswrod> {
  final authController = Get.find<AuthController>();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var newPasswordController = TextEditingController();
  var hiddinPassword = true;
  var hiddinPassword2 = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'auth_create_password'.tr),
      body: Container(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pwd_new_title'.tr,
              style: TextStyle(
                color: ivory,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(
              width: Get.width * 0.65,
              child: Text(
                'pwd_new_sub'.tr,
                style: TextStyle(
                  color: const Color.fromARGB(255, 212, 212, 212),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            height(0.02),

            MyTextField(
              isObscure: hiddinPassword2,
              hintText: 'auth_new_password'.tr,
              controller: passwordController,

              leading: Image.asset(
                'assets/lock_icon.png',
                width: 15,
                height: 15,
              ),

              textColor: Get.isDarkMode ? whiteColor : blackColor,
              trailing: IconButton(
                onPressed: () {
                  setState(() {
                    hiddinPassword2 = !hiddinPassword2;
                  });
                },
                icon: hiddinPassword2
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

            MyTextField(
              isObscure: hiddinPassword,
              hintText: 'auth_confirm_password'.tr,
              controller: newPasswordController,
              leading: Image.asset(
                'assets/lock_icon.png',
                width: 15,
                height: 15,
              ),

              textColor: Get.isDarkMode ? whiteColor : blackColor,

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

            MyButton(
              label: 'auth_update_password'.tr,
              onTap: () async {
                final password = passwordController.text;
                if (password.length < 8) {
                  myWarningDialog(subtitle: 'val_password_min'.tr);
                  return;
                }
                if (password != newPasswordController.text) {
                  myWarningDialog(subtitle: 'sec_pwd_mismatch'.tr);
                  return;
                }
                await authController.resetPassword(
                  password: password,
                  email: widget.email ?? '',
                  otp: widget.otp ?? '',
                );
              },
              image: 'assets/arrow.png',
              imageColor: midnightPrimary,
              labelColor: midnightPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

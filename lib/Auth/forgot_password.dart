import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final authController = Get.find<AuthController>();
  var emailController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'auth_forgot_password'.tr),
      body: Container(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'auth_reset_password'.tr,
              style: TextStyle(
                color: ivory,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            height(0.01),
            SizedBox(
              width: Get.width * 0.65,
              child: Text(
                'forgot_sub'.tr,
                style: TextStyle(
                  color: const Color.fromARGB(255, 212, 212, 212),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            height(0.02),

            MyTextField(
              hintText: 'auth_email_address'.tr,
              controller: emailController,

              leading: Image.asset(
                'assets/mail_icon.png',
                width: 15,
                height: 15,
              ),
              textColor: Get.isDarkMode ? whiteColor : blackColor,
            ),
            height(0.02),

            height(0.05),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: myPadding,
        child: MyButton(
          onTap: () async {
            await authController.forgetPassword(
              email: emailController.text,
              froResent: false,
            );
          },
          label: 'auth_send_link'.tr,
          image: 'assets/arrow.png',
          imageColor: midnightPrimary,
          labelColor: midnightPrimary,
        ),
      ),
    );
  }
}

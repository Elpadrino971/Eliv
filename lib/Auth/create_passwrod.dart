import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreatePasswrod extends StatefulWidget {
  const CreatePasswrod({super.key, this.fromForget = false, this.email});
  final bool fromForget;
  final String? email;

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
      appBar: MyAppbar(title: 'Create passwrd'),
      body: Container(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Security ',
              style: TextStyle(
                color: blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(
              width: Get.width * 0.65,
              child: Text(
                "Create a password that is unique and easy to remember.",
                style: TextStyle(
                  color: const Color.fromARGB(255, 212, 212, 212),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            height(0.02),

            MyTextField(
              isObscure: hiddinPassword2,
              hintText: 'New Password',
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
              hintText: 'Confirm Password',
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
              label: 'Update Password ',
              onTap: () async {
                await authController.resetPassword(
                  password: passwordController.text,
                  email: widget.email ?? '',
                );
              },
              image: 'assets/arrow.png',
              imageColor: whiteColor,
              labelColor: whiteColor,
            ),
          ],
        ),
      ),
    );
  }
}

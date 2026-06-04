import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
// import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
// import 'package:get/get_navigation/src/extension_navigation.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  var swichValue = false;
  var oldPasswordController = TextEditingController();
  var newPasswordController = TextEditingController();
  var conformPasswordController = TextEditingController();
  var showPassword = false;
  var showPassword2 = false;
  var showPassword3 = false;
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
              Text(
                'sec_old_pwd'.tr,
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              height(0.01),
              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: oldPasswordController,
                isObscure: showPassword,

                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  child: Icon(
                    showPassword ? Icons.remove_red_eye : Icons.visibility_off,

                    color: greyColor,
                    size: 20,
                  ),
                ),
              ),

              height(0.01),

              Text(
                'New password',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              height(0.01),
              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: newPasswordController,
                isObscure: showPassword2,

                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      showPassword2 = !showPassword2;
                    });
                  },
                  child: Icon(
                    showPassword2 ? Icons.remove_red_eye : Icons.visibility_off,
                    color: greyColor,
                    size: 20,
                  ),
                ),
              ),

              height(0.01),

              Text(
                'Confirm Password',
                style: TextStyle(
                  color: greyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              height(0.01),

              MyTextField(
                hintText: 'sec_enter_pwd'.tr,
                controller: conformPasswordController,
                isObscure: showPassword3,

                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      showPassword3 = !showPassword3;
                    });
                  },
                  child: Icon(
                    showPassword3 ? Icons.remove_red_eye : Icons.visibility_off,

                    color: greyColor,
                    size: 20,
                  ),
                ),
              ),

              height(0.01),

              // Text(
              //   'sec_2fa'.tr,
              //   style: TextStyle(
              //     color: greyColor,
              //     fontWeight: FontWeight.w600,
              //     fontSize: 14,
              //   ),
              // ),
              // height(0.01),
              // MyContainer(
              //   widget: Column(
              //     children: [
              //       Row(
              //         children: [
              //           Row(
              //             children: [
              //               Image.asset(
              //                 'assets/icon15.png',
              //                 width: 20,
              //                 height: 20,
              //               ),
              //               width(0.02),

              //               Text(
              //                 'common_enabled'.tr,
              //                 style: TextStyle(
              //                   color: Get.isDarkMode ? whiteColor : blackColor,
              //                   fontWeight: FontWeight.bold,
              //                   fontSize: 16,
              //                 ),
              //               ),
              //               height(0.01),
              //             ],
              //           ),
              //           Spacer(),
              //           Switch(
              //             value: swichValue,
              //             onChanged: (value) {
              //               setState(() {
              //                 swichValue = value;
              //               });
              //             },

              //             inactiveThumbColor: whiteColor,
              //             inactiveTrackColor: greyColor,
              //             activeTrackColor: mainThemeColor,
              //             activeThumbColor: whiteColor,
              //           ),
              //         ],
              //       ),

              //       height(0.01),

              //       Text(
              //         'sec_2fa_desc'.tr,
              //         style: TextStyle(
              //           color: greyColor,
              //           fontWeight: FontWeight.w400,
              //           fontSize: 14,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

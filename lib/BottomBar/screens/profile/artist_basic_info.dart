import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/artist_bank_details.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ArtistBankInfo extends StatefulWidget {
  const ArtistBankInfo({super.key});

  @override
  State<ArtistBankInfo> createState() => _ArtistBankInfoState();
}

class _ArtistBankInfoState extends State<ArtistBankInfo> {
  Map body = Get.arguments;

  final authController = Get.find<AuthController>();

  final accountController = TextEditingController();
  final nameController = TextEditingController();
  final numberController = TextEditingController();
  final swiftController = TextEditingController();
  final routingController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  Future myInitMethod() async {
    myPrint(body);
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'prof_become_artist'.tr),

      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: myPadding,
              child: Get.isDarkMode
                  ? Image.asset('assets/active5.png', width: Get.width)
                  : Image.asset(
                      'assets/information_image1.png',
                      width: Get.width,
                    ),
            ),

            height(0.01),

            Container(
              padding: myPadding,
              width: Get.width,
              decoration: BoxDecoration(color: Color(0xffF0FDF4)),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/secure_icon.png', width: 40, height: 40),

                  width(0.03),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sec_protected'.tr,
                        style: TextStyle(
                          // Fond du bandeau = vert clair (0xffF0FDF4) : un texte
                          // ivoire y était illisible -> vert foncé lisible.
                          color: Color(0xff166534),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(
                        width: Get.width * 0.75,
                        child: Text(
                          'bank_secure_note'.tr,
                          style: TextStyle(
                            color: Color(0xff4A5565),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            height(0.01),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: myPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bank_holder'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ivory,
                        ),
                      ),

                      MyTextField(
                        hintText: 'John Doe',
                        controller: accountController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_bank_holder'.tr;
                          }
                          return null;
                        },
                      ),

                      Text(
                        'bank_name'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ivory,
                        ),
                      ),

                      MyTextField(
                        hintText: 'Chase Bank',
                        controller: nameController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_bank_name'.tr;
                          }
                          return null;
                        },
                      ),

                      Text(
                        'bank_account_num'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ivory,
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: numberController,

                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_bank_account'.tr;
                          }
                          return null;
                        },
                      ),
                      Text(
                        'bank_swift'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ivory,
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: swiftController,
                        isObscure: true,

                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_bank_swift'.tr;
                          }
                          return null;
                        },
                      ),
                      Text(
                        'bank_routing'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ivory,
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: routingController,
                        isObscure: true,
                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_bank_routing'.tr;
                          }
                          return null;
                        },
                      ),
                      height(0.02),

                      MyButton(
                        label: 'common_continue'.tr,
                        onTap: () {
                          if (formKey.currentState!.validate()) {
                            body['account_holder_name'] =
                                accountController.text;
                            body['bank_name'] = nameController.text;
                            body['account_number'] = numberController.text;
                            body['swift_number'] = swiftController.text;
                            body['routing_number'] = routingController.text;
                            Get.to(() => ArtistBankDetails(), arguments: body);
                          }
                        },
                        labelColor: whiteColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

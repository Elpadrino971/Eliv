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
      appBar: MyAppbar(title: 'Become Artist'),

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
                        'Secure & Protected',
                        style: TextStyle(
                          color: blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(
                        width: Get.width * 0.75,
                        child: Text(
                          'Your banking information is encrypted and stored securely. We never share your details.',
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
                        'Account Holder Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: 'John Doe',
                        controller: accountController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'Please enter account holder name';
                          }
                          return null;
                        },
                      ),

                      Text(
                        'Bank Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: 'Chase Bank',
                        controller: nameController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'Please enter bank name';
                          }
                          return null;
                        },
                      ),

                      Text(
                        'Account Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: numberController,

                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'Please enter account number';
                          }
                          return null;
                        },
                      ),
                      Text(
                        'Swift Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: swiftController,
                        isObscure: true,

                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'Please enter swift number';
                          }
                          return null;
                        },
                      ),
                      Text(
                        'Routing Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: '••••••••••',
                        controller: routingController,
                        isObscure: true,
                        keyboardType: TextInputType.number,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'Please enter routing number';
                          }
                          return null;
                        },
                      ),
                      height(0.02),

                      MyButton(
                        label: 'Continue',
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

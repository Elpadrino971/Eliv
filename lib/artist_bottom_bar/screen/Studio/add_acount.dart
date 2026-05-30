import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddAcount extends StatefulWidget {
  const AddAcount({super.key});

  @override
  State<AddAcount> createState() => _AddAcountState();
}

class _AddAcountState extends State<AddAcount> {
  final AuthController authController = Get.find<AuthController>();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController swiftController = TextEditingController();
  final TextEditingController routingController = TextEditingController();

  Future<void> _onAddAccount() async {
    final accHolder = accountController.text.trim();
    final bankName = nameController.text.trim();
    final accNum = numberController.text.trim();
    final swift = swiftController.text.trim();
    final routing = routingController.text.trim();

    if (accHolder.isEmpty || bankName.isEmpty || accNum.isEmpty) {
      myWarningDialog(subtitle: 'Please fill in all core bank details.');
      return;
    }

    await authController.addBank(
      accountHolderName: accHolder,
      bankName: bankName,
      accountNumber: accNum,
      swiftNumber: swift,
      routingNumber: routing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Withdraw'),
      body: Column(
        children: [
          Container(
            padding: myPadding,
            width: Get.width,
            decoration: const BoxDecoration(color: Color(0xffF0FDF4)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/secure_icon.png', width: 40, height: 40),
                width(0.03),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secure & Protected',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(
                      width: Get.width * 0.7,
                      child: const Text(
                        'Your banking information is encrypted and stored securely. We never share your details.',
                        style: TextStyle(
                          color: Color(0xff4A5565),
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
          height(0.01),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: myPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
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
                    ),
                    const Text(
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
                    ),
                    const Text(
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
                      isObscure: true,
                      keyboardType: TextInputType.number,
                    ),
                    const Text(
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
                    ),
                    const Text(
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
                    ),
                    height(0.02),
                    MyButton(
                      label: 'Add Account',
                      onTap: _onAddAccount,
                      labelColor: whiteColor,
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

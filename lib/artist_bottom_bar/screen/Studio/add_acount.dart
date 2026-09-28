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
      myWarningDialog(subtitle: 'art_val_bank_details'.tr);
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
      appBar: MyAppbar(title: 'art_withdraw'.tr),
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
                    Text(
                      'sec_protected'.tr,
                      style: const TextStyle(
                        // Titre sur bandeau vert clair : vert foncé lisible.
                        color: Color(0xff166534),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(
                      width: Get.width * 0.7,
                      child: Text(
                        'art_secure_desc'.tr,
                        style: const TextStyle(
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
                    Text(
                      'bank_holder'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF4EFE6),
                      ),
                    ),
                    MyTextField(
                      hintText: 'art_hint_holder_name'.tr,
                      controller: accountController,
                    ),
                    Text(
                      'bank_name'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF4EFE6),
                      ),
                    ),
                    MyTextField(
                      hintText: 'hint_bank_name'.tr,
                      controller: nameController,
                    ),
                    Text(
                      'bank_account_num'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF4EFE6),
                      ),
                    ),
                    // IBAN / numéro de compte : lettres + chiffres, saisi en
                    // clair et en majuscules.
                    MyTextField(
                      hintText: 'FR76 …',
                      controller: numberController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    Text(
                      'bank_swift'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF4EFE6),
                      ),
                    ),
                    MyTextField(
                      hintText: 'BNPAFRPP',
                      controller: swiftController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    Text(
                      'bank_routing'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF4EFE6),
                      ),
                    ),
                    MyTextField(
                      hintText: '••••••••••',
                      controller: routingController,
                      keyboardType: TextInputType.number,
                    ),
                    height(0.02),
                    MyButton(
                      label: 'art_add_account'.tr,
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

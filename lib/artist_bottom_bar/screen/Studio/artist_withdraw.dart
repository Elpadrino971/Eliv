import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/banks_model.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/add_acount.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ArtistWithdraw extends StatefulWidget {
  const ArtistWithdraw({super.key});

  @override
  State<ArtistWithdraw> createState() => _ArtistWithdrawState();
}

class _ArtistWithdrawState extends State<ArtistWithdraw> {
  final AuthController authController = Get.find<AuthController>();
  final TextEditingController priceController = TextEditingController();
  ListElement? selectedBank;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    await authController.getBank();
  }

  void _onConfirmWithdraw() {
    final String amount = priceController.text.trim();
    if (amount.isEmpty) {
      myWarningDialog(subtitle: 'art_val_withdraw_amount'.tr);
      return;
    }

    if (selectedBank == null) {
      myWarningDialog(subtitle: 'art_val_payout_method'.tr);
      return;
    }

    final double balance =
        double.tryParse(userModel.value.user?.wallet?.toString() ?? '0') ?? 0;
    final double withdrawalValue = double.tryParse(amount) ?? 0;

    if (withdrawalValue > balance) {
      myWarningDialog(
        subtitle: 'art_err_insufficient_points'.tr,
      );
      return;
    }

    authController.withdraw(
      bankId: selectedBank!.id.toString(),
      amount: amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'art_withdraw'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Overview
              Container(
                padding: myPadding,
                width: Get.width,
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? goldPrimary : blackColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/payment_icon2.png',
                          width: 30,
                          height: 30,
                        ),
                        const Spacer(),
                        Text(
                          'rev_available_balance'.tr,
                          style: const TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    height(0.01),
                    Obx(
                      () => Text(
                        '${userModel.value.user?.wallet ?? 0} €',
                        style: const TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      'rev_ready_payout'.tr,
                      style: const TextStyle(
                        color: whiteColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              height(0.02),
              Text(
                'art_withdrawal_amount'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Get.isDarkMode ? whiteColor : blackColor,
                ),
              ),
              height(0.01),

              MyTextField(
                hintText: 'art_enter_amount'.tr,
                controller: priceController,
                keyboardType: TextInputType.number,
              ),

              height(0.015),

              // Dynamic Suggestion Pills
              Obx(() {
                final double currentBalance =
                    double.tryParse(
                      userModel.value.user?.wallet?.toString() ?? '0',
                    ) ??
                    0;

                final List<String> suggestions = [];
                if (currentBalance >= 100) suggestions.add('100');
                if (currentBalance >= 500) suggestions.add('500');
                if (currentBalance >= 1000) suggestions.add('1000');
                suggestions.add('All');

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: suggestions.map((s) {
                    return GestureDetector(
                      onTap: () {
                        if (s == 'All') {
                          priceController.text = currentBalance
                              .toStringAsFixed(0);
                        } else {
                          priceController.text = s;
                        }
                      },
                      child: MyContainer(
                        noWidth: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        widget: Text(
                          s == 'All' ? 'art_all'.tr : '$s €',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),

              height(0.03),
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: mainThemeColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'art_payout_methods'.tr,
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              height(0.01),

              // Dynamic Bank List
              Obx(() {
                final list = authController.banks.value.list ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'art_no_banks'.tr,
                        style: const TextStyle(color: greyColor),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => height(0.01),
                  itemBuilder: (context, index) {
                    final bank = list[index];
                    final bool isPicked = selectedBank?.id == bank.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedBank = bank;
                        });
                      },
                      child: MyContainer(
                        border: Border.all(
                          color: isPicked
                              ? (Get.isDarkMode ? goldPrimary : mainThemeColor)
                              : Colors.transparent,
                        ),
                        widget: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: MyContainer(
                            noWidth: true,
                            padding: const EdgeInsets.all(8),
                            color: const Color(0xffFFFDF1),
                            widget: Image.asset(
                              'assets/chase_icon.png',
                              width: 24,
                            ),
                          ),
                          title: Text(
                            bank.bankName ?? 'art_bank'.tr,
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Checking •••• ${bank.accountNumber != null && bank.accountNumber!.length > 4 ? bank.accountNumber!.substring(bank.accountNumber!.length - 4) : bank.accountNumber}',
                            style: TextStyle(
                              color: greyColor.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index == 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffDCFCE7),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: const Color(0xff00A63E),
                                    ),
                                  ),
                                  child: Text(
                                    'art_primary'.tr,
                                    style: const TextStyle(
                                      color: Color(0xff00A63E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Get.isDarkMode ? goldPrimary : Colors.red,
                                  size: 22,
                                ),
                                onPressed: () {
                                  myWarningDialog(
                                    title: 'art_delete_payout_title'.tr,
                                    subtitle: 'art_delete_payout_confirm'
                                        .trParams({
                                          'bank': '${bank.bankName}',
                                          'last4':
                                              '${bank.accountNumber != null && bank.accountNumber!.length > 4 ? bank.accountNumber!.substring(bank.accountNumber!.length - 4) : bank.accountNumber}',
                                        }),
                                    btnTitle: 'common_cancel'.tr,
                                    ontap: () => Get.back(),
                                    secondBtnTitle: 'art_delete'.tr,
                                    secondOnTap: () async {
                                      Get.back(); // close warning dialog
                                      if (selectedBank?.id == bank.id) {
                                        setState(() {
                                          selectedBank = null;
                                        });
                                      }
                                      await authController.deleteBank(
                                        bankId: bank.id.toString(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              height(0.015),

              // Add Method Link
              GestureDetector(
                onTap: () {
                  Get.to(() => const AddAcount());
                },
                child: MyContainer(
                  border: Border.all(
                    color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                  ),
                  widget: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: MyContainer(
                      noWidth: true,
                      padding: const EdgeInsets.all(8),
                      color: whiteColor,
                      widget: const Icon(
                        Icons.add,
                        color: mainThemeColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'art_add_bank_account'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              height(0.04),

              MyButton(
                label: 'art_confirm_withdrawal'.tr,
                onTap: _onConfirmWithdraw,
                labelColor: whiteColor,
                buttonColor: Get.isDarkMode ? goldPrimary : mainThemeColor,
              ),
              height(0.03),
            ],
          ),
        ),
      ),
    );
  }
}

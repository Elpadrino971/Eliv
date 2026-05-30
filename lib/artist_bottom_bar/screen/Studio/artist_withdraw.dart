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
      myWarningDialog(subtitle: 'Please enter a withdrawal amount.');
      return;
    }

    if (selectedBank == null) {
      myWarningDialog(subtitle: 'Please select a payout method.');
      return;
    }

    final double points =
        double.tryParse(userModel.value.user?.points?.toString() ?? '0') ?? 0;
    final double withdrawalValue = double.tryParse(amount) ?? 0;

    if (withdrawalValue > points) {
      myWarningDialog(
        subtitle: 'You do not have enough points for this withdrawal.',
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
      appBar: MyAppbar(title: 'Withdraw'),
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
                  color: Get.isDarkMode ? redColor : blackColor,
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
                        const Text(
                          'Available Balance',
                          style: TextStyle(
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
                        '\$${userModel.value.user?.points ?? 0}',
                        style: const TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Text(
                      'Ready for Payout',
                      style: TextStyle(
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
                'Withdrawal Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Get.isDarkMode ? whiteColor : blackColor,
                ),
              ),
              height(0.01),

              MyTextField(
                hintText: 'Enter amount...',
                controller: priceController,
                keyboardType: TextInputType.number,
              ),

              height(0.015),

              // Dynamic Suggestion Pills
              Obx(() {
                final double currentPoints =
                    double.tryParse(
                      userModel.value.user?.points?.toString() ?? '0',
                    ) ??
                    0;

                final List<String> suggestions = [];
                if (currentPoints >= 100) suggestions.add('100');
                if (currentPoints >= 500) suggestions.add('500');
                if (currentPoints >= 1000) suggestions.add('1000');
                suggestions.add('All');

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: suggestions.map((s) {
                    return GestureDetector(
                      onTap: () {
                        if (s == 'All') {
                          priceController.text = currentPoints.toStringAsFixed(
                            0,
                          );
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
                          s == 'All' ? 'All' : '\$$s',
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
                    'Payout Methods',
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No bank accounts linked.',
                        style: TextStyle(color: greyColor),
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
                              ? (Get.isDarkMode ? redColor : mainThemeColor)
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
                            bank.bankName ?? 'Bank',
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
                                  child: const Text(
                                    'Primary',
                                    style: TextStyle(
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
                                  color: Get.isDarkMode ? redColor : Colors.red,
                                  size: 22,
                                ),
                                onPressed: () {
                                  myWarningDialog(
                                    title: 'Delete Payout Method',
                                    subtitle:
                                        'Are you sure you want to delete ${bank.bankName} ending in ${bank.accountNumber != null && bank.accountNumber!.length > 4 ? bank.accountNumber!.substring(bank.accountNumber!.length - 4) : bank.accountNumber}?',
                                    btnTitle: 'Cancel',
                                    ontap: () => Get.back(),
                                    secondBtnTitle: 'Delete',
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
                    color: Get.isDarkMode ? redColor : mainThemeColor,
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
                    title: const Text(
                      'Add Bank account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              height(0.04),

              MyButton(
                label: 'Confirm Withdrawal',
                onTap: _onConfirmWithdraw,
                labelColor: whiteColor,
                buttonColor: Get.isDarkMode ? redColor : mainThemeColor,
              ),
              height(0.03),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/add_acount.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_withdraw.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/transaction_history.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  final authController = Get.find<AuthController>();
  List<Map<String, dynamic>> transactions = [];
  bool loadingTransactions = true;

  @override
  void initState() {
    super.initState();
    authController.getBank();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final response = ApiResponse();
      response.typeSetter = 'get';
      response.urlSetter = APIs.artistRevenueTransactionsAPI;
      final value = await response.hitAPI();
      if (value is String && value.split(' ').first != 'error') {
        final decoded = jsonDecode(value);
        final list = (decoded['data'] as List?) ?? [];
        if (mounted) {
          setState(() {
            transactions = list.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      myPrint('artist revenue-transactions: $e');
    } finally {
      if (mounted) setState(() => loadingTransactions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'rev_revenue'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rev_earnings'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ivory,
                ),
              ),
              Text(
                'studio_financial_hub'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff737373),
                ),
              ),
              height(0.01),

              // Solde réel (users.wallet, crédité à chaque vente de billet/
              // cadeau via le split de commission) — pas users.points, qui
              // est la monnaie cadeaux des FANS, sans rapport avec les gains.
              MyContainer(
                widget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/payment_icon2.png',
                          width: 30,
                          height: 30,
                        ),
                        Spacer(),
                        Text(
                          'common_default'.tr,
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
                        '${userModel.value.user?.wallet ?? '0'} €',
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    MyButton(
                      label: 'art_withdraw'.tr,
                      onTap: () {
                        Get.to(() => const ArtistWithdraw());
                      },
                      labelColor: whiteColor,
                    ),
                  ],
                ),
              ),
              height(0.02),

              Row(
                children: [
                  Image.asset(
                    'assets/clock.png',
                    width: 17,
                    color: mainThemeColor,
                  ),
                  width(0.02),
                  Text(
                    'art_transactions'.tr,
                    style: TextStyle(
                      color: ivory,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () {
                      Get.to(() => TranssactinHistory(transactions: transactions));
                    },
                    child: Text(
                      'art_view_all'.tr,
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              height(0.01),
              if (loadingTransactions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'art_no_transactions'.tr,
                      style: const TextStyle(color: greyColor),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final amount = (tx['amount'] as num?) ?? 0;
                    return MyContainer(
                      padding: EdgeInsets.only(left: 15, right: 15),
                      widget: ListTile(
                        minTileHeight: 0,
                        contentPadding: EdgeInsets.all(0),
                        title: Text(
                          '${tx['title'] ?? ''}',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${tx['date'] ?? ''}',
                          style: TextStyle(
                            color: Color(0xffA1A1A1),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Text(
                          '+${amount.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: Color(0xff00A63E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => height(0.01),
                  itemCount: transactions.length,
                ),
              height(0.01),

              Row(
                children: [
                  Image.asset(
                    'assets/payout_icon.png',
                    width: 17,
                    color: mainThemeColor,
                  ),
                  width(0.02),
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

              // Vrais comptes bancaires (mêmes données que l'écran de retrait,
              // au lieu du faux "Chase Business" codé en dur).
              Obx(() {
                final banks = authController.banks.value.list ?? [];
                if (banks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'art_no_banks'.tr,
                      style: const TextStyle(color: greyColor),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final bank = banks[index];
                    final last4 = (bank.accountNumber != null &&
                            bank.accountNumber!.length > 4)
                        ? bank.accountNumber!.substring(
                            bank.accountNumber!.length - 4)
                        : bank.accountNumber ?? '';
                    return MyContainer(
                      padding: EdgeInsets.all(10),
                      widget: ListTile(
                        minTileHeight: 0,
                        contentPadding: EdgeInsets.all(0),
                        leading: Container(
                          padding: EdgeInsets.all(15),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: whiteColor,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.account_balance_outlined,
                            color: mainThemeColor,
                          ),
                        ),
                        title: Text(
                          bank.bankName ?? 'art_bank'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                        subtitle: Text(
                          'Checking •••• $last4',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff737373),
                          ),
                        ),
                        trailing: index == 0
                            ? MyContainer(
                                noWidth: true,
                                padding: EdgeInsets.all(10),
                                color: Color(0xffDCFCE7),
                                border: BoxBorder.all(color: Color(0xff00A63E)),
                                widget: Text(
                                  'art_primary'.tr,
                                  style: TextStyle(
                                    color: Color(0xff00A63E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => height(0.01),
                  itemCount: banks.length,
                );
              }),
              height(0.01),
              GestureDetector(
                onTap: () => Get.to(() => const AddAcount()),
                child: MyContainer(
                  border: BoxBorder.all(
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
            ],
          ),
        ),
      ),
    );
  }
}

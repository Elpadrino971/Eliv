import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/transactions_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TranssactinHistory extends StatefulWidget {
  const TranssactinHistory({super.key, this.transactions = const []});

  /// Transactions réelles (ticket/cadeau) venant de /api/artist/revenue-
  /// transactions, passées depuis RevenueScreen — plus de liste factice
  /// codée en dur ("Ticket Sales +$1,240", "Merch Drop", faux virement).
  final List<Map<String, dynamic>> transactions;

  @override
  State<TranssactinHistory> createState() => _TranssactinHistoryState();
}

class _TranssactinHistoryState extends State<TranssactinHistory> {
  String selectedText = 'All';

  List<Map<String, dynamic>> get _filtered {
    // Toutes les entrées du ledger sont des gains (crédits) pour l'instant ;
    // les retraits (débits) ne sont pas encore inclus dans ce flux.
    if (selectedText == 'Debit') return [];
    return widget.transactions;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: MyAppbar(title: 'art_transaction_history'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedText = 'All';
                    });
                  },
                  child: Container(
                    width: Get.width * 0.28,
                    padding: EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? selectedText == 'All'
                                ? goldPrimary
                                : greyColor.withValues(alpha: 0.2)
                          : selectedText == 'All'
                          ? blackColor
                          : greyColor.withValues(alpha: 0.2),

                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      textAlign: TextAlign.center,
                      'art_all'.tr,
                      style: TextStyle(
                        color: selectedText == 'All'
                            ? whiteColor
                            : Color(0xff9FA8BC),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedText = 'Credit';
                    });
                  },
                  child: Container(
                    width: Get.width * 0.28,
                    padding: EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? selectedText == 'Credit'
                                ? goldPrimary
                                : greyColor.withValues(alpha: 0.2)
                          : selectedText == 'Credit'
                          ? blackColor
                          : greyColor.withValues(alpha: 0.2),

                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/alert_icon1.png',
                          width: 15,
                          color: selectedText == 'Credit'
                              ? whiteColor
                              : Color(0xff9FA8BC),
                        ),
                        width(0.01),
                        Text(
                          'art_credit'.tr,
                          style: TextStyle(
                            color: selectedText == 'Credit'
                                ? whiteColor
                                : Color(0xff9FA8BC),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedText = 'Debit';
                    });
                  },
                  child: Container(
                    width: Get.width * 0.28,
                    padding: EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? selectedText == 'Debit'
                                ? goldPrimary
                                : greyColor.withValues(alpha: 0.2)
                          : selectedText == 'Debit'
                          ? blackColor
                          : greyColor.withValues(alpha: 0.2),

                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/alert_icon2.png',
                          width: 15,
                          color: selectedText == 'Debit'
                              ? whiteColor
                              : Color(0xff9FA8BC),
                        ),
                        width(0.01),
                        Text(
                          'art_debit'.tr,
                          style: TextStyle(
                            color: selectedText == 'Debit'
                                ? whiteColor
                                : Color(0xff9FA8BC),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'art_transactions'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ivory,
                  ),
                ),
                Text(
                  '${filtered.length} ${'art_total'.tr}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff737373),
                  ),
                ),
              ],
            ),

            height(0.02),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'art_no_transactions'.tr,
                  style: const TextStyle(color: greyColor),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => height(0.01),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final amount = (tx['amount'] as num?) ?? 0;
                    return TransactionsCard(
                      title: '${tx['title'] ?? ''}',
                      price: '+${amount.toStringAsFixed(2)} €',
                      date: '${tx['date'] ?? ''}',
                      subTitle: '${tx['title'] ?? ''}',
                      name: 'rev_concert_revenue'.tr,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

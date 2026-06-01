import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_create_event.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/transactions_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TranssactinHistory extends StatefulWidget {
  const TranssactinHistory({super.key});

  @override
  State<TranssactinHistory> createState() => _TranssactinHistoryState();
}

class _TranssactinHistoryState extends State<TranssactinHistory> {
  String selectedText = 'All';

  List<Map> transactionsList = [];
  @override
  Widget build(BuildContext context) {
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
                            : Color(0xff4A5565),
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
                              : Color(0xff4A5565),
                        ),
                        width(0.01),
                        Text(
                          'art_credit'.tr,
                          style: TextStyle(
                            color: selectedText == 'Credit'
                                ? whiteColor
                                : Color(0xff4A5565),
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
                              : Color(0xff4A5565),
                        ),
                        width(0.01),
                        Text(
                          'art_debit'.tr,
                          style: TextStyle(
                            color: selectedText == 'Debit'
                                ? whiteColor
                                : Color(0xff4A5565),
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
                  '8 ${'art_total'.tr}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff737373),
                  ),
                ),
              ],
            ),

            height(0.02),
            GestureDetector(
              onTap: () {
                Get.to(() => ArtistCreateEvent());
              },
              child: TransactionsCard(
                title: 'Ticket Sales',
                price: '+\$1,240',
                date: 'FEB 20',
                subTitle: 'Electric Dreams Festival',
                name: 'rev_concert_revenue'.tr,
              ),
            ),
            height(0.01),

            TransactionsCard(
              title: 'Merch Drop',
              price: '+\$650',
              date: 'FEB 18',
              subTitle: 'Limited Edition T-Shirts',
              name: 'Merchandise',
            ),
            height(0.01),

            TransactionsCard(
              isChange: false,
              title: 'Bank Payout',
              price: '-\$5,000',
              date: 'FEB 15',
              subTitle: 'Chase Business Account',
              name: 'Withdrawal',
            ),
          ],
        ),
      ),
    );
  }
}

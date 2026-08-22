import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/transactions_model.dart';
import 'package:flutter/material.dart';
import 'package:artist/widgets/widget.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class TopupHistory extends StatefulWidget {
  const TopupHistory({super.key});

  @override
  State<TopupHistory> createState() => _TopupHistoryState();
}

class _TopupHistoryState extends State<TopupHistory> {
  final authController = Get.find<AuthController>();
  String selectedFilter = 'ALL';
  List<Transaction> allTransactions = [];

  Future myInitMethod() async {
    await authController.getTransaction();
    allTransactions.clear();
    allTransactions.addAll(authController.transactions.value.list ?? []);
    allTransactions.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    await authController.getTransaction(key: 'price');
    allTransactions.addAll(authController.ticketsDataHistory.value.list ?? []);
    allTransactions.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  Map<String, List<Transaction>> groupTransactions(
    List<Transaction> transactions,
  ) {
    Map<String, List<Transaction>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in transactions) {
      if (tx.createdAt == null) continue;

      final txDate = DateTime(
        tx.createdAt!.year,
        tx.createdAt!.month,
        tx.createdAt!.day,
      );
      String key;
      if (txDate == today) {
        key = 'TODAY';
      } else if (txDate == yesterday) {
        key = 'YESTERDAY';
      } else {
        key = DateFormat('MMMM dd, yyyy').format(txDate).toUpperCase();
      }

      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? darkmodeColor : whiteColor,
      appBar: MyAppbar(title: 'topup_history'.tr),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: myInitMethod,
          child: SingleChildScrollView(
            padding: myPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: LinearGradient(
                      colors: [
                        mainThemeColor.withValues(alpha: 0.7),
                        mainThemeColor,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'wallet_available_balance'.tr,
                        style: TextStyle(
                          color: whiteColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      height(0.01),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Obx(
                            () => Text(
                              userModel.value.user?.points ?? '0',
                              style: const TextStyle(
                                color: whiteColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 40,
                              ),
                            ),
                          ),
                          width(0.02),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'PTS',
                              style: TextStyle(
                                color: whiteColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                height(0.03),

                // Filter Tabs
                Row(
                  children: [
                    _filterTab('ALL'),
                    width(0.02),
                    _filterTab('PURCHASES'),
                    width(0.02),
                    _filterTab('GIFT'),
                  ],
                ),
                height(0.03),

                Text(
                  'recent_history'.tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                height(0.02),

                Obx(() {
                  RxList<Transaction> transactions = <Transaction>[].obs;
                  if (selectedFilter == 'ALL') {
                    transactions.value = allTransactions;
                  } else if (selectedFilter == 'PURCHASES') {
                    transactions.clear();
                    transactions.value =
                        authController.ticketsDataHistory.value.list ?? [];
                  } else if (selectedFilter == 'GIFT') {
                    transactions.clear();
                    transactions.value =
                        authController.transactions.value.list ?? [];
                  }

                  final grouped = groupTransactions(transactions);

                  if (grouped.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text('empty_no_transactions'.tr),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: grouped.keys.length,
                    separatorBuilder: (context, index) => height(0.03),
                    itemBuilder: (context, index) {
                      final key = grouped.keys.elementAt(index);
                      final items = grouped[key] ?? [];
                      return _historySection(key, items);
                    },
                  );
                }),
                height(0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTab(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (label == 'ALL'
                    ? mainThemeColor.withValues(alpha: 0.2)
                    : const Color(0xffF2F2F2))
              : const Color(0xffF2F2F2),
          borderRadius: BorderRadius.circular(30),
          border: isSelected && label == 'ALL'
              ? Border.all(color: mainThemeColor.withValues(alpha: 0.1))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (label == 'ALL' ? mainThemeColor : blackColor)
                : greyColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _historySection(String dateTitle, List<Transaction> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateTitle,
          style: const TextStyle(
            color: greyColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        height(0.02),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => height(0.03),
          itemBuilder: (context, index) {
            final item = items[index];
            bool isPositive = item.type?.toLowerCase() == 'credit';
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? mainThemeColor.withValues(alpha: 0.05)
                        : const Color(0xffF2F2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: isPositive ? mainThemeColor : greyColor,
                    size: 24,
                  ),
                ),
                width(0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        item.createdAt != null
                            ? DateFormat(
                                'MMM dd • HH:mm',
                              ).format(item.createdAt!)
                            : 'N/A',
                        style: const TextStyle(color: greyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : '-'}${item.amount ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isPositive ? mainThemeColor : blackColor,
                      ),
                    ),
                    const Text(
                      'PTS',
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

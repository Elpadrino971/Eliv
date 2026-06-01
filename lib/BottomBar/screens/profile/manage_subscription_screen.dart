import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  State<ManageSubscriptionScreen> createState() =>
      _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final subscriptionController = Get.put(SubscriptionController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await subscriptionController.getSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;
    final Color accentColor = isDark ? goldPrimary : mainThemeColor;

    return Scaffold(
      backgroundColor: isDark ? darkmodeColor : const Color(0xffF8F8F8),
      appBar: MyAppbar(title: 'prof_manage_sub'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            // ── Tab Bar ────────────────────────────────────────────────
            MyTabBar(
              tabController: _tabController,
              tabOne: 'sub_current'.tr,
              tabTwo: 'History',
            ),

            height(0.015),

            // ── Tab Views ──────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CurrentSubscriptionTab(
                    accentColor: accentColor,
                    isDark: isDark,
                  ),
                  _HistoryTab(accentColor: accentColor, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Current Subscription Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentSubscriptionTab extends StatelessWidget {
  final Color accentColor;
  final bool isDark;

  const _CurrentSubscriptionTab({
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = userModel.value.user?.userSubscription;

      List<UserSubscription> activeOnly = [];
      if (data == null) {
        return Center(child: CircularProgressIndicator(color: mainThemeColor));
      }

      if (data.isNotEmpty) {
        activeOnly = data.where((e) => e.status == 'active').toList();
      }

      if (activeOnly.isEmpty) {
        return Center(
          child: MyDefaultText(
            text: 'empty_no_active_sub'.tr,
            color: ivory,
          ),
        );
      }

      return SingleChildScrollView(
        child: ListView.builder(
          padding: EdgeInsets.all(0),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: activeOnly.length,
          itemBuilder: (context, index) {
            return SubscriptionCard(
              subscription: activeOnly[index].subscription!,
              showButton: false,
            );
          },
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History Tab
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final Color accentColor;
  final bool isDark;

  const _HistoryTab({required this.accentColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = userModel.value.user?.userSubscription;

      List<UserSubscription> historySubs = [];
      if (data == null) {
        return Center(child: CircularProgressIndicator(color: mainThemeColor));
      }

      if (data.isNotEmpty) {
        historySubs = data.where((e) => e.status != 'active').toList();
      }
      if (historySubs.isEmpty) {
        return Center(
          child: MyDefaultText(
            text: 'empty_no_sub_history'.tr,
            color: ivory,
          ),
        );
      }

      return SingleChildScrollView(
        child: ListView.builder(
          padding: EdgeInsets.all(0),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: historySubs.length,
          itemBuilder: (context, index) {
            return SubscriptionCard(
              purchasedDate: DateFormat(
                'dd MMMM yyyy',
              ).format(historySubs[index].createdAt!),
              subscription: historySubs[index].subscription!,
              showButton: false, // No purchase button in history
            );
          },
        ),
      );
    });
  }
}

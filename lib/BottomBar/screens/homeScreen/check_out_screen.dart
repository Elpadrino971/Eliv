import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/BottomBar/screens/profile/user_wallet.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CheckOutScreen extends StatefulWidget {
  const CheckOutScreen({super.key, required this.event, this.discountPercent = 0});
  final Event event;

  /// Remise (%) appliquee via une promo live (ex: 20 = -20%). 0 = aucune.
  final int discountPercent;

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  List<Map> get paymentList => [
    {'name': 'home_payment_card'.tr, 'image': 'assets/card_icon.png'},
    {'name': 'home_payment_pay'.tr, 'image': 'assets/pay_icon.png'},
  ];
  String selectedPayment = '';

  double get _ticketPrice {
    final base = double.tryParse(widget.event.ticketPrice ?? '0') ?? 0;
    return widget.discountPercent > 0
        ? base * (1 - widget.discountPercent / 100)
        : base;
  }

  // Prix en POINTS (monnaie interne) : 1 € = 100 points.
  int get _ticketPoints => (_ticketPrice * 100).round();

  List<Map> get textList => [
    {
      'title': 'home_standard_pass'.tr,
      'subTitle': widget.discountPercent > 0
          ? 'Promo -${widget.discountPercent}% appliquée'
          : 'home_4k_uhd_access'.tr,
      'price': '$_ticketPoints pts',
    },
  ];
  String selectedAccess = '';
  @override
  void initState() {
    selectedPayment = paymentList[0]['name'];
    super.initState();
  }

  final cardholderController = TextEditingController();
  final numberController = TextEditingController();
  final dateController = TextEditingController();
  final cvvController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? midnightPrimary : scaffoldBackgroundColor,
      appBar: MyAppbar(title: 'home_checkout'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'home_select_access_tier'.tr.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  color: textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 2.5,
                ),
              ),
              height(0.02),
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(0),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAccess = textList[index]['title'];
                      });
                    },
                    child: Container(
                      padding: myPadding,
                      width: Get.width,
                      decoration: BoxDecoration(
                        color: Get.isDarkMode
                            ? selectedAccess == textList[index]['title']
                                  ? goldPrimary
                                  : darkmodeColor
                            : selectedAccess == textList[index]['title']
                            ? mainThemeColor.withValues(alpha: 0.2)
                            : whiteColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Get.isDarkMode
                              ? selectedAccess == textList[index]['title']
                                    ? goldPrimary
                                    : borderGreyColor
                              : selectedAccess == textList[index]['title']
                              ? mainThemeColor
                              : borderGreyColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                textList[index]['title'],
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : Color(0xff262626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),

                              Text(
                                textList[index]['subTitle'],
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : Color(0xff262626),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          Spacer(),

                          Text(
                            textList[index]['price'],
                            style: TextStyle(
                              color: Get.isDarkMode
                                  ? whiteColor
                                  : Color(0xff262626),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return height(0.02);
                },
                itemCount: textList.length,
              ),

              height(0.01),

              Text(
                'home_payment_method'.tr.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  color: textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 2.5,
                ),
              ),
              height(0.02),

              // Paiement EN POINTS (conforme Apple : aucun formulaire carte
              // in-app pour du contenu numérique). L'argent réel entre via la
              // recharge du portefeuille (achat In-App RevenueCat).
              Container(
                padding: myPadding,
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? darkmodeColor : whiteColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderGreyColor, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: goldPrimary,
                      size: 28,
                    ),
                    width(0.03),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'wallet_available_balance'.tr,
                          style: const TextStyle(
                            color: Color(0xffA1A1A1),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Obx(
                          () => Text(
                            '${userModel.value.user?.points ?? '0'} pts',
                            style: TextStyle(
                              color: Get.isDarkMode ? whiteColor : blackColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await Get.to(() => const UserWallet());
                        setState(() {}); // rafraîchit le solde au retour
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: goldPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Recharger',
                          style: TextStyle(
                            color: midnightPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              height(0.02),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (Champs carte retirés : paiement en points uniquement,
                  // conforme aux règles Apple pour le contenu numérique.)
                  height(0.01),
                  Row(
                    children: [
                      Text(
                        'home_total_charged'.tr,
                        style: TextStyle(
                          color: Color(0xffA1A1A1),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),

                      Text(
                        selectedAccess.isEmpty
                            ? textList[0]['price']
                            : textList.firstWhere(
                                (t) => t['title'] == selectedAccess,
                              )['price'],
                        style: TextStyle(
                          color: ivory,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  height(0.01),
                  MyButton(
                    label: 'home_authorize_payment'.tr,
                    labelColor: midnightPrimary,
                    onTap: () async {
                      final eventController = Get.find<EventController>();

                      // 1. Get selected price and parse numeric value
                      final selectedTier = selectedAccess.isEmpty
                          ? textList[0]
                          : textList.firstWhere(
                              (t) => t['title'] == selectedAccess,
                            );

                      final String priceStr = selectedTier['price']
                          .toString()
                          .replaceAll(RegExp(r'[^0-9.]'), '');
                      final double price = double.tryParse(priceStr) ?? 0.0;

                      // 2. Check points
                      final double userPoints =
                          double.tryParse(
                            userModel.value.user?.points ?? '0',
                          ) ??
                          0.0;

                      if (userPoints < price) {
                        myAlertDialog(
                          title: 'home_insufficient_points'.tr,
                          content: 'home_insufficient_points_msg'.tr,
                          onTap: () => Get.back(),
                        );
                        return;
                      }

                      // 3. Confirmation and Buy
                      myAlertDialog(
                        title: 'home_confirm_purchase'.tr,
                        content: 'home_confirm_purchase_msg'.trParams({
                          'name': '${widget.event.name}',
                        }),
                        onTap: () async {
                          Get.back(); // Close alert
                          myLoadingDialog();
                          await eventController.buyTicket(
                            eventId: widget.event.id.toString(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

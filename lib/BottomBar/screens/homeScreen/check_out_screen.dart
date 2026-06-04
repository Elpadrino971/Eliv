import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
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

  List<Map> get textList => [
    {
      'title': 'home_standard_pass'.tr,
      'subTitle': widget.discountPercent > 0
          ? 'Promo -${widget.discountPercent}% appliquée'
          : 'home_4k_uhd_access'.tr,
      'price': '\$${_ticketPrice.toStringAsFixed(2)}',
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

              GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),

                itemCount: 2,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPayment = paymentList[index]['name'];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: Get.isDarkMode
                              ? paymentList[index]['name'] == selectedPayment
                                    ? AssetImage('assets/container4.png')
                                    : AssetImage('assets/container5.png')
                              : paymentList[index]['name'] == selectedPayment
                              ? AssetImage('assets/container1.png')
                              : AssetImage('assets/container2.png'),
                          fit: BoxFit.cover,
                        ),
                        color: Get.isDarkMode
                            ? selectedPayment == paymentList[index]['name']
                                  ? goldPrimary
                                  : darkmodeColor
                            : selectedPayment == paymentList[index]['name']
                            ? mainThemeColor.withValues(alpha: 0.2)
                            : whiteColor,
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            paymentList[index]['image'],
                            width: 20,
                            height: 20,
                            color: paymentList[index]['name'] == selectedPayment
                                ? whiteColor
                                : Color(0xffA1A1A1),
                          ),
                          Text(
                            paymentList[index]['name'],
                            style: TextStyle(
                              color:
                                  paymentList[index]['name'] == selectedPayment
                                  ? whiteColor
                                  : Color(0xffA1A1A1),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              height(0.02),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_cardholder_name'.tr,
                    style: TextStyle(
                      color: Color(0xffA1A1A1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  MyTextField(
                    hintText: 'Alex Harrison',
                    controller: cardholderController,
                  ),

                  height(0.01),
                  Text(
                    'home_card_number'.tr,
                    style: TextStyle(
                      color: Color(0xffA1A1A1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  MyTextField(
                    hintText: '•••• •••• •••• 4242',
                    controller: numberController,
                    keyboardType: TextInputType.number,
                  ),

                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          height(0.01),
                          Text(
                            'home_expiry_date'.tr,
                            style: TextStyle(
                              color: Color(0xffA1A1A1),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            width: Get.width * 0.44,
                            child: MyTextField(
                              hintText: 'MM / YY',
                              controller: dateController,
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                        ],
                      ),

                      Spacer(),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          height(0.01),
                          Text(
                            'home_cvv'.tr,
                            style: TextStyle(
                              color: Color(0xffA1A1A1),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            width: Get.width * 0.44,
                            child: MyTextField(
                              hintText: '•••',
                              controller: cvvController,
                              keyboardType: TextInputType.text,
                              isObscure: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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

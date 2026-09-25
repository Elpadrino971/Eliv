import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Controllers/subscription_controller.dart';
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
    return double.tryParse(widget.event.ticketPrice ?? '0') ?? 0;
  }

  // ID du produit IAP correspondant au palier de prix du billet.
  // Ex : 49.99 € -> "ticket_49". (Les promos ne s'appliquent pas à l'IAP —
  // Apple ne permet pas de remise arbitraire sur un consommable.)
  String get _ticketProductId => 'ticket_${_ticketPrice.floor()}';

  List<Map> get textList => [
    {
      'title': 'home_standard_pass'.tr,
      'subTitle': 'home_4k_uhd_access'.tr,
      'price': '${_ticketPrice.toStringAsFixed(2)} €',
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

              // Paiement du billet par ACHAT IN-APP (App Store), conforme Apple.
              Row(
                children: [
                  Icon(Icons.lock_rounded, color: goldPrimary, size: 18),
                  width(0.02),
                  Expanded(
                    child: Text(
                      'checkout_secure_note'.tr,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                    label: 'checkout_pay'.trParams({
                      'price': _ticketPrice.toStringAsFixed(2),
                    }),
                    labelColor: midnightPrimary,
                    onTap: () async {
                      final eventController = Get.find<EventController>();
                      myAlertDialog(
                        title: 'home_confirm_purchase'.tr,
                        content: 'home_confirm_purchase_msg'.trParams({
                          'name': '${widget.event.name}',
                        }),
                        onTap: () async {
                          Get.back(); // ferme la confirmation
                          myLoadingDialog();
                          // Concert GRATUIT (prix 0) : aucun achat IAP (il n'y a
                          // pas de produit `ticket_0`). On enregistre l'accès
                          // directement — le backend accorde un billet gratuit
                          // quand le prix est 0 (pas de vérif paiement).
                          if (_ticketPrice <= 0) {
                            await eventController.buyTicket(
                              eventId: widget.event.id.toString(),
                            );
                            return; // buyTicket gère son dialog succès/erreur
                          }
                          // 1. Achat IAP direct du billet (palier de prix).
                          final sub = Get.isRegistered<SubscriptionController>()
                              ? Get.find<SubscriptionController>()
                              : Get.put(SubscriptionController());
                          final paid =
                              await sub.purchaseByProductId(_ticketProductId);
                          if (!paid) {
                            Get.back(); // ferme le loader
                            // Fermer la feuille de paiement est un choix, pas
                            // une panne : on ne crie pas à l'échec pour ça.
                            if (sub.lastPurchaseCancelled) {
                              myWarningDialog(
                                title: 'common_info'.tr,
                                subtitle: 'pay_cancelled'.tr,
                              );
                            } else {
                              myWarningDialog(
                                subtitle: 'checkout_payment_incomplete'
                                    .trParams({'product': _ticketProductId}),
                              );
                            }
                            return;
                          }
                          // 2. Paiement validé -> enregistre l'accès au concert.
                          await eventController.buyTicket(
                            eventId: widget.event.id.toString(),
                          );
                          // buyTicket gère son propre dialog succès/erreur.
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

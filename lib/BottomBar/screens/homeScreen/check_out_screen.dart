import 'dart:io';

import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/live_router.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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

  // Prix affiché par le STORE (ex. "4,99 €", déjà localisé avec sa devise),
  // chargé au démarrage. Null tant qu'il n'est pas connu -> repli sur le
  // prix € du backend. C'est le store qui débite : c'est lui qu'on affiche.
  String? _storePrice;
  // Vrai quand la requête produits a abouti (succès ou échec).
  bool _productsChecked = false;
  // Vrai quand le store ne connaît pas le produit ticket_XX.
  bool _productMissing = false;

  // « Gratuit » pour un concert à 0 € (jamais « 0.00 € »).
  String get _fallbackPriceLabel => priceLabel(widget.event.ticketPrice);
  String get _priceLabel => _storePrice ?? _fallbackPriceLabel;

  /// Android : aucun produit billet n'existe encore sur Google Play -> on
  /// remplace le bouton de paiement par un message neutre (règles Play :
  /// pas de lien ni de mention d'un paiement externe).
  bool get _androidUnavailable =>
      Platform.isAndroid &&
      _ticketPrice > 0 &&
      _productsChecked &&
      _productMissing;

  /// Un achat store a été lancé pour CE concert sans que le billet ait pu
  /// être attaché (voir [EventController.pendingTicketKey]).
  bool get _hasPendingTicket =>
      EventController.pendingTicketEventId() == widget.event.id;

  List<Map> get textList => [
    {
      'title': 'home_standard_pass'.tr,
      'subTitle': 'home_4k_uhd_access'.tr,
      'price': _priceLabel,
    },
  ];
  String selectedAccess = '';

  @override
  void initState() {
    selectedPayment = paymentList[0]['name'];
    super.initState();
    _loadStoreProduct();
  }

  Future<void> _loadStoreProduct() async {
    if (_ticketPrice <= 0) return;
    try {
      final products = await Purchases.getProducts(
        [_ticketProductId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (!mounted) return;
      setState(() {
        _productsChecked = true;
        _productMissing = products.isEmpty;
        _storePrice = products.isNotEmpty ? products.first.priceString : null;
      });
    } catch (e) {
      myPrint('checkout: getProducts($_ticketProductId) -> $e');
      if (!mounted) return;
      setState(() {
        _productsChecked = true;
        // Sur Android, pas de billetterie Play pour l'instant : on affiche le
        // message neutre plutôt qu'un bouton qui échouera. Sur iOS, on garde
        // le bouton (erreur passagère probable) avec le prix de repli.
        _productMissing = Platform.isAndroid;
      });
    }
  }

  final cardholderController = TextEditingController();
  final numberController = TextEditingController();
  final dateController = TextEditingController();
  final cvvController = TextEditingController();

  /// Tunnel d'achat. Un loader est ouvert pendant toute la séquence et
  /// TOUJOURS refermé par [_finishGrant] ou dans les branches d'échec.
  Future<void> _startPurchase() async {
    final eventController = Get.find<EventController>();
    final eventId = widget.event.id.toString();
    myLoadingDialog();
    // Concert GRATUIT (prix 0) : aucun achat IAP (il n'y a pas de produit
    // `ticket_0`). On enregistre l'accès directement — le backend accorde un
    // billet gratuit quand le prix est 0 (pas de vérif paiement).
    if (_ticketPrice <= 0) {
      final updated = await eventController.buyTicketWithRetry(
        eventId,
        retry: false,
      );
      _finishGrant(updated, afterStorePurchase: false);
      return;
    }
    // 1. Achat IAP direct du billet (palier de prix). Juste avant la feuille
    //    de paiement, on mémorise l'id du concert : si l'app est coupée ou si
    //    /buy-ticket échoue après le débit, la fiche proposera « J'ai déjà
    //    payé · récupérer mon billet ».
    final sub = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : Get.put(SubscriptionController());
    final paid = await sub.purchaseByProductId(
      _ticketProductId,
      onBeforePurchase: () =>
          box.write(EventController.pendingTicketKey, widget.event.id),
    );
    if (!paid) {
      Get.back(); // ferme le loader
      if (sub.lastPurchaseCancelled) {
        // Fermer la feuille de paiement est un choix, pas une panne : rien
        // n'a été débité, on ne crie pas à l'échec et on oublie l'attente.
        box.remove(EventController.pendingTicketKey);
        myWarningDialog(
          title: 'common_info'.tr,
          subtitle: 'pay_cancelled'.tr,
        );
      } else {
        // Échec non choisi (réseau, store…) : le débit a PEUT-ÊTRE eu lieu,
        // on garde l'attente -> le bouton de récupération apparaît.
        myWarningDialog(
          subtitle: 'checkout_payment_incomplete'
              .trParams({'product': _ticketProductId}),
        );
      }
      if (mounted) setState(() {});
      return;
    }
    // 2. Paiement validé par le store -> on attache le billet, avec jusqu'à
    //    3 nouveaux essais (2 s / 5 s / 10 s) : le reçu peut mettre quelques
    //    secondes à être visible côté RevenueCat (402), ou le réseau peut
    //    flancher juste après le débit.
    final updated = await eventController.buyTicketWithRetry(
      eventId,
      retry: true,
    );
    _finishGrant(updated, afterStorePurchase: true);
  }

  /// « J'ai déjà payé » : ré-attache le billet SANS repasser par le store.
  Future<void> _recoverTicket() async {
    final eventController = Get.find<EventController>();
    myLoadingDialog();
    final updated = await eventController.buyTicketWithRetry(
      widget.event.id.toString(),
      retry: true,
    );
    _finishGrant(updated, afterStorePurchase: true);
  }

  /// Ferme le loader puis : erreur -> message ; succès -> si le concert est
  /// en direct, on entre DIRECTEMENT dans le live (la fiche reçoit quand
  /// même le billet en résultat), sinon dialogue « Billet réservé ».
  void _finishGrant(Event? updated, {required bool afterStorePurchase}) {
    final eventController = Get.find<EventController>();
    Get.back(); // ferme le loader
    if (updated == null) {
      if (afterStorePurchase) {
        myWarningDialog(subtitle: 'ticket_attach_failed'.tr);
      } else {
        final err = eventController.lastBuyTicketError;
        if (err != null) {
          parseError(err, doBack: false);
        } else {
          myWarningDialog(subtitle: 'common_error'.tr);
        }
      }
      if (mounted) setState(() {});
      return;
    }
    if (updated.status == 'live') {
      Get.back(result: updated); // ferme le checkout -> la fiche a le billet
      joinLive(updated);
      return;
    }
    mySuccessDialog(
      subtitle: 'msg_ticket_booked'.tr,
      ontap: () {
        Get.back(); // ferme le dialogue
        Get.back(result: updated); // ferme le checkout -> la fiche a le billet
      },
    );
  }

  Widget _androidUnavailableNote() {
    return Container(
      width: Get.width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.isDarkMode ? darkmodeColor : whiteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGreyColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: goldPrimary, size: 20),
          width(0.03),
          Expanded(
            child: Text(
              'checkout_android_unavailable'.tr,
              style: TextStyle(
                color: Get.isDarkMode ? whiteColor : const Color(0xff262626),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(0),
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
                                      : const Color(0xff262626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),

                              Text(
                                textList[index]['subTitle'],
                                style: TextStyle(
                                  color: Get.isDarkMode
                                      ? whiteColor
                                      : const Color(0xff262626),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          Text(
                            textList[index]['price'],
                            style: TextStyle(
                              color: Get.isDarkMode
                                  ? whiteColor
                                  : const Color(0xff262626),
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

              // Paiement du billet par ACHAT IN-APP (App Store / Google Play).
              // Concert gratuit : aucun paiement, donc pas de mention de store.
              if (_ticketPrice > 0)
              Row(
                children: [
                  const Icon(Icons.lock_rounded, color: goldPrimary, size: 18),
                  width(0.02),
                  Expanded(
                    child: Text(
                      Platform.isAndroid
                          ? 'checkout_secure_note_android'.tr
                          : 'checkout_secure_note'.tr,
                      style: const TextStyle(
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
                  // (Champs carte retirés : paiement in-app uniquement,
                  // conforme aux règles Apple / Google pour le contenu numérique.)
                  height(0.01),
                  Row(
                    children: [
                      Text(
                        'home_total_charged'.tr,
                        style: const TextStyle(
                          color: Color(0xffA1A1A1),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),

                      Text(
                        _priceLabel,
                        style: const TextStyle(
                          color: ivory,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  height(0.01),
                  if (_androidUnavailable)
                    _androidUnavailableNote()
                  else
                    MyButton(
                      label: _ticketPrice <= 0
                          ? 'checkout_reserve_free'.tr
                          : _storePrice != null
                          ? 'checkout_pay_amount'.trParams({
                              'price': _storePrice!,
                            })
                          : 'checkout_pay'.trParams({
                              'price': _ticketPrice.toStringAsFixed(2),
                            }),
                      labelColor: midnightPrimary,
                      onTap: () {
                        myAlertDialog(
                          title: 'home_confirm_purchase'.tr,
                          content: 'home_confirm_purchase_msg'.trParams({
                            'name': '${widget.event.name}',
                          }),
                          onTap: () {
                            Get.back(); // ferme la confirmation
                            _startPurchase();
                          },
                        );
                      },
                    ),
                  // Un paiement store a été lancé pour ce concert sans billet
                  // attaché : on propose de le récupérer sans repayer.
                  if (_hasPendingTicket && _ticketPrice > 0) ...[
                    height(0.015),
                    MyButton(
                      label: 'ticket_recover_button'.tr,
                      buttonColor: Colors.transparent,
                      borderColor: goldPrimary,
                      labelColor: goldPrimary,
                      onTap: _recoverTicket,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

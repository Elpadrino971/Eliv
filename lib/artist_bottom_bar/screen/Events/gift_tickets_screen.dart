import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// ────────────────────────────────────────────────────────────────────────
/// PLACES OFFERTES — côté artiste. L'artiste saisit l'e-mail d'un invité :
///   POST /api/events/:id/gift-ticket  { email }
/// puis la liste est rechargée :
///   GET  /api/events/:id/gift-tickets -> { gifted_count, max, items[] }
/// Un invité sans compte est « en attente » : il reçoit sa place à la
/// création / vérification de son compte.
/// ────────────────────────────────────────────────────────────────────────

/// Une place offerte telle que renvoyée par l'API.
class GiftedTicket {
  const GiftedTicket({required this.email, required this.state, this.createdAt});

  final String email;
  final String state; // 'granted' | 'pending'
  final DateTime? createdAt;

  bool get isGranted => state == 'granted';

  factory GiftedTicket.fromJson(Map json) {
    final rawDate = json['created_at'];
    return GiftedTicket(
      email: (json['email'] ?? '').toString(),
      state: (json['state'] ?? 'pending').toString(),
      createdAt: rawDate is String && rawDate.isNotEmpty
          ? DateTime.tryParse(rawDate)
          : null,
    );
  }
}

class GiftTicketsScreen extends StatefulWidget {
  const GiftTicketsScreen({super.key, required this.event});
  final Event event;

  @override
  State<GiftTicketsScreen> createState() => _GiftTicketsScreenState();
}

class _GiftTicketsScreenState extends State<GiftTicketsScreen> {
  // Deux ApiResponse : le POST et le GET ne s'écrasent pas l'URL/le type.
  final _listResponse = ApiResponse();
  final _sendResponse = ApiResponse();
  final _emailController = TextEditingController();

  bool _loadingList = true;
  bool _sending = false;
  int _giftedCount = 0;
  int _max = 0;
  List<GiftedTicket> _items = [];

  String get _eventId => widget.event.id.toString();

  bool get _quotaReached => _max > 0 && _giftedCount >= _max;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  Future<void> _loadList() async {
    _listResponse.typeSetter = 'get';
    _listResponse.urlSetter = APIs.giftTicketsAPI(_eventId);
    final String value = await _listResponse.hitAPI();
    if (!mounted) return;
    if (value.split(' ').first != 'error') {
      try {
        final decoded = jsonDecode(value);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is Map) {
          // Typage explicite (pas d'appel générique sur `dynamic`) : la
          // liste finale est bien une List<GiftedTicket>.
          final rawItems = data['items'];
          final List rawList = rawItems is List ? rawItems : const [];
          final List<GiftedTicket> items = rawList
              .whereType<Map>()
              .map((Map x) => GiftedTicket.fromJson(x))
              .toList();
          setState(() {
            _giftedCount = _asInt(data['gifted_count']);
            _max = _asInt(data['max']);
            _items = items;
          });
        }
      } catch (e) {
        myPrint('gift-tickets: $e');
      }
    } else {
      parseError(value);
    }
    if (mounted) setState(() => _loadingList = false);
  }

  Future<void> _send() async {
    if (_sending) return;
    final email = _emailController.text.trim();
    if (!GetUtils.isEmail(email)) {
      myWarningDialog(subtitle: 'gift_invalid_email'.tr);
      return;
    }
    if (_quotaReached) {
      myWarningDialog(subtitle: 'gift_quota_reached'.tr);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    _sendResponse.typeSetter = 'post';
    _sendResponse.urlSetter = APIs.giftTicketAPI(_eventId);
    _sendResponse.bodySetter = {'email': email};
    final String value = await _sendResponse.hitAPI();
    if (!mounted) return;
    setState(() => _sending = false);
    if (value.split(' ').first != 'error') {
      String sentEmail = email;
      String state = 'granted';
      try {
        final decoded = jsonDecode(value);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is Map) {
          sentEmail = (data['email'] ?? email).toString();
          state = (data['state'] ?? 'granted').toString();
          _giftedCount = _asInt(data['gifted_count']);
          _max = _asInt(data['max']);
        }
      } catch (e) {
        myPrint('gift-ticket: $e');
      }
      _emailController.clear();
      final successLine = 'gift_success'.trParams({'email': sentEmail});
      final pendingNote = 'gift_pending_note'.tr;
      final message =
          state == 'pending' ? '$successLine\n$pendingNote' : successLine;
      Get.snackbar(
        'gift_title'.tr,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: cardDeep,
        colorText: ivory,
        margin: const EdgeInsets.all(14),
        borderRadius: 14,
        duration: Duration(seconds: state == 'pending' ? 6 : 4),
      );
      await _loadList();
    } else {
      // 403 (pas propriétaire), 422 (e-mail invalide), 409 (déjà une
      // place), 429 (quota) : le serveur renvoie `message`, affiché tel quel.
      parseError(value);
    }
  }

  Widget _header() {
    return MyContainer(
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/gift_icon.png',
                width: 26,
                height: 26,
                color: goldPrimary,
              ),
              width(0.03),
              Expanded(
                child: Text(
                  widget.event.name ?? 'N/A',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    color: Get.isDarkMode ? ivory : blackColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          height(0.01),
          Text(
            'gift_count'.trParams({'n': '$_giftedCount', 'max': '$_max'}),
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              color: goldPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    final disabled = _sending || _quotaReached;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyTextField(
          hintText: 'gift_email_hint'.tr,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          leading: const Icon(
            Icons.alternate_email_rounded,
            color: goldSecondary,
            size: 20,
          ),
          onSubmit: (_) => _send(),
        ),
        height(0.005),
        Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: MyButton(
            label: _sending ? 'common_loading'.tr : 'gift_send'.tr,
            onTap: () {
              if (!disabled) _send();
            },
            image: 'assets/gift_icon.png',
            imageHeight: 16,
            imageWidth: 16,
            imageColor: midnightPrimary,
          ),
        ),
        if (_quotaReached) ...[
          height(0.01),
          Text(
            'gift_quota_reached'.tr,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _stateChip(GiftedTicket item) {
    final granted = item.isGranted;
    final Color color = granted ? const Color(0xff00A63E) : goldPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        granted ? 'gift_state_granted'.tr : 'gift_state_pending'.tr,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _item(GiftedTicket item) {
    final created = item.createdAt;
    final dateLabel = created == null
        ? ''
        : '${AppDate.fullDate(created)} · ${AppDate.time(created)}';
    return MyContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      widget: Row(
        children: [
          Icon(
            item.isGranted
                ? Icons.confirmation_number_rounded
                : Icons.hourglass_top_rounded,
            color: item.isGranted ? goldPrimary : textMuted,
            size: 22,
          ),
          width(0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    color: Get.isDarkMode ? ivory : blackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (dateLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          width(0.02),
          _stateChip(item),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loadingList) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: goldPrimary)),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'gift_empty'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: textMuted,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _items.length,
      separatorBuilder: (context, index) => height(0.01),
      itemBuilder: (context, index) => _item(_items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'gift_title'.tr),
      body: RefreshIndicator(
        color: goldPrimary,
        onRefresh: _loadList,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              height(0.02),
              _form(),
              height(0.025),
              Text(
                'gift_title'.tr,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  color: Get.isDarkMode ? ivory : blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              height(0.01),
              _list(),
              height(0.08),
            ],
          ),
        ),
      ),
    );
  }
}

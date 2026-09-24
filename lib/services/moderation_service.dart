import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Signalement et blocage d'un compte.
///
/// Exigence App Store 1.2 : une application qui publie du contenu d'autres
/// utilisateurs doit permettre de signaler un contenu ET de bloquer un compte
/// abusif. Le blocage est unilatéral et réversible : le contenu du compte
/// bloqué disparaît du feed et du chat des lives de celui qui l'a bloqué.
class ModerationService {
  static Future<bool> _post(String url, Map<String, dynamic> body) async {
    final r = ApiResponse()
      ..typeSetter = 'post'
      ..urlSetter = url
      ..bodySetter = body.map((k, v) => MapEntry(k, '$v'));
    try {
      final value = await r.hitAPI();
      return value.split(' ').first != 'error';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> blockUser(int userId) => _post(APIs.blockUserAPI, {'user_id': userId});
  static Future<bool> unblockUser(int userId) => _post(APIs.unblockUserAPI, {'user_id': userId});

  static Future<bool> reportUser(int userId, String reason, {String? details}) =>
      _post(APIs.reportEventAPI, {
        'target_type': 'user',
        'target_id': userId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      });

  static Future<List> blockedUsers() async {
    final r = ApiResponse()
      ..typeSetter = 'get'
      ..urlSetter = APIs.blockedUsersAPI;
    try {
      final value = await r.hitAPI();
      if (value.split(' ').first == 'error') return [];
      final data = jsonDecode(value);
      return (data is Map && data['data'] is List) ? data['data'] as List : [];
    } catch (_) {
      return [];
    }
  }

  /// Feuille d'actions : signaler ou bloquer un compte.
  static void showActions(BuildContext context, {required int userId, required String name}) {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          decoration: const BoxDecoration(
            color: midnightSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                name,
                style: const TextStyle(color: ivory, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _tile(
                icon: Icons.flag_outlined,
                label: 'mod_report'.tr,
                onTap: () {
                  Get.back();
                  _askReason(userId, name);
                },
              ),
              _tile(
                icon: Icons.block_rounded,
                label: 'mod_block'.tr,
                danger: true,
                onTap: () {
                  Get.back();
                  _confirmBlock(userId, name);
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) =>
      ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: danger ? const Color(0xffE2584A) : goldPrimary),
        title: Text(
          label,
          style: TextStyle(
            color: danger ? const Color(0xffE2584A) : ivory,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static void _askReason(int userId, String name) {
    const reasons = <String, String>{
      'spam': 'mod_reason_spam',
      'harassment': 'mod_reason_harassment',
      'hate': 'mod_reason_hate',
      'sexual': 'mod_reason_sexual',
      'copyright': 'mod_reason_copyright',
      'other': 'mod_reason_other',
    };
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          decoration: const BoxDecoration(
            color: midnightSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'mod_report_title'.tr,
                style: const TextStyle(color: ivory, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...reasons.entries.map(
                (e) => _tile(
                  icon: Icons.chevron_right_rounded,
                  label: e.value.tr,
                  onTap: () async {
                    Get.back();
                    await reportUser(userId, e.key);
                    mySuccessDialog(
                      subtitle: 'mod_report_sent'.tr,
                      ontap: () => Get.back(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static void _confirmBlock(int userId, String name) {
    myWarningDialog(
      title: 'mod_block'.tr,
      subtitle: 'mod_block_confirm'.trParams({'name': name}),
      btnTitle: 'mod_block'.tr,
      secondBtnTitle: 'common_cancel'.tr,
      secondOnTap: () => Get.back(),
      ontap: () async {
        Get.back();
        final ok = await blockUser(userId);
        mySuccessDialog(
          subtitle: ok ? 'mod_block_done'.tr : 'common_error'.tr,
          ontap: () => Get.back(),
        );
      },
    );
  }
}

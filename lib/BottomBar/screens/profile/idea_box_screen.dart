import 'package:artist/Global/api.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/services/api_services.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Boîte à idées — les utilisateurs/artistes proposent des améliorations.
/// Envoie l'idée au backend (POST /api/ideas), visible ensuite dans l'admin.
class IdeaBoxScreen extends StatefulWidget {
  const IdeaBoxScreen({super.key});

  @override
  State<IdeaBoxScreen> createState() => _IdeaBoxScreenState();
}

class _IdeaBoxScreenState extends State<IdeaBoxScreen> {
  final _message = TextEditingController();
  final _categories = ['Général', 'Fonctionnalité', 'Lives', 'Cadeaux', 'Design', 'Bug'];
  String _category = 'Général';
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty) {
      myWarningDialog(subtitle: 'Écris ton idée avant d\'envoyer.');
      return;
    }
    setState(() => _sending = true);
    final response = ApiResponse();
    response.typeSetter = 'post';
    response.urlSetter = APIs.submitIdeaAPI;
    response.bodySetter = {
      'category': _category,
      'message': _message.text.trim(),
      'user_id': '${userModel.value.user?.id ?? ''}',
    };
    await response.hitAPI().then((value) {
      setState(() => _sending = false);
      if (value.split(' ').first != 'error') {
        _message.clear();
        mySuccessDialog(
          subtitle: 'Merci ! Ton idée a bien été envoyée. 💡',
          ontap: () {
            Get.back();
            Get.back();
          },
        );
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Get.isDarkMode;
    final textColor = dark ? whiteColor : blackColor;
    return Scaffold(
      appBar: MyAppbar(title: 'Boîte à idées'),
      body: SingleChildScrollView(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: goldPrimary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aide-nous à améliorer VYBZZZ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            height(0.005),
            Text(
              'Une idée, une suggestion, un truc qui te manque ? Dis-le nous — on lit tout.',
              style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
            ),
            height(0.025),

            Text('Catégorie', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            height(0.008),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = c == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? goldPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? goldPrimary : goldSecondary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        color: selected ? midnightPrimary : textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            height(0.025),

            Text('Ton idée', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            height(0.008),
            TextField(
              controller: _message,
              maxLines: 6,
              maxLength: 600,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Décris ton idée…',
                hintStyle: TextStyle(color: textMuted),
                filled: true,
                fillColor: dark ? cardDeep : boxColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldSecondary.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldSecondary.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: goldPrimary),
                ),
              ),
            ),
            height(0.02),

            MyButton(
              label: _sending ? 'Envoi…' : 'Envoyer mon idée',
              onTap: () { if (!_sending) _submit(); },
              labelColor: midnightPrimary,
            ),
            height(0.05),
          ],
        ),
      ),
    );
  }
}

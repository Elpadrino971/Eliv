import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/locale_service.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selected = LocaleService.currentCode;

  @override
  Widget build(BuildContext context) {
    final languages = LocaleService.supported;
    return Scaffold(
      appBar: MyAppbar(title: 'language'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.01),
            Text(
              'choose_language'.tr,
              style: TextStyle(
                color: greyColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            height(0.02),
            // Liste scrollable (12 langues > hauteur ecran).
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cardDeep,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: greyColor.withValues(alpha: 0.2)),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: languages.length,
                  separatorBuilder: (_, __) => Divider(
                    color: greyColor.withValues(alpha: 0.2),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = lang.code == _selected;
                    return InkWell(
                      onTap: () async {
                        await LocaleService.setLocale(lang.code);
                        setState(() => _selected = lang.code);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            _codeBadge(lang.code, isSelected),
                            const SizedBox(width: 14),
                            Text(
                              lang.name,
                              style: TextStyle(
                                color: ivory,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: goldPrimary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pastille avec le code langue (ex: "FR") — rendu fiable partout, contrairement
  /// aux emojis-drapeaux que beaucoup de polices n'affichent pas.
  Widget _codeBadge(String code, bool isSelected) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? goldPrimary.withValues(alpha: 0.18)
            : midnightPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? goldPrimary
              : greyColor.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          color: isSelected ? goldPrimary : ivory,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

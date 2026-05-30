import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  List languageList = [
    'English (US)',
    'English (UK)',
    'Spanish',
    'French',
    'German',
    'Japanese',
  ];
  int selectedLanguage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Language'),
      body: Padding(
        padding: myPadding,
        child: Column(
          children: [
            GestureDetector(
              child: Container(
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? cardDeep : cardDeep,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: greyColor.withValues(alpha: 0.2)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: myPadding,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLanguage = languageList[index];
                          });
                        },
                        child: Row(
                          children: [
                            Text(languageList[index]),
                            Spacer(),

                            languageList[index] == selectedLanguage
                                ? Image.asset(
                                    'assets/check_icon.png',

                                    width: 15,
                                    height: 15,
                                  )
                                : SizedBox.shrink(),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(color: greyColor);
                  },
                  itemCount: languageList.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

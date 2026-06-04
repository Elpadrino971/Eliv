import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/shimmer_loaders.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final settingController = Get.put(SettingController());

  Future myInitMethod() async {
    await settingController.getManagement();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Frequently Asked Questions'),
      body: GetBuilder<SettingController>(
        builder: (controller) {
          final faqList = controller.management.value.list;

          if (faqList == null) {
            return SingleChildScrollView(
              child: Padding(
                padding: myPadding,
                child: Column(
                  children: List.generate(
                    6,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: EventTileShimmer(),
                    ),
                  ),
                ),
              ),
            );
          }

          if (faqList.isEmpty) {
            return Center(
              child: Text(
                'empty_no_faqs'.tr,
                style: const TextStyle(color: greyColor, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: myPadding,
            itemCount: faqList.length,
            separatorBuilder: (context, index) => height(0.015),
            itemBuilder: (context, index) {
              final faq = faqList[index];
              return Container(
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? cardDeep : whiteColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: greyColor.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      dense: true,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        faq.name ?? 'sup_no_title'.tr,
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      iconColor: mainThemeColor,
                      collapsedIconColor: greyColor,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          child: Text(
                            faq.description ?? 'sup_no_answer'.tr,
                            style: TextStyle(
                              color: greyColor.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

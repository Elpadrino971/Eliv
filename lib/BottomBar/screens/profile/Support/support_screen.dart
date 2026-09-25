import 'package:artist/BottomBar/screens/profile/Support/all_support_chats.dart';
import 'package:artist/Controllers/support_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:artist/widgets/shimmer_loaders.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final supportController = Get.find<SupportController>();
  final searchController = TextEditingController();
  List filteredSubjects = [];

  Future myInitMethod() async {
    await supportController.getSupportSubjects();
    _filterSubjects('');
  }

  void _filterSubjects(String query) {
    final allSubjects = supportController.supportSubjects?['list'] ?? [];
    if (query.isEmpty) {
      filteredSubjects = List.from(allSubjects);
    } else {
      filteredSubjects = allSubjects.where((subject) {
        final name = subject['name'].toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  @override
  void initState() {
    myInitMethod();
    searchController.addListener(() {
      _filterSubjects(searchController.text);
    });
    super.initState();
  }

  void _showCreateTicketSheet({String? initialSubject}) {
    final subController = TextEditingController(text: initialSubject);
    final descController = TextEditingController();
    final bool isCustom = initialSubject == null;

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? cardDeep : whiteColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: greyColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              height(0.02),
              Text(
                isCustom
                    ? 'Tell us what’s wrong'
                    : 'Ticket for: $initialSubject',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              height(0.02),
              Text(
                'sup_subject'.tr,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              height(0.005),
              MyTextField(
                hintText: 'sup_subject_hint'.tr,
                controller: subController,
                readOnly: !isCustom,
              ),
              height(0.02),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              height(0.005),
              MyTextField(
                hintText: 'sup_describe_hint'.tr,
                controller: descController,
                maxLines: 4,
              ),
              height(0.03),
              MyButton(
                label: 'sup_create_ticket'.tr,
                onTap: () async {
                  if (subController.text.isEmpty ||
                      descController.text.isEmpty) {
                    myWarningDialog(subtitle: 'All fields are required.');
                    return;
                  }
                  myLoadingDialog();
                  await supportController.createSupport(
                    subController.text.trim(),
                    descController.text.trim(),
                  );
                  Get.back(); // close loading
                  Get.back(); // close sheet
                  mySuccessDialog(
                    subtitle: 'sup_created'.tr,
                    ontap: () => Get.back(),
                  );
                },
                labelColor: whiteColor,
              ),
              height(0.02),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(
        title: 'support_create_title'.tr,
        actions: [
          IconButton(
            onPressed: () {
              Get.to(() => const AllSupportChats());
            },
            icon: const Icon(Icons.history, color: mainThemeColor),
          ),
        ],
      ),
      body: Padding(
        padding: myPadding,
        child: GetBuilder<SupportController>(
          builder: (controller) {
            final subjects = controller.supportSubjects;
            if (subjects == null) {
              return EventTileShimmer();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height(0.01),
                Container(
                  padding: myPadding,
                  width: Get.width,
                  decoration: BoxDecoration(
                    color: Get.isDarkMode ? goldPrimary : mainThemeColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sup_how_help'.tr,
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      height(0.01),
                      Text(
                        'sup_search_desc'.tr,
                        style: TextStyle(
                          color: whiteColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      height(0.01),
                      MyTextField(
                        hintText: 'sup_search_hint'.tr,
                        controller: searchController,
                        fillColor: whiteColor.withValues(alpha: 0.1),
                        borderColor: whiteColor,
                        textColor: whiteColor,
                        hintColor: whiteColor,
                      ),
                    ],
                  ),
                ),
                height(0.01),
                Text(
                  'sup_popular_topics'.tr,
                  style: TextStyle(
                    color: greyColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                height(0.01),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (filteredSubjects.isEmpty &&
                          searchController.text.isNotEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              'sup_no_topics'.tr,
                              style: const TextStyle(color: greyColor),
                            ),
                          ),
                        ),
                      ...filteredSubjects.map((subject) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _showCreateTicketSheet(
                              initialSubject: subject['name'],
                            ),
                            child: MyContainer(
                              padding: myPadding,
                              widget: Row(
                                children: [
                                  Text(
                                    subject['name'] ?? 'N/A',
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward_ios_outlined,
                                    size: 13,
                                    color: greyColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      // Other Option
                      GestureDetector(
                        onTap: () => _showCreateTicketSheet(),
                        child: MyContainer(
                          border: Border.all(
                            color: mainThemeColor.withValues(alpha: 0.2),
                          ),
                          color: mainThemeColor.withValues(alpha: 0.05),
                          padding: myPadding,
                          widget: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'sup_other_issues'.tr,
                                    style: TextStyle(
                                      color: mainThemeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'sup_create_custom'.tr,
                                    style: TextStyle(
                                      color: greyColor.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.edit_note,
                                size: 20,
                                color: mainThemeColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      height(0.03),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

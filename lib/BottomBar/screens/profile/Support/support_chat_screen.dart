import 'dart:async';

import 'package:artist/Controllers/support_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/support_model.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final supportController = Get.find<SupportController>();
  final TextEditingController _msgController = TextEditingController();
  Support ticket = Get.arguments;

  Future myInitMethod() async {
    ticket = await supportController.getSupportDetails('${ticket.id ?? ''}');
    supportController.update();
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        ticket = await supportController.getSupportDetails(
          '${ticket.id ?? ''}',
        );
        supportController.update();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(
        title: ticket.subject ?? 'N/A',
        actions: ticket.status != 'resolved'
            ? [
                TextButton(
                  onPressed: () async {
                    final data = await _showCompleteDialog();
                    if (data.id != null) {
                      ticket = data;
                      supportController.update();
                    }
                  },
                  child: Text(
                    'common_done'.tr,
                    style: TextStyle(
                      color: mainThemeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ticket = await supportController.getSupportDetails(
            '${ticket.id ?? ''}',
          );
          supportController.update();
        },
        child: GetBuilder<SupportController>(
          init: supportController,
          builder: (controller) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: (ticket.metaData ?? []).length,
                    itemBuilder: (context, index) {
                      final msg = ticket.metaData![index];
                      final isUser = msg.userId == userModel.value.user?.id;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: Get.width * 0.7,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser
                                ? mainThemeColor
                                : (Get.isDarkMode
                                      ? cardDeep
                                      : const Color(0xffF2F2F2)),
                            borderRadius: BorderRadius.circular(15).copyWith(
                              bottomRight: isUser
                                  ? const Radius.circular(0)
                                  : const Radius.circular(15),
                              bottomLeft: isUser
                                  ? const Radius.circular(15)
                                  : const Radius.circular(0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.value ?? 'N/A',
                                style: TextStyle(
                                  color: isUser
                                      ? whiteColor
                                      : (Get.isDarkMode
                                            ? whiteColor
                                            : blackColor),
                                  fontSize: 14,
                                ),
                              ),
                              height(0.005),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(msg.createdAt ?? DateTime.now()),
                                style: TextStyle(
                                  color: isUser
                                      ? whiteColor.withValues(alpha: 0.7)
                                      : greyColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (ticket.status != 'resolved')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? const Color(0xff0D1117)
                          : whiteColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Get.isDarkMode
                                  ? cardDeep
                                  : const Color(0xffF8F8F8),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: TextField(
                              controller: _msgController,
                              decoration: InputDecoration(
                                hintText: 'sup_type_message'.tr,
                                border: InputBorder.none,
                                hintStyle: const TextStyle(
                                  color: greyColor,
                                  fontSize: 14,
                                ),
                              ),
                              style: TextStyle(
                                color: Get.isDarkMode ? whiteColor : blackColor,
                              ),
                            ),
                          ),
                        ),
                        width(0.02),
                        CircleAvatar(
                          backgroundColor: mainThemeColor,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: whiteColor,
                              size: 18,
                            ),
                            onPressed: () async {
                              final String msg = _msgController.text.trim();
                              if (msg.isEmpty) {
                                return;
                              }
                              _msgController.clear();
                              ticket = await supportController.storeSupportMeta(
                                '${ticket.id}',
                                "text",
                                msg,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'sup_completed'.tr,
                      style: TextStyle(
                        color: greyColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Support> _showCompleteDialog() async {
    double selectedRating = 5;
    final TextEditingController feedbackController = TextEditingController();
    Support toReturn = Support();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'sup_resolve_ticket'.tr,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sup_exp_q'.tr,
                  style: TextStyle(fontSize: 14, color: greyColor),
                ),
                height(0.02),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = index + 1.0;
                        });
                      },
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                height(0.02),
                Text(
                  'sup_feedback'.tr,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                height(0.005),
                MyTextField(
                  hintText: 'sup_share_thoughts'.tr,
                  controller: feedbackController,
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('common_cancel'.tr, style: TextStyle(color: greyColor)),
              ),
              TextButton(
                onPressed: () async {
                  myLoadingDialog();
                  final data = await supportController.resolveSupport(
                    id: '${ticket.id}',
                    rating: selectedRating.toString(),
                    review: feedbackController.text.trim(),
                  );
                  toReturn = data;
                  mySuccessDialog(
                    subtitle:
                        'sup_resolved_thanks'.tr,
                    ontap: () {
                      Get.back(result: data); // close loading
                      Get.back(result: data); // close dialog
                      Get.back(result: data); // back to list
                    },
                  );
                },
                child: Text(
                  'sup_mark_resolved'.tr,
                  style: TextStyle(
                    color: mainThemeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return toReturn;
  }
}

import 'package:artist/BottomBar/screens/profile/Support/support_chat_screen.dart';
import 'package:artist/BottomBar/screens/profile/Support/support_screen.dart';
import 'package:artist/Controllers/support_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/shimmer_loaders.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AllSupportChats extends StatefulWidget {
  const AllSupportChats({super.key});

  @override
  State<AllSupportChats> createState() => _AllSupportChatsState();
}

class _AllSupportChatsState extends State<AllSupportChats> {
  final supportController = Get.put(SupportController());
  Future myInitMethod() async {
    await supportController.getSupportList();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'sup_tickets'.tr),
      body: RefreshIndicator(
        onRefresh: myInitMethod,
        child: Padding(
          padding: myPadding,
          child: GetBuilder<SupportController>(
            builder: (controller) {
              final supports = controller.supportList.value.list;

              if (supports == null) {
                return EventTileShimmer();
              }
              if (supports.isEmpty) {
                return Center(child: Text("No Support Tickets"));
              }
              return Column(
                children: [
                  height(0.01),
                  Expanded(
                    child: ListView.separated(
                      itemCount: supports.length,
                      separatorBuilder: (context, index) => height(0.02),
                      itemBuilder: (context, index) {
                        final ticket = supports[index];
                        return GestureDetector(
                          onTap: () async {
                            await Get.to(
                              () => SupportChatScreen(),
                              arguments: ticket,
                            );
                            await myInitMethod();
                          },
                          child: MyContainer(
                            padding: const EdgeInsets.all(16),
                            widget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      ticket.priority ?? 'N/A',
                                      style: const TextStyle(
                                        color: greyColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    _buildStatusBadge(ticket.status ?? ''),
                                  ],
                                ),
                                height(0.01),
                                Text(
                                  ticket.subject ?? '',
                                  style: TextStyle(
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                height(0.005),
                                Text(
                                  (ticket.metaData ?? []).isEmpty
                                      ? 'No Description'
                                      : ticket.metaData?.last.value ?? 'N/A',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: greyColor.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                height(0.015),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: greyColor,
                                    ),
                                    width(0.01),
                                    Text(
                                      DateFormat(
                                        'dd MMM, yyyy',
                                      ).format(ticket.createdAt!),
                                      style: const TextStyle(
                                        color: greyColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'common_view_details'.tr,
                                      style: TextStyle(
                                        color: mainThemeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: mainThemeColor,
        onPressed: () async {
          await Get.to(() => const SupportScreen());
          await myInitMethod();
        },
        child: const Icon(Icons.add, color: whiteColor),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.blue;
        break;
      case 'in progress':
        color = Colors.orange;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      default:
        color = greyColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.capitalize ?? 'N/A',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

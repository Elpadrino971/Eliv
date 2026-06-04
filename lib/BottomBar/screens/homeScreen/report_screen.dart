import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final describeController = TextEditingController();
  String selectedReason = '';
  List<Map> get reasonList => [
    {
      'title': 'home_reason_harassment_title'.tr,
      'subTitle': 'home_reason_harassment_sub'.tr,
    },
    {
      'title': 'home_reason_inappropriate_title'.tr,
      'subTitle': 'home_reason_inappropriate_sub'.tr,
    },
    {
      'title': 'home_reason_violence_title'.tr,
      'subTitle': 'home_reason_violence_sub'.tr,
    },
    {
      'title': 'home_reason_spam_title'.tr,
      'subTitle': 'home_reason_spam_sub'.tr,
    },
    {
      'title': 'home_reason_copyright_title'.tr,
      'subTitle': 'home_reason_copyright_sub'.tr,
    },
    {
      'title': 'home_reason_hate_title'.tr,
      'subTitle': 'home_reason_hate_sub'.tr,
    },
    {
      'title': 'home_reason_other_title'.tr,
      'subTitle': 'home_reason_other_sub'.tr,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'home_report_title'.tr),
      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: Get.width,
                padding: myPadding,
                decoration: BoxDecoration(
                  color: Color(0xffFFF6ED),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Color(0xffFFC9C9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/alert.png', width: 20, height: 20),
                    width(0.02),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home_important'.tr,
                          style: TextStyle(
                            color: Color(0xff101828),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          width: Get.width * 0.7,
                          child: Text(
                            'home_report_warning'.tr,
                            style: TextStyle(
                              color: Color(0xff4A5565),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              height(0.01),
              MyContainer(
                padding: EdgeInsets.only(left: 15, right: 15),
                widget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home_reporting'.tr,
                      style: TextStyle(
                        color: Color(0xff99A1AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.all(0),

                      leading: Image.asset(
                        'assets/report_icon.png',
                        width: 40,
                        height: 40,
                      ),
                      title: Text(
                        'home_report_live_performance'.tr,
                        style: TextStyle(
                          color: Get.isDarkMode
                              ? whiteColor
                              : Color(0xff101828),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Electric Dreams Festival',
                        style: TextStyle(
                          color: Color(0xff99A1AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              height(0.01),

              Text(
                'home_select_reason'.tr,
                style: TextStyle(
                  color: ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedReason = reasonList[index]['title'];
                      });
                    },
                    child: MyContainer(
                      border: BoxBorder.all(
                        color: Get.isDarkMode
                            ? reasonList[index]['title'] == selectedReason
                                  ? goldPrimary
                                  : cardDeep
                            : reasonList[index]['title'] == selectedReason
                            ? mainThemeColor
                            : Color(0xffE5E7EB),
                      ),

                      padding: EdgeInsets.only(left: 15, right: 15),
                      widget: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.all(0),
                            title: Text(
                              reasonList[index]['title'],
                              style: TextStyle(
                                color: Get.isDarkMode ? whiteColor : blackColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              reasonList[index]['subTitle'],
                              style: TextStyle(
                                color: Color(0xff6A7282),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Image.asset(
                              'assets/circle_icon2.png',
                              width: 20,
                              height: 20,
                              color: Get.isDarkMode
                                  ? reasonList[index]['title'] == selectedReason
                                        ? goldPrimary
                                        : whiteColor
                                  : reasonList[index]['title'] == selectedReason
                                  ? mainThemeColor
                                  : whiteColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return height(0.01);
                },
                itemCount: reasonList.length,
              ),
              height(0.01),

              Text(
                'home_describe_issue'.tr,
                style: TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              height(0.01),

              MyTextField(
                hintText: 'home_describe_issue_hint'.tr,
                controller: describeController,
                maxLines: 3,
              ),
              height(0.02),

              Row(
                children: [
                  SizedBox(
                    width: Get.width * 0.44,
                    child: MyButton(
                      label: 'common_cancel'.tr,
                      onTap: () {},

                      labelColor: Color(0xff364153),
                      buttonColor: Color(0xffF3F4F6),
                    ),
                  ),

                  Spacer(),

                  SizedBox(
                    width: Get.width * 0.44,
                    child: MyButton(
                      label: 'home_submit_report'.tr,
                      onTap: () {},

                      labelColor: whiteColor,
                      buttonColor: mainThemeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

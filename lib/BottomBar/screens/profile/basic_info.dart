import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/BottomBar/screens/profile/artist_basic_info.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BasicInfo extends StatefulWidget {
  const BasicInfo({super.key});

  @override
  State<BasicInfo> createState() => _BasicInfoState();
}

class _BasicInfoState extends State<BasicInfo> {
  final authController = Get.find<AuthController>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final primaryController = TextEditingController();
  final performanceController = TextEditingController();
  final experienceController = TextEditingController();
  List<TextEditingController> socialURLController = [];
  List<TextEditingController> socialNameController = [];

  final formKey = GlobalKey<FormState>();

  Future myInitMethod() async {
    socialURLController = [TextEditingController()];
    socialNameController = [TextEditingController()];
    emailController.text = userModel.value.user?.email ?? '';
    nameController.text = userModel.value.user?.artistName ?? '';
    phoneController.text = userModel.value.user?.phoneNumber ?? '';
    experienceController.text = userModel.value.user?.experience ?? '';
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'prof_become_artist'.tr),
      body: Form(
        key: formKey,
        child: Column(
          children: [
            Padding(
              padding: myPadding,
              child: Get.isDarkMode
                  ? Image.asset('assets/basic_image.png')
                  : Image.asset('assets/active_image1.png'),
            ),
            height(0.01),

            MyContainer(
              // color: Color(0xfffefbe9),
              border: BoxBorder.all(color: Colors.transparent),
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        '10k+',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Artists',
                        style: TextStyle(
                          color: Color(0xff4A5565),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        '\$2M+',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Paid Out',
                        style: TextStyle(
                          color: Color(0xff4A5565),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        '500k+',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Attendees',
                        style: TextStyle(
                          color: Color(0xff4A5565),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        '4.9★',
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'sup_rating'.tr,
                        style: TextStyle(
                          color: Color(0xff4A5565),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            height(0.02),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: myPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Artist/Band Name *',
                        style: TextStyle(
                          color: Color(0xff364153),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      MyTextField(
                        hintText: 'ba_stage_hint'.tr,
                        controller: nameController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_stage'.tr;
                          }
                          return null;
                        },
                      ),

                      Text(
                        'Email *',
                        style: TextStyle(
                          color: Color(0xff364153),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      MyTextField(
                        hintText: 'your@email.com',
                        readOnly: true,
                        controller: emailController,
                      ),
                      Text(
                        'Phone Number *',
                        style: TextStyle(
                          color: Color(0xff364153),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      MyTextField(
                        hintText: '+1 (555) 000-0000',
                        controller: phoneController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_phone'.tr;
                          }
                          return null;
                        },
                      ),

                      Text(
                        'Primary Genre *',
                        style: TextStyle(
                          color: Color(0xff364153),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      MyTextField(
                        hintText: '',
                        controller: primaryController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_genre'.tr;
                          }
                          return null;
                        },
                      ),
                      Text(
                        'Performance Experience *',
                        style: TextStyle(
                          color: Color(0xff364153),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      MyTextField(
                        hintText: '',
                        controller: performanceController,
                        validation: (v) {
                          if (v!.isEmpty) {
                            return 'val_experience'.tr;
                          }
                          return null;
                        },
                      ),
                      height(0.01),

                      Row(
                        children: [
                          Text(
                            'Social Media / Website*',
                            style: TextStyle(
                              color: Color(0xff364153),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Spacer(),

                          GestureDetector(
                            onTap: () {
                              socialURLController.add(TextEditingController());
                              socialNameController.add(TextEditingController());
                              setState(() {});
                            },
                            child: Image.asset(
                              'assets/plus_icon2.png',
                              width: 22,
                            ),
                          ),
                        ],
                      ),
                      ...List.generate(socialURLController.length, (index) {
                        return Row(
                          children: [
                            SizedBox(
                              width: Get.width * 0.25,
                              child: MyTextField(
                                hintText: 'ba_social_name'.tr,
                                controller: socialNameController[index],
                                validation: (v) {
                                  if (v!.isEmpty) {
                                    return 'val_social_name'.tr;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            width(0.02),
                            Expanded(
                              child: MyTextField(
                                hintText: 'ba_social_hint'.tr,
                                controller: socialURLController[index],
                                validation: (v) {
                                  if (v!.isEmpty) {
                                    return 'val_social_url'.tr;
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      }),

                      height(0.02),
                      MyButton(
                        label: 'common_continue'.tr,
                        onTap: () {
                          if (formKey.currentState!.validate()) {
                            Map socialLinks = {};
                            for (
                              int i = 0;
                              i < socialURLController.length;
                              i++
                            ) {
                              socialLinks[socialNameController[i].text] =
                                  socialURLController[i].text;
                            }
                            Map body = {
                              'artist_name': nameController.text,
                              'primary_genre': primaryController.text,
                              'experience': performanceController.text,
                              'artist_number': phoneController.text,
                              'social_links': socialLinks,
                            };
                            Get.to(() => ArtistBankInfo(), arguments: body);
                            myPrint(body);
                          }
                        },
                        labelColor: whiteColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

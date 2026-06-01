import 'dart:io';

import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/image_widget.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final authController = Get.find<AuthController>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final numberController = TextEditingController();
  final dateController = TextEditingController();
  final bioController = TextEditingController();

  File? showImage;

  Future myInitMethod() async {
    nameController.text = userModel.value.user?.fullName ?? '';
    emailController.text = userModel.value.user?.email ?? '';
    numberController.text = userModel.value.user?.phoneNumber ?? '';
    dateController.text = userModel.value.user?.dob ?? '';
    bioController.text = userModel.value.user?.bio ?? '';
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'personal_title'.tr),
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.02),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await pickImage().then((value) {
                          setState(() {
                            showImage = value;
                          });
                        });
                      },
                      child: Center(
                        child: Stack(
                          children: [
                            showImage != null
                                ? ClipOval(
                                    child: Image.file(
                                      showImage!,
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                    ),
                                  )
                                : ClipOval(
                                    child: ImageWidget(
                                      url:
                                          '${userModel.value.user?.profileImage}',
                                      fit: BoxFit.cover,
                                      height: 80,
                                      width: 80,

                                      // height: 120,
                                    ),
                                  ),

                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/camra2.png',

                                  height: 25,
                                  width: 25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    height(0.01),

                    Center(
                      child: Text(
                        'auth_upload_photo'.tr,
                        style: TextStyle(
                          color: Color(0xffA1A1A1),

                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    height(0.02),

                    Text(
                      'f_full_name'.tr,
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    MyTextField(
                      hintText: 'Alex Harrison',
                      controller: nameController,
                    ),

                    Text(
                      'Email Address',
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    MyTextField(
                      hintText: 'alex.h@VybzzZ.com',
                      controller: emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    Text(
                      'f_phone'.tr,
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    MyTextField(
                      hintText: '+1 (555) 012-3456',
                      controller: numberController,

                      keyboardType: TextInputType.number,
                    ),

                    Text(
                      'auth_date_of_birth'.tr,
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    MyTextField(
                      hintText: 'February 18, 1995',
                      controller: dateController,
                      readOnly: true,
                      onTap: () async {
                        await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        ).then((value) {
                          if (value != null) {
                            final formated = DateFormat(
                              'MMMM dd, yyyy',
                            ).format(value);
                            dateController.text = formated;
                          }
                        });
                      },
                      keyboardType: TextInputType.datetime,
                    ),
                    Text(
                      'f_bio'.tr,
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    MyTextField(
                      hintText: 'ba_bio_hint'.tr,
                      controller: bioController,
                      maxLines: 5,
                      keyboardType: TextInputType.text,
                    ),

                    height(0.02),

                    MyButton(
                      label: 'ba_update_profile'.tr,
                      onTap: () async {
                        await authController.updateProfile(
                          name: nameController.text,
                          phoneNumber: numberController.text,
                          birthDate: dateController.text,
                          profilePicture: showImage?.path ?? '',
                          about: bioController.text,
                          fromEdit: true,
                        );
                      },
                      labelColor: whiteColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

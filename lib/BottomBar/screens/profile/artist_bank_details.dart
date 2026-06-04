import 'dart:io';

import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ArtistBankDetails extends StatefulWidget {
  const ArtistBankDetails({super.key});

  @override
  State<ArtistBankDetails> createState() => _ArtistBankDetailsState();
}

class _ArtistBankDetailsState extends State<ArtistBankDetails> {
  final authController = Get.find<AuthController>();
  var bioController = TextEditingController();
  var addressController = TextEditingController();
  File? showImage;
  double? lat, lng;
  Map body = Get.arguments;

  final formKey = GlobalKey<FormState>();

  Future myInitMethod() async {
    myPrint(body);
    addressController.text = userModel.value.user?.address ?? '';
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

      body: Padding(
        padding: myPadding,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Get.isDarkMode
                  ? Image.asset('assets/active6.png', width: Get.width)
                  : Image.asset('assets/details_image1.png', width: Get.width),

              height(0.02),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'ba_complete_your_profile'.tr,
                        style: TextStyle(
                          color: ivory,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(
                        width: Get.width * 0.75,
                        child: Text(
                          'ba_help_fans'.tr,
                          style: TextStyle(
                            color: Color(0xff4A5565),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      height(0.01),

                      SizedBox(
                        width: Get.width * 0.75,
                        child: Text(
                          'ba_profile_photo'.tr,
                          style: TextStyle(
                            color: Color(0xff364153),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      height(0.01),

                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await pickImage(source: ImageSource.camera).then((
                                value,
                              ) {
                                setState(() {
                                  showImage = value;
                                });
                              });
                            },
                            child: Get.isDarkMode
                                ? Image.asset(
                                    'assets/camra3.png',
                                    width: 40,
                                    height: 40,
                                  )
                                : Image.asset(
                                    'assets/upload_icon.png',
                                    width: 40,
                                    height: 40,
                                  ),
                          ),
                          width(0.02),

                          GestureDetector(
                            onTap: () async {
                              await pickImage().then((value) {
                                setState(() {
                                  showImage = value;
                                });
                              });
                            },
                            child: MyContainer(
                              noWidth: true,
                              padding: EdgeInsets.all(8),
                              widget: Row(
                                children: [
                                  Image.asset(
                                    'assets/upload_icon2.png',
                                    width: 15,
                                    height: 15,
                                    color: Get.isDarkMode
                                        ? whiteColor
                                        : blackColor,
                                  ),

                                  width(0.02),

                                  Text(
                                    'auth_upload_photo'.tr,
                                    style: TextStyle(
                                      color: Get.isDarkMode
                                          ? whiteColor
                                          : blackColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          width(0.02),
                          showImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    showImage!,
                                    fit: BoxFit.cover,
                                    width: 50,
                                    height: 50,
                                  ),
                                )
                              : SizedBox(),
                        ],
                      ),

                      height(0.01),
                      Text(
                        'Artist Bio *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: 'ba_story'.tr,
                        controller: bioController,
                        onChanged: (value) {
                          setState(() {});
                        },
                        validation: (value) {
                          if (value == null || value.isEmpty) {
                            return 'val_enter_bio'.tr;
                          }
                          if (value.length < 50) {
                            return 'val_bio_min'.tr;
                          }
                          return null;
                        },
                        maxLines: 4,
                      ),
                      height(0.01),

                      Row(
                        children: [
                          Text(
                            'val_min_50'.tr,
                            style: TextStyle(
                              color: Color(0xff6A7282),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),

                          Spacer(),

                          Text(
                            '${bioController.text.length}/500',
                            style: TextStyle(
                              color: Color(0xff6A7282),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      height(0.01),
                      Text(
                        'Address *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff364153),
                        ),
                      ),

                      MyTextField(
                        hintText: 'Enter your address',
                        controller: addressController,
                        validation: (value) {
                          if (value == null || value.isEmpty) {
                            return 'val_address'.tr;
                          }
                          return null;
                        },
                        leading: Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Color(0xff99A1AF),
                        ),
                      ),
                      height(0.01),
                      MyContainer(
                        widget: Text(
                          'ba_agreement'.tr,
                          style: TextStyle(
                            color: Color(0xff4A5565),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      height(0.02),

                      MyButton(
                        label: 'sup_submit_request'.tr,
                        onTap: () async {
                          if (formKey.currentState!.validate()) {
                            // Print all collected forms data
                            myPrint('--- ALL COLLECTED FORMS DATA ---');
                            myPrint(body);
                            myPrint('Bio: ${bioController.text}');
                            myPrint('Address: ${addressController.text}');
                            if (showImage != null) {
                              myPrint('Profile Photo Path: ${showImage!.path}');
                            }
                            myPrint('-------------------------------');

                            Map social = body['social_links'];
                            await authController.updateProfile(
                              platform: social.keys.toList(),
                              urls: social.values.toList(),
                              artistNumber: body['artist_number'],
                              accountHolderName: body['account_holder_name'],
                              bankName: body['bank_name'],
                              accountNumber: body['account_number'],
                              swiftNumber: body['swift_number'],
                              routingNumber: body['routing_number'],
                              artistBio: bioController.text,
                              location: addressController.text,
                              lat: lat?.toString() ?? '0.0',
                              lng: lng?.toString() ?? '0.0',
                              experience: body['experience'],
                              primaryGenre: body['primary_genre'],
                              artistName: body['artist_name'],
                              artistProfile: showImage?.path,
                              formArtist: true,
                            );
                          }
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
      ),
    );
  }
}

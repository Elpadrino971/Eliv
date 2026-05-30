import 'dart:io';

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_header.dart';
import 'package:artist/widgets/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CompleteProfile extends StatefulWidget {
  const CompleteProfile({super.key});

  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<CompleteProfile> {
  final authController = Get.put(AuthController());
  var birthController = TextEditingController();
  var cboutController = TextEditingController();

  File? showImage;

  List selectedIndex = [];

  Future myInitMethod() async {
    await authController.getGenres();
  }

  @override
  void initState() {
    super.initState();
    myInitMethod();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: myPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            height(0.04),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: Get.width * 0.8,
                  child: MyHeader(activeIndex: 2),
                ),
                GestureDetector(
                  onTap: () {
                    myAlertDialog(
                      title: 'Skip',
                      content: 'Are you sure you want to skip?',
                      onTap: () {
                        Get.offAll(() => LoginScreen());
                      },
                    );
                    // myPrint(userModel);
                  },
                  child: Text(
                    "Skip",
                    style: TextStyle(
                      color: Get.isDarkMode ? redColor : mainThemeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            height(0.035),

            Text(
              'Complete Profile',
              style: TextStyle(
                color: blackColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(
              width: Get.width * 0.65,
              child: Text(
                "Tell us a bit more about yourself",
                style: TextStyle(
                  color: const Color.fromARGB(255, 212, 212, 212),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            height(0.01),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
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
                                    child: Image.asset(
                                      'assets/upload_image.png',
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
                        'Upload Photo',
                        style: TextStyle(
                          color: Color(0xffA1A1A1),

                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    height(0.02),

                    MyTextField(
                      hintText: 'Date of Birth',
                      controller: birthController,
                      keyboardType: TextInputType.datetime,

                      leading: GestureDetector(
                        onTap: () async {
                          await pickDate(context).then((value) {
                            if (value != null) {
                              setState(() {
                                birthController.text = value;
                              });
                            }
                          });
                        },

                        child: Image.asset(
                          'assets/date_icon2.png',
                          color: Color(0xffD4D4D4),
                        ),
                      ),

                      readOnly: true,

                      onTap: () async {
                        await pickDate(context).then((value) {
                          if (value != null) {
                            setState(() {
                              birthController.text = value;
                            });
                          }
                        });
                      },

                      textColor: blackColor,
                    ),

                    MyTextField(
                      hintText: 'Tell us about your musical taste...',
                      controller: cboutController,
                      keyboardType: TextInputType.emailAddress,

                      leading: Image.asset(
                        'assets/text_icon.png',
                        width: 15,
                        height: 15,
                      ),
                      textColor: blackColor,
                      maxLines: 1,
                    ),

                    Row(
                      children: [
                        Image.asset('assets/icon2.png'),

                        Text(
                          ' Favorite Genres',
                          style: TextStyle(
                            color: Color(0xffA1A1A1),

                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    height(0.02),
                    Obx(() {
                      final genres = authController.genres.value.genre ?? [];
                      return SizedBox(
                        height: Get.height * 0.2,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.all(0),
                          itemCount: genres.length,

                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.8,

                                crossAxisSpacing: 5,
                                mainAxisSpacing: 5,
                              ),
                          itemBuilder: (context, index) {
                            final genre = genres[index];
                            return GestureDetector(
                              onTap: () {
                                if (selectedIndex.contains(genre)) {
                                  selectedIndex.remove(genre);
                                } else {
                                  selectedIndex.add(genre);
                                }
                                setState(() {});
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Get.isDarkMode
                                      ? selectedIndex.contains(genre)
                                            ? redColor
                                            : boxColor
                                      : selectedIndex.contains(genre)
                                      ? mainThemeColor
                                      : boxColor,
                                  border: Border.all(color: Color(0xffF5F5F5)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Text(
                                    genre.genre ?? '',
                                    style: TextStyle(
                                      color: selectedIndex.contains(genre)
                                          ? whiteColor
                                          : Color(0xffA1A1A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),

                    // height(0.02),
                    MyButton(
                      label: 'Complete Account',
                      onTap: () async {
                        List values = selectedIndex.map((e) => e.id).toList();
                        await authController.updateProfile(
                          about: cboutController.text,
                          birthDate: birthController.text,
                          genres: values,
                          profilePicture: showImage?.path,
                        );
                      },
                      image: 'assets/arrow.png',
                      imageColor: whiteColor,
                      labelColor: whiteColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // bottomNavigationBar: Padding(
      //   padding: myPadding,
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: [
      //       Text(
      //         "Already have an account? ",
      //         style: TextStyle(
      //           color: Color(0xffA1A1A1),
      //           fontWeight: FontWeight.w400,
      //           fontSize: 14,
      //         ),
      //       ),
      //       width(0.02),
      //       GestureDetector(
      //         onTap: () {
      //           Get.to(() => LoginScreen());
      //         },
      //         child: Text(
      //           "Log In",
      //           style: TextStyle(
      //             color: Get.isDarkMode ? redColor : mainThemeColor,
      //             fontWeight: FontWeight.bold,
      //             fontSize: 14,
      //           ),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    );
  }
}

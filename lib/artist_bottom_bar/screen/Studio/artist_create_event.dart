import 'dart:io';

import 'package:artist/Controllers/controller.dart';
import 'package:artist/Global/app_date.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ArtistCreateEvent extends StatefulWidget {
  const ArtistCreateEvent({super.key});

  @override
  State<ArtistCreateEvent> createState() => _ArtistCreateEventState();
}

class _ArtistCreateEventState extends State<ArtistCreateEvent> {
  final artistController = Get.find<ArtistController>();

  final titleController = TextEditingController();
  final genreController = TextEditingController();
  final descriptionController = TextEditingController();
  final startDateController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final standardController = TextEditingController();
  final vipController = TextEditingController();
  String? selectedGenre;

  bool liveValue = true;

  final formKey = GlobalKey<FormState>();

  File? coverImage;
  XFile? visualVideo;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        coverImage = File(image.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        visualVideo = video;
      });
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      setState(() {
        controller.text = DateFormat('HH:mm:ss').format(dt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Create Event'),

      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: myPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create',
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),

                Text(
                  'New Performance',
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.02),

                Text(
                  ' Event Details',
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),
                Text(
                  'Title *',
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyTextField(
                  hintText: 'e.g. Neon Nights Live',
                  controller: titleController,
                  validation: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Genre *',
                      style: TextStyle(
                        color: Color(0xff737373),

                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    Obx(() {
                      final genre = artistController.genres.value.genre ?? [];
                      return MyDropDown(
                        dropdownvalue: selectedGenre,
                        hintText: 'Select Genre',
                        items: genre.map((e) => e.genre ?? '').toList(),
                        onChanged: (value) {
                          selectedGenre = value;
                        },
                        validation: (value) {
                          if (value == null) {
                            return 'Please select a genre';
                          }
                          return null;
                        },
                      );
                    }),
                  ],
                ),

                height(0.01),
                Text(
                  'Description *',
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyTextField(
                  hintText: 'Share more about your show...',
                  controller: descriptionController,
                  maxLines: 4,
                  validation: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),

                height(0.01),
                Text(
                  ' Cover Image *',
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),

                GestureDetector(
                  onTap: _pickImage,
                  child: MyContainer(
                    padding: coverImage != null
                        ? EdgeInsets.all(0)
                        : EdgeInsets.only(
                            top: 30,
                            bottom: 30,
                            left: 15,
                            right: 15,
                          ),

                    widget: coverImage != null
                        ? Image.file(
                            coverImage!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                        : Column(
                            children: [
                              Image.asset('assets/upload4.png', width: 20),

                              Text(
                                'Upload Cover',
                                style: TextStyle(
                                  color: Color(0xffA1A1A1),

                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),

                height(0.01),
                Text(
                  ' Visuals * (Video Only)',
                  style: TextStyle(
                    color: ivory,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                height(0.01),

                GestureDetector(
                  onTap: _pickVideo,
                  child: MyContainer(
                    padding: EdgeInsets.only(
                      top: 30,
                      bottom: 30,
                      left: 15,
                      right: 15,
                    ),

                    widget: Column(
                      children: [
                        visualVideo != null
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Image.asset('assets/upload4.png', width: 20),

                        Text(
                          visualVideo != null
                              ? visualVideo!.name
                              : 'Upload Visual',
                          style: TextStyle(
                            color: Color(0xffA1A1A1),

                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                height(0.02),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date *',
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'yyyy-mm-dd',
                            controller: startDateController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/date_icon2.png',
                              color: Color(0xffD4D4D4),
                            ),
                            onTap: () =>
                                _pickDate(context, startDateController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time *',
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'hh:mm:ss',
                            controller: startTimeController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/clock.png',
                              width: 20,
                              color: Color(0xff737373),
                            ),
                            onTap: () =>
                                _pickTime(context, startTimeController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                height(0.01),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date *',
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'yyyy-mm-dd',
                            controller: startDateController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/date_icon2.png',
                              color: Color(0xffD4D4D4),
                            ),
                            onTap: () =>
                                _pickDate(context, startDateController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time *',
                          style: TextStyle(
                            color: Color(0xff737373),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          width: Get.width * 0.44,
                          child: MyTextField(
                            hintText: 'hh:mm:ss',
                            controller: endTimeController,
                            readOnly: true,
                            leading: Image.asset(
                              'assets/clock.png',
                              width: 20,
                              color: Color(0xff737373),
                            ),
                            onTap: () => _pickTime(context, endTimeController),
                            validation: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            textColor: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                height(0.01),

                Text(
                  'Standard (\$) *',
                  style: TextStyle(
                    color: Color(0xff737373),

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                MyTextField(
                  hintText: '0.00',
                  controller: standardController,
                  keyboardType: TextInputType.number,
                  leading: Icon(
                    Icons.monetization_on,
                    size: 20,
                    color: Color(0xff737373),
                  ),
                  validation: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter ticket price';
                    }
                    return null;
                  },
                ),

                height(0.01),

                Text(
                  'Settings',
                  style: TextStyle(
                    color: Get.isDarkMode ? whiteColor : blackColor,

                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                Row(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/setting.png',
                          width: 20,
                          height: 20,
                          color: Color(0xffA1A1A1),
                        ),
                        width(0.02),

                        Text(
                          'Live Chat',
                          style: TextStyle(
                            color: Get.isDarkMode ? whiteColor : blackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        height(0.01),
                      ],
                    ),
                    Spacer(),
                    Switch(
                      value: liveValue,
                      onChanged: (value) {
                        setState(() {
                          liveValue = value;
                        });
                      },

                      inactiveThumbColor: whiteColor,
                      inactiveTrackColor: greyColor,
                      activeTrackColor: mainThemeColor,
                      activeThumbColor: whiteColor,
                    ),
                  ],
                ),
                height(0.02),
                MyButton(
                  label: 'Publish Event',
                  onTap: () {
                    if (formKey.currentState!.validate()) {
                      if (coverImage == null) {
                        Get.snackbar('Error', 'Please upload a cover image');
                        return;
                      }
                      if (visualVideo == null) {
                        Get.snackbar('Error', 'Please upload a visual video');
                        return;
                      }

                      // Call API logic
                      final selectedGenreId = artistController
                          .genres
                          .value
                          .genre
                          ?.firstWhere((e) => e.genre == selectedGenre)
                          .id;

                      artistController.createEvent(
                        name: titleController.text,
                        description: descriptionController.text,
                        // Envoye en UTC (avec 'Z') pour que chaque spectateur
                        // voie l'heure dans son propre fuseau.
                        startDateTime: AppDate.localPartsToUtcIso(
                          startDateController.text,
                          startTimeController.text,
                        ),
                        endDateTime: AppDate.localPartsToUtcIso(
                          startDateController.text,
                          endTimeController.text,
                        ),
                        ticketPrice: standardController.text,
                        genreId: selectedGenreId?.toString() ?? '',
                        hasLiveChat: liveValue ? '1' : '0',
                        coverImg: coverImage?.path ?? '',
                        visualVideo: visualVideo?.path ?? '',
                      );
                    }
                  },
                  labelColor: whiteColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

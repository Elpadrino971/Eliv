import 'dart:convert';
import 'dart:io';

import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/loading_dialog.dart';
import 'package:artist/widgets/my_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

Rx<UserModel> userModel = UserModel().obs;

final box = GetStorage();

String authorization = userModel.value.token ?? '';

const myPadding = EdgeInsets.all(15);
const myPaddingTwo = EdgeInsets.only(top: 15, left: 15, right: 15);
const textFieldPadding = EdgeInsets.symmetric(vertical: 5);
const String themeKey = 'isDarkMode';

const String revenueCatAppleApiKey = 'appl_KIbaeOroARylQdwdEhBeHEGIVms';

Widget height(double height) {
  return SizedBox(height: Get.height * height);
}

Widget width(double width) {
  return SizedBox(width: Get.width * width);
}

void myPrint(dynamic value) {
  if (kDebugMode) {
    print(value);
  }
}

// Rx<UserModel> userModel=UserModel().obs;

Future<String?> pickDate(BuildContext context) async {
  final DateTime? pickedDate = await showDatePicker(
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: mainThemeColor),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: mainThemeColor),
          ),
        ),
        child: child!,
      );
    },
    initialDate: DateTime.now(),
    currentDate: DateTime.now(),
    context: context,
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
  );

  if (pickedDate != null) {
    String formattedDate = DateFormat('dd MMM, yyyy').format(pickedDate);

    return formattedDate;
  } else {
    return null;
  }
}

Future mySuccessDialog({
  String? title,
  required String subtitle,
  void Function()? ontap,
  String? btnTitle,
  bool showIcon = false,
  bool showSecondIcon = false,
  String? image,
  final Color? secondButtonColor,
  final Color? buttonColor,
  final Color? secondLabelColor,
  final Color? labelColor,
  final String? secondButtonLabel,
  VoidCallback? secondButtonOnTap,
  bool isTwoButton = false,
  double? secondButtonWidth,
  double? firstButtonWidth,
}) async {
  return await showDialog(
    context: Get.context!,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 15),
        child: SuccessDialog(
          title: title ?? 'Success',
          subtitle: subtitle,
          btnTitle: btnTitle,
          image: image,
          ontap:
              ontap ??
              () {
                Get.back();
              },
          firstButtonWidth: firstButtonWidth,
          secondButtonLabel: secondButtonLabel,
          isTwoButton: isTwoButton,
          secondButtonOnTap: secondButtonOnTap,
          secondButtonWidth: secondButtonWidth,
          showIcon: showIcon,
          buttonColor: buttonColor,
          labelColor: labelColor,
          secondButtonColor: secondButtonColor,
          secondLabelColor: secondLabelColor,
          showSecondIcon: showSecondIcon,
        ),
      );
    },
  );
}

Future myWarningDialog({
  String? title,
  required String subtitle,
  void Function()? ontap,
  String? btnTitle,
  String? secondBtnTitle,
  String? image,

  void Function()? secondOnTap,
}) async {
  return await showDialog(
    context: Get.context!,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 15),
        child: WarningDialog(
          title: title ?? 'Warning',
          subtitle: subtitle,
          btnTitle: btnTitle,
          secondButtonTitle: secondBtnTitle,
          image: image,
          secondOnTap: secondOnTap,
          ontap:
              ontap ??
              () {
                Get.back();
              },
        ),
      );
    },
  );
}

Future<void> myLoadingDialog({String? title, bool showLoader = false}) async {
  showDialog(
    barrierDismissible: showLoader,
    context: Get.context!,
    builder: (context) {
      return LoadingDialog(message: title ?? "Loading");
    },
  );
}

Future<File?> pickImage({ImageSource? source}) async {
  final pickedFile = await ImagePicker().pickImage(
    source: source ?? ImageSource.gallery,
  );
  if (pickedFile != null) {
    File image = File(pickedFile.path);
    return image;
  } else {
    return null;
  }
}

Future<String?> pickTime(BuildContext context) async {
  String? formattedTime;
  final TimeOfDay? pickedTime = await showTimePicker(
    context: Get.context!,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            hourMinuteColor: mainThemeColor,
            dayPeriodColor: mainThemeColor,
            backgroundColor: whiteColor,
            hourMinuteTextColor: whiteColor,
            dialHandColor: mainThemeColor,
            dialBackgroundColor: blackColor.withValues(alpha: 0.1),
            dayPeriodTextColor: blackColor,
            entryModeIconColor: blackColor,

            helpTextStyle: TextStyle(color: blackColor),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: blackColor),
          ),
        ),
        child: child!,
      );
    },
    initialTime: TimeOfDay.now(),
  );

  if (pickedTime != null) {
    formattedTime = pickedTime.format(Get.context!);

    return formattedTime;
  } else {
    return formattedTime;
  }
}

// Future<File?> pickVideo() async {
//   final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
//   if (pickedFile != null) {
//     File video = File(pickedFile.path);
//     return video;
//   } else {
//     return null;
//   }
// }

Future<dynamic> myAlertDialog({
  required String title,
  required String content,
  required VoidCallback onTap,
}) {
  return showDialog(
    context: Get.context!,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Get.isDarkMode ? Colors.black : whiteColor,
        elevation: 0,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text(content),
        actions: [
          TextButton(
            child: Text('No'),
            onPressed: () {
              Get.back();
            },
          ),
          TextButton(
            onPressed: onTap,
            child: Text('Yes', style: TextStyle(color: mainThemeColor)),
          ),
        ],
      );
    },
  );
}

/// Parse Error

dynamic parseError(
  String value, {
  bool doBack = false,
  bool showDialog = true,
}) {
  final data = value.split('error ').last;
  final error = jsonDecode(data);
  if (doBack) {
    Get.back();
  }
  showDialog ? myWarningDialog(subtitle: error['message']) : null;
}

/// Calculate total watch time from a list of events
String calculateTotalWatchTime(List<Event> events) {
  Duration total = Duration.zero;
  for (var event in events) {
    if (event.startDateTime != null && event.endDateTime != null) {
      total += event.endDateTime!.difference(event.startDateTime!).abs();
    }
  }
  int hours = total.inHours;
  return '$hours+';
}

/// Calculate single event duration
String calculateEventDuration(DateTime start, DateTime end) {
  Duration diff = end.difference(start).abs();
  int hours = diff.inHours;
  int minutes = diff.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}

Future myShare({required String message}) async {
  await SharePlus.instance.share(ShareParams(text: message));
}

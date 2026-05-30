import 'package:artist/Global/colors.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MyDropDown extends StatelessWidget {
  const MyDropDown({
    super.key,
    this.onTap,
    this.onChanged,
    this.width,
    this.validation,
    required this.dropdownvalue,
    required this.hintText,
    required this.items,
    this.fillColor,
    this.borderRadius,
    this.borderColor,
  });

  final String? dropdownvalue;
  final double? width;
  final VoidCallback? onTap;
  final Function(dynamic)? onChanged;
  final String? Function(String?)? validation;
  final String hintText;
  final List<String> items;
  final Color? fillColor;
  final double? borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: SizedBox(
        width: width ?? Get.width,
        child: DropdownButtonFormField<String>(
          hint: Text(
            hintText,
            style: TextStyle(
              color: Get.isDarkMode ? textMuted : greyColor,
              fontSize: 13,
            ),
          ),
          style: TextStyle(
            color: Get.isDarkMode ? ivory : blackColor,
            fontSize: 14,
          ),
          dropdownColor: Get.isDarkMode ? cardDeep : whiteColor,
          onTap: onTap,
          validator: validation,
          onChanged: onChanged,
          initialValue: dropdownvalue,
          icon: Icon(
            Icons.keyboard_arrow_down_outlined,
            color: Get.isDarkMode ? ivory : blackColor,
          ),
          menuMaxHeight: Get.height * 0.3,

          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Get.isDarkMode ? ivory : blackColor,
                    ),
                  ),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            fillColor:
                fillColor ??
                (Get.isDarkMode ? cardDeep : Color(0xffFAFAFA)),
            filled: true,
            contentPadding: const EdgeInsets.all(12.0),
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius ?? 15),
              borderSide: BorderSide(
                color: borderColor ?? Colors.transparent,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: borderColor ?? goldPrimary,
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(borderRadius ?? 15),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: borderColor ?? Colors.transparent,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(borderRadius ?? 15),
            ),
          ),
        ),
      ),
    );
  }
}

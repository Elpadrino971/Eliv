import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class MyTextField extends StatelessWidget {
  const MyTextField({
    super.key,
    required this.hintText,

    required this.controller,
    this.isHintItalic = false,
    this.maxLength,
    this.onTap,
    this.maxLines = 1,
    this.isObscure = false,
    this.readOnly = false,
    this.autoFocus = false,
    this.filled = true,
    this.keyboardType,
    this.onChanged,
    this.trailing,
    this.leading,
    this.defaultValue,
    this.validation,
    this.textInputAction,
    this.fillColor,
    this.onEditComplete,
    this.hintWeight,
    this.borderRadius,
    this.borderColor,
    this.hintColor,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.onSubmit,
    this.onTapOutside,
    this.hintSize,
    this.contentPadding,
    this.elevation,
    this.textColor,
  });

  final ValueChanged<String>? onSubmit;
  final String hintText;
  final double? hintSize;
  final double? elevation;
  final bool isHintItalic;
  final Color? hintColor;
  final FontWeight? fontWeight;
  final EdgeInsets? contentPadding;
  final Color? borderColor;
  final double? borderRadius;
  final FontWeight? hintWeight;
  final bool isObscure;
  final bool readOnly;
  final bool autoFocus;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;
  final int maxLines;
  final Widget? trailing;
  final Widget? leading;
  final bool? filled;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final TextEditingController controller;
  final String? defaultValue;
  final String? Function(String?)? validation;
  final Color? fillColor;
  final void Function()? onEditComplete;
  final double? fontSize;
  final TextAlign? textAlign;
  final Color? textColor;
  final Function(PointerDownEvent)? onTapOutside;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: TextFormField(
        onTapOutside: onTapOutside,
        onFieldSubmitted: onSubmit,
        textAlign: textAlign ?? TextAlign.start,
        style: TextStyle(
          fontSize: fontSize ?? 14,
          fontWeight: fontWeight,
          color: textColor ?? (Get.isDarkMode ? whiteColor : blackColor),
        ),
        onTap: onTap,
        autofocus: autoFocus,
        onEditingComplete: onEditComplete,
        validator: validation,
        maxLines: maxLines,
        initialValue: defaultValue,
        controller: controller,
        readOnly: readOnly,
        obscureText: isObscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        cursorHeight: 20,
        maxLength: maxLength,
        cursorColor: Get.isDarkMode ? whiteColor : blackColor,
        decoration: InputDecoration(
          fillColor:
              fillColor ??
              (Get.isDarkMode ? Color(0xff141821) : Color(0xffFAFAFA)),
          filled: filled,
          contentPadding: contentPadding ?? const EdgeInsets.all(12.0),
          suffixIcon: trailing,
          prefixIcon: leading,
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
              color: borderColor ?? Colors.transparent,

              width: 1,
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
          hintStyle: TextStyle(
            color:
                hintColor ??
                (Get.isDarkMode ? Color(0xffFAFAFA) : Color(0xff141821)),
            fontSize: hintSize ?? 13,
            fontWeight: hintWeight,

            fontStyle: isHintItalic ? FontStyle.italic : FontStyle.normal,
          ),
          hintText: hintText,
        ),
      ),
    );
  }
}

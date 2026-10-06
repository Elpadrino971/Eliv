import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';

class MyPinInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLength;
  /// Une seule case doit demander le focus à l'ouverture. Quand les six le
  /// demandaient, Android donnait le clavier à la DERNIÈRE : le premier
  /// chiffre atterrissait dans la case 6 et la saisie devenait impossible.
  final bool autofocus;

  const MyPinInputField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.maxLength = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      child: SizedBox(
        width: Get.width * .12,
        // height: 50,
        child: TextFormField(
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter code';
            }
            return null;
          },
          controller: controller,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: maxLength,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxLength),
            FilteringTextInputFormatter.digitsOnly,
          ],
          cursorHeight: 22,
          cursorColor: Get.isDarkMode ? goldPrimary : blackColor,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Get.isDarkMode ? ivory : Color(0xff23334A),
          ),
          decoration: InputDecoration(
            counterText: '',
            fillColor: Get.isDarkMode ? cardDeep : cardDeep,
            filled: true,
            contentPadding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Get.isDarkMode
                    ? goldSecondary.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Get.isDarkMode ? goldPrimary : Colors.transparent,
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

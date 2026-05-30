import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';

class MyPinInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLength;

  const MyPinInputField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.maxLength = 1,
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
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: maxLength,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxLength),
            FilteringTextInputFormatter.digitsOnly,
          ],
          cursorHeight: 22,
          cursorColor: blackColor,
          style: TextStyle(fontSize: 25, color: Color(0xff23334A)),
          decoration: InputDecoration(
            counterText: '',
            fillColor: Color(0xffF3F3F5),

            filled: true,
            contentPadding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

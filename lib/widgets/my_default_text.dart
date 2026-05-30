import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';


class MyDefaultText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const MyDefaultText({
    super.key,

    required this.text,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w500,
    this.color = blackColor,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,

      style: TextStyle(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
        overflow: overflow,
      ),
    );
  }
}

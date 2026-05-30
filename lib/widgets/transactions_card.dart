import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class TransactionsCard extends StatefulWidget {
  const TransactionsCard({
    super.key,
    required this.title,
    required this.price,
    required this.date,
    required this.subTitle,
    required this.name,
    this.isChange = true,
  });
  final String title;
  final String price;
  final String date;
  final String subTitle;
  final String name;
  final bool isChange;

  @override
  State<TransactionsCard> createState() => _TransactionsCardState();
}

class _TransactionsCardState extends State<TransactionsCard> {
  @override
  Widget build(BuildContext context) {
    return MyContainer(
      padding: EdgeInsets.all(10),
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: Get.isDarkMode ? whiteColor : blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                widget.price,
                style: TextStyle(
                  color: widget.isChange
                      ? Color(0xff00A63E)
                      : Color(0xffE7000B),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          Text(
            widget.date,
            style: TextStyle(
              color: greyColor.withValues(alpha: 0.3),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          Text(
            widget.subTitle,
            style: TextStyle(
              color: greyColor.withValues(alpha: 0.3),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.name,
                style: TextStyle(
                  color: greyColor.withValues(alpha: 0.3),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              widget.isChange
                  ? Image.asset(
                      'assets/alert_icon1.png',
                      width: 20,
                      color: Color(0xff00A63E),
                    )
                  : Image.asset(
                      'assets/alert_icon2.png',
                      width: 20,
                      color: Color(0xffE7000B),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

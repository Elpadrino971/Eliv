import 'package:artist/Global/colors.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';

class MyNotification extends StatefulWidget {
  const MyNotification({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.message,
  });

  final String image;
  final String title;
  final String subtitle;
  final String message;

  @override
  State<MyNotification> createState() => _MyNotificationState();
}

class _MyNotificationState extends State<MyNotification> {
  @override
  Widget build(BuildContext context) {
    return MyContainer(
      
      padding: EdgeInsets.only(left: 10, right: 10),
      widget: ListTile(
        contentPadding: EdgeInsets.all(0),
        leading: Image.asset(widget.image, width: 40, height: 40),
        title: Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: ivory,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Spacer(),

            Text(
              widget.subtitle,
              style: TextStyle(
                color: greyColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        subtitle: Text(
          widget.message,
          style: TextStyle(
            color: greyColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    
    
    
    
    
    
    );
  }
}

import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_appbar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'pay_title'.tr),

      body: Padding(
        padding: myPadding,
        child: Column( 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pay_primary_method'.tr,
              style: TextStyle(
                color: greyColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            height(0.01),
            Container(
              padding: myPadding,
              width: Get.width,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/container3.png'),
                  fit: BoxFit.fill,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: 5,
                          bottom: 5,
                        ),
                        decoration: BoxDecoration(
                          color: mainThemeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: whiteColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Image.asset(
                          'assets/payment_icon.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: 5,
                          bottom: 5,
                        ),
                        decoration: BoxDecoration(
                          color: mainThemeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: whiteColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'common_default'.tr,
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  height(0.01),

                  Text(
                    '•••• •••• •••• 4242',
                    style: TextStyle(
                      color: whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  Text(
                    'Alex Harrison',
                    style: TextStyle(
                      color: whiteColor.withValues(alpha: 0.3),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  height(0.01),

                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'label_expires'.tr,
                            style: TextStyle(
                              color: whiteColor.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          Text(
                            '12/28',
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      Spacer(),

                      ClipOval(
                        child: Image.asset(
                          'assets/protect_icon.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            height(0.02),

            Text(
              'pay_other_methods'.tr,
              style: TextStyle(
                color: greyColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            height(0.01),

            MyContainer(
              padding: EdgeInsets.all(0),
              widget: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.only(left: 10, right: 10),
                    leading: Image.asset(
                      'assets/apple_pay.png',
                      width: 50,
                      height: 50,
                    ),
                    title: Text(
                      'Apple Pay',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'pay_linked_icloud'.tr,
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: greyColor,
                    ),
                  ),

                  Divider(color: greyColor.withValues(alpha: 0.2)),

                  ListTile(
                    contentPadding: EdgeInsets.only(left: 10, right: 10),
                    leading: Image.asset(
                      'assets/visa_pay.png',
                      width: 50,
                      height: 50,
                    ),
                    title: Text(
                      'Visa •••• 9901',
                      style: TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'pay_backup_method'.tr,
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: greyColor,
                    ),
                  ),
                ],
              ),
            ),
            height(0.02),
            MyButton(
              label: ' Add New Method',
              onTap: () {},
              labelColor: mainThemeColor,
              buttonColor: Colors.transparent,
              borderColor: mainThemeColor,
            ),

            height(0.01),

            Row(
              children: [
                Image.asset('assets/check.png', width: 20, height: 20),

                width(0.02),

                SizedBox(
                  width: Get.width * 0.7,
                  child: Text(
                    'pay_secure_ssl'.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffA1A1A1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

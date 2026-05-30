import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/artist_withdraw.dart';
import 'package:artist/artist_bottom_bar/screen/Studio/transaction_history.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  List<_SalesData>? data;

  @override
  void initState() {
    super.initState();
    data = [
      _SalesData('0-4', 0, 150),
      _SalesData('5-9', 0, 350),
      _SalesData('10-14', 0, 500),
    ];
  }

  List<Map> transactionsList = [
    {'title': 'Ticket Sales', 'date': 'Feb 2', 'price': '+\$1,240'},
    {'title': 'Merch Drop', 'date': 'Feb 1', 'price': '+\$450'},
    {'title': 'Bank Payout', 'date': 'Jan 28', 'price': '-\$5,000'},
  ];

  List<Map> methodsList = [
    {
      'image': 'assets/chase_icon.png',
      'title': 'Chase Business',
      'subTitle': 'Checking •••• 4291',
    },
    {
      'image': 'assets/add_icon.png',
      'title': 'Add Method',
      'subTitle': 'Connect Stripe',
    },
  ];

  var _selected = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Revenue'),

      body: SingleChildScrollView(
        child: Padding(
          padding: myPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: blackColor,
                ),
              ),
              Text(
                'Financial Hub',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff737373),
                ),
              ),
              height(0.01),

              MyContainer(
                widget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/payment_icon2.png',
                          width: 30,
                          height: 30,
                        ),
                        Spacer(),
                        Text(
                          'Default',
                          style: TextStyle(
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    height(0.01),

                    Text(
                      '\$${userModel.value.user?.points ?? 0}',
                      style: TextStyle(
                        color: whiteColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    Text(
                      '',
                      style: TextStyle(
                        color: whiteColor.withValues(alpha: 0.3),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    MyButton(
                      label: 'Withdraw',
                      onTap: () {
                        Get.to(() => const ArtistWithdraw());
                      },
                      labelColor: whiteColor,
                    ),
                  ],
                ),
              ),
              height(0.02),
              Text(
                ' Revenue Streams',
                style: TextStyle(
                  color: blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              SfCartesianChart(
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                enableSideBySideSeriesPlacement: false,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLabelFormatter: (AxisLabelRenderDetails args) {
                    if (args.value < 0) {
                      return ChartAxisLabel(
                        args.value.abs().toString().replaceAll(
                          RegExp(r'[-.]0'),
                          '',
                        ),
                        args.textStyle,
                      );
                    }
                    return ChartAxisLabel(args.text, args.textStyle);
                  },
                ),
                onDataLabelRender: (dataLabelArgs) {
                  if (dataLabelArgs.text != null) {
                    double? yValue = double.tryParse(dataLabelArgs.text!);

                    if (yValue != null && yValue < 0) {
                      dataLabelArgs.text = yValue.abs().toString().replaceAll(
                        RegExp(r'[-.]0'),
                        '',
                      );
                    }
                  }
                },
                series: <CartesianSeries<_SalesData, String>>[
                  BarSeries<_SalesData, String>(
                    dataSource: data,
                    xValueMapper: (_SalesData sales, _) => sales.x,
                    yValueMapper: (_SalesData sales, _) => sales.y1,
                    name: 'Laki-Laki',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.middle,
                    ),
                  ),
                  BarSeries<_SalesData, String>(
                    dataSource: data,
                    xValueMapper: (_SalesData sales, _) => sales.x,
                    yValueMapper: (_SalesData sales, _) => sales.y2,
                    name: 'Prempuan',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.middle,
                    ),
                  ),
                ],
              ),

              height(0.01),

              Row(
                children: [
                  Image.asset(
                    'assets/clock.png',
                    width: 17,
                    color: mainThemeColor,
                  ),
                  width(0.02),
                  Text(
                    ' Transactions',
                    style: TextStyle(
                      color: blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  Spacer(),

                  GestureDetector(
                    onTap: () {
                      Get.to(() => TranssactinHistory());
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xff737373),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              height(0.01),
              ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return MyContainer(
                    padding: EdgeInsets.only(left: 15, right: 15),
                    widget: ListTile(
                      minTileHeight: 0,
                      contentPadding: EdgeInsets.all(0),
                      title: Text(
                        transactionsList[index]['title'],
                        style: TextStyle(
                          color: Get.isDarkMode ? whiteColor : blackColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        transactionsList[index]['date'],
                        style: TextStyle(
                          color: Color(0xffA1A1A1),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        transactionsList[index]['price'],
                        style: TextStyle(
                          color: Color(0xffA1A1A1),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return height(0.01);
                },
                itemCount: transactionsList.length,
              ),
              height(0.01),

              Row(
                children: [
                  Image.asset(
                    'assets/payout_icon.png',
                    width: 17,
                    color: mainThemeColor,
                  ),
                  width(0.02),
                  Text(
                    '  Payout Methods',
                    style: TextStyle(
                      color: Get.isDarkMode ? whiteColor : blackColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              height(0.01),

              ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selected = methodsList[index]['title'];
                      });
                    },
                    child: MyContainer(
                      border: BoxBorder.all(
                        color: Get.isDarkMode
                            ? methodsList[index]['title'] == _selected
                                  ? goldPrimary
                                  : greyColor.withValues(alpha: 0.2)
                            : methodsList[index]['title'] == _selected
                            ? mainThemeColor
                            : greyColor.withValues(alpha: 0.2),
                      ),
                      padding: EdgeInsets.all(10),
                      widget: ListTile(
                        minTileHeight: 0,
                        contentPadding: EdgeInsets.all(0),
                        leading: Container(
                          padding: EdgeInsets.all(15),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: methodsList[index]['title'] == _selected
                                ? Color(0xffFFFDF1)
                                : whiteColor,

                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Image.asset(
                            methodsList[index]['image'],
                            width: 20,
                            color: methodsList[index]['title'] == _selected
                                ? mainThemeColor
                                : greyColor,
                          ),
                        ),

                        title: Text(
                          methodsList[index]['title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Get.isDarkMode ? whiteColor : blackColor,
                          ),
                        ),
                        subtitle: Text(
                          methodsList[index]['subTitle'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff737373),
                          ),
                        ),

                        trailing: methodsList[index]['title'] == _selected
                            ? MyContainer(
                                noWidth: true,
                                padding: EdgeInsets.all(10),
                                color: Color(0xffDCFCE7),
                                border: BoxBorder.all(color: Color(0xff00A63E)),
                                widget: Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Color(0xff00A63E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return height(0.01);
                },

                itemCount: methodsList.length,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesData {
  _SalesData(this.x, this.y1, this.y2);

  final String x;
  final double? y1;
  final double? y2;
}

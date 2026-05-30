import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/packages_model.dart';
import 'package:artist/widgets/widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PointsStore extends StatefulWidget {
  const PointsStore({super.key, required this.packages});
  final List<Package> packages;

  @override
  State<PointsStore> createState() => _PointsStoreState();
}

class _PointsStoreState extends State<PointsStore> {
  final userController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.isDarkMode ? darkmodeColor : whiteColor,
      appBar: MyAppbar(title: 'Points Store'),
      body: SafeArea(
        child: widget.packages.isEmpty
            ? Center(child: Text('No Packages Available'))
            : SingleChildScrollView(
                padding: myPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: widget.packages.length,
                      itemBuilder: (context, index) {
                        final bundle = widget.packages[index];
                        return PointsCard(
                          points: bundle.points ?? 'N/A',
                          price: bundle.price ?? 'N/A',
                          isHighlighted: index == 0,
                          onTap: () async {
                            await myAlertDialog(
                              title: 'Buy Package',
                              content:
                                  'Are you sure you want to buy this package?',
                              onTap: () async {
                                Get.back();
                                await userController.purchasePackage(
                                  packageId: bundle.id.toString(),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    height(0.03),
                  ],
                ),
              ),
      ),
    );
  }
}

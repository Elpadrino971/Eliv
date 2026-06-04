import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    required this.width,
    this.radius = 12,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Get.isDarkMode ? cardDeep : Colors.grey[300]!,
      highlightColor:
          Get.isDarkMode ? const Color(0xff1C3350) : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Get.isDarkMode ? cardDeep : whiteColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(height: Get.height * 0.47, width: Get.width, radius: 0);
  }
}

class FeaturedArtistShimmer extends StatelessWidget {
  const FeaturedArtistShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => width(0.04),
        itemBuilder: (context, index) => Column(
          children: [
            const ShimmerBox(height: 70, width: 70, radius: 35),
            height(0.01),
            const ShimmerBox(height: 10, width: 50, radius: 5),
          ],
        ),
      ),
    );
  }
}

class EventCardShimmer extends StatelessWidget {
  const EventCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Get.height * 0.2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => width(0.02),
        itemBuilder: (context, index) => ShimmerBox(
          height: Get.height * 0.2,
          width: Get.width * 0.4,
          radius: 15,
        ),
      ),
    );
  }
}

class EventTileShimmer extends StatelessWidget {
  const EventTileShimmer({super.key, this.length = 3});
  final int length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Row(
            children: [
              const ShimmerBox(height: 80, width: 80, radius: 12),
              width(0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(height: 15, width: 150, radius: 5),
                    height(0.01),
                    const ShimmerBox(height: 12, width: 100, radius: 5),
                    height(0.01),
                    const ShimmerBox(height: 12, width: 200, radius: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ImageWidget extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Color? color;
  const ImageWidget({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      color: color,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade400,
        highlightColor: Colors.grey.shade300, //whiteColor,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: blackColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Image.asset(
        "assets/no_img.jpg",
        height: height,
        width: width,
        fit: BoxFit.cover,
      ),
      errorListener: (value) {
        myPrint(value);
      },
    );
  }
}

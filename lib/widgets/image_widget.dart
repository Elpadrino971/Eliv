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
  final String errorAsset;
  const ImageWidget({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit,
    this.color,
    this.errorAsset = "assets/no_img.jpg",
  });

  /// Si une URL complète a été collée DANS le champ (ex. cover_image =
  /// "https://photo.com/x.jpg"), les appelants produisent
  /// "https://api.../events/covers/https://photo.com/x.jpg".
  /// On détecte ce cas (2e "://") et on garde uniquement l'URL réelle.
  /// Sinon (simple nom de fichier), on renvoie l'URL telle quelle.
  String _resolve(String u) {
    final firstScheme = u.indexOf('://');
    if (firstScheme == -1) return u;
    final secondScheme = u.indexOf('://', firstScheme + 3);
    if (secondScheme != -1) {
      final start = u.lastIndexOf('http', secondScheme);
      if (start > 0) return u.substring(start);
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _resolve(url),
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
            color: cardDeep,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Image.asset(
        errorAsset,
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

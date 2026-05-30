import 'dart:math';
import 'package:flutter/material.dart';

class HeartAnimationOverlay extends StatefulWidget {
  const HeartAnimationOverlay({super.key});

  @override
  HeartAnimationOverlayState createState() => HeartAnimationOverlayState();
}

class HeartAnimationOverlayState extends State<HeartAnimationOverlay> {
  final List<Widget> _hearts = [];

  void addHeart() {
    final random = Random();
    final double left = random.nextDouble() * 300; // random horizontal position

    final heart = Positioned(
      bottom: 0,
      left: left,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: -400),
        duration: const Duration(seconds: 2),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value),
            child: Opacity(
              opacity: 1 - (-value / 400),
              child: const Icon(Icons.favorite, color: Colors.pink, size: 30),
            ),
          );
        },
      ),
    );

    if (mounted) {
      setState(() {
        _hearts.add(heart);
      });
    }

    // Remove the heart after animation completes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hearts.remove(heart);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _hearts,
    );
  }
}

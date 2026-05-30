import 'package:flutter/material.dart';

class AppTextTheme {
  static TextTheme appTextTheme() => const TextTheme(
    // Display styles (largest text)
    displayLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 36,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),

    // Body styles (DEFAULT for most Text widgets)
    bodyLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black87,
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black54,
      fontSize: 12,
    ),

    // Label styles (buttons, chips)
    labelLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}

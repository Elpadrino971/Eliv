import 'package:artist/Configs/app_text_theme.dart';
import 'package:artist/Global/colors.dart';
import 'package:flutter/material.dart';


class AppThemeData {
  static Color? get textGreyColor => null;

  /// LIGHT THEME - COMPLETE CONFIGURATION
  static ThemeData lightThemeData() => ThemeData(
    fontFamily: 'Montserrat',
    scaffoldBackgroundColor: whiteColor,
    primaryColor: mainThemeColor,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: AppThemeData.colorScheme(),

    // COMPLETE TEXT THEME - ALL text widgets will use these colors
    textTheme: AppTextTheme.appTextTheme(),

    // App Bar Theme
    appBarTheme: AppThemeData.appBarTheme(),

    // Elevated Button Theme
    elevatedButtonTheme: AppThemeData.elevatedButtonTheme(),

    // Floating Action Button Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: mainThemeColor,
      foregroundColor: whiteColor,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: AppThemeData.bottomNavigationBarTheme(),

    // Icon Theme
    iconTheme: const IconThemeData(color: Colors.black),

    // Card Theme
    cardTheme: AppThemeData.cardTheme(),
  );

  /// DARK THEME - COMPLETE CONFIGURATION
  static ThemeData appDarkThemeData() => ThemeData(
    fontFamily: 'Montserrat',
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    primaryColor: mainThemeColor,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: mainThemeColor,
      secondary: mainThemeColor,
      surface: mainThemeColor,
      onSurface: whiteColor,
    ),

    // COMPLETE TEXT THEME FOR DARK MODE
    textTheme: const TextTheme(
      // Display styles (largest text)
      displayLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),

      // Body styles (DEFAULT for most Text widgets)
      bodyLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 12,
      ),

      // Label styles (buttons, chips)
      labelLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldBackgroundColor,
      foregroundColor: whiteColor,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Montserrat',
        color: whiteColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: mainThemeColor,
        foregroundColor: whiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: mainThemeColor,
      foregroundColor: whiteColor,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: mainThemeColor,
      selectedItemColor: whiteColor,
      // ignore: deprecated_member_use
      unselectedItemColor: whiteColor.withOpacity(0.6),
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 10,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 10,
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: whiteColor),

    // Card Theme
    cardTheme: CardThemeData(
      color: mainThemeColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static BottomNavigationBarThemeData bottomNavigationBarTheme() =>
      BottomNavigationBarThemeData(
        backgroundColor: whiteColor,
        selectedItemColor: mainThemeColor,
        unselectedItemColor: textGreyColor,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
        ),
      );

  static ElevatedButtonThemeData elevatedButtonTheme() =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mainThemeColor,
          foregroundColor: whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  static AppBarTheme appBarTheme() => const AppBarTheme(
    backgroundColor: whiteColor,
    foregroundColor: Colors.black,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );

  static ColorScheme colorScheme() => const ColorScheme.light(
    primary: mainThemeColor,
    secondary: mainThemeColor,
    surface: whiteColor,
    onSurface: Colors.black,
  );

  static CardThemeData cardTheme() => CardThemeData(
    color: whiteColor,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

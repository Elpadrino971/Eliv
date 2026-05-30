import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeService {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  bool _readIsDarkModeFromStorage() {
    return _box.read(_key) ??
        true; // default to dark (change if you want light default)
  }

  ThemeMode getThemeMode() {
    return _readIsDarkModeFromStorage() ? ThemeMode.dark : ThemeMode.light;
  }

  bool isDarkMode() => _readIsDarkModeFromStorage();

  void saveIsDarkMode(bool isDark) => _box.write(_key, isDark);

  /// Toggles and applies the theme immediately
  void switchTheme() {
    final newIsDark = !_readIsDarkModeFromStorage();
    saveIsDarkMode(newIsDark);
    Get.changeThemeMode(newIsDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// Set explicitly
  void setTheme(bool isDark) {
    saveIsDarkMode(isDark);
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}

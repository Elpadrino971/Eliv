import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeService {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  // VYBZZZ : identite visuelle unique (premium bleu nuit + or).
  // L'app est verrouillee en mode sombre ; le basculement clair est neutralise
  // pour garantir un theme coherent sur tous les ecrans.
  ThemeMode getThemeMode() => ThemeMode.dark;

  bool isDarkMode() => true;

  void saveIsDarkMode(bool isDark) {
    // Verrouille : on conserve toujours le mode sombre.
    _box.write(_key, true);
  }

  /// Conserve le mode sombre (basculement desactive).
  void switchTheme() {
    Get.changeThemeMode(ThemeMode.dark);
  }

  /// Conserve le mode sombre (basculement desactive).
  void setTheme(bool isDark) {
    Get.changeThemeMode(ThemeMode.dark);
  }
}

import 'package:get/get.dart';
import '../services/theme_service.dart';

class ThemeController extends GetxController {
  final ThemeService _service = ThemeService();
  final isDark = true.obs;

  @override
  void onInit() {
    super.onInit();
    isDark.value = _service.isDarkMode();
  }

  void toggleTheme(bool value) {
    isDark.value = value;
    _service.setTheme(value);
  }

  void switchTheme() {
    _service.switchTheme();
    isDark.value = _service.isDarkMode();
  }
}

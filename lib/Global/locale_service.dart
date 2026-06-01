import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Une langue supportee par l'app (code ISO + nom natif + drapeau).
class AppLanguage {
  final String code; // ex: 'fr'
  final String name; // nom dans la langue elle-meme, ex: 'Français'
  final String flag; // emoji drapeau
  const AppLanguage(this.code, this.name, this.flag);
}

/// Gere la langue de l'app : liste supportee, persistance (get_storage),
/// locale initiale (langue du telephone si supportee, sinon anglais) et
/// changement de langue a chaud.
class LocaleService {
  LocaleService._();

  static final GetStorage _box = GetStorage();
  static const String _key = 'app_locale';

  /// Langues officiellement supportees (ordre = ordre d'affichage).
  /// Ajouter une langue ici + une map dans AppTranslations suffit.
  static const List<AppLanguage> supported = <AppLanguage>[
    AppLanguage('fr', 'Français', '🇫🇷'),
    AppLanguage('en', 'English', '🇬🇧'),
    AppLanguage('es', 'Español', '🇪🇸'),
    AppLanguage('it', 'Italiano', '🇮🇹'),
    AppLanguage('de', 'Deutsch', '🇩🇪'),
    AppLanguage('pt', 'Português', '🇵🇹'),
    AppLanguage('zh', '中文', '🇨🇳'),
    AppLanguage('ko', '한국어', '🇰🇷'),
    AppLanguage('ja', '日本語', '🇯🇵'),
  ];

  static const Locale fallback = Locale('en');

  static bool _isSupported(String code) =>
      supported.any((l) => l.code == code);

  /// Code de langue enregistre par l'utilisateur (null si jamais choisi).
  static String? get savedCode => _box.read(_key);

  /// Locale a utiliser au demarrage de l'app.
  static Locale get initialLocale {
    final saved = savedCode;
    if (saved != null && _isSupported(saved)) return Locale(saved);

    // Sinon : langue du systeme si on la supporte, sinon anglais.
    final device =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (_isSupported(device)) return Locale(device);
    return fallback;
  }

  /// Code de langue actuellement actif.
  static String get currentCode =>
      Get.locale?.languageCode ?? initialLocale.languageCode;

  /// Change la langue a chaud et la persiste.
  static Future<void> setLocale(String code) async {
    if (!_isSupported(code)) return;
    await _box.write(_key, code);
    Get.updateLocale(Locale(code));
  }
}

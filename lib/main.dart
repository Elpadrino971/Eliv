import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/locale_service.dart';
import 'package:artist/Global/translations/app_translations.dart';
import 'package:artist/OnBoarding/onboarding_1.dart';
import 'package:artist/firebase_options.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/spalash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GetStorage.init();
  // Donnees de formatage des dates pour toutes les langues (mois/jours
  // localises selon la langue choisie).
  await initializeDateFormatting();
  await SubscriptionController.init();
  await PushNotificationSystem().setup();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Thème premium unique (bleu nuit + or) applique a TOUS les ecrans.
    final premiumTheme = _buildPremiumTheme();

    return SafeArea(
      top: false,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        // i18n : dictionnaire, langue initiale (choix utilisateur > systeme >
        // anglais) et langue de repli.
        translations: AppTranslations(),
        locale: LocaleService.initialLocale,
        fallbackLocale: LocaleService.fallback,
        // Delegues officiels Flutter : RTL automatique (arabe) + labels
        // Material/Cupertino localises (date pickers, etc.).
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleService.supportedLocales,
        // Le meme theme pour light/dark + themeMode force => une seule
        // identite visuelle, quel que soit le reglage systeme ou stocke.
        theme: premiumTheme,
        darkTheme: premiumTheme,
        themeMode: ThemeMode.dark,
        home: (box.read('init') == null)
            ? const Onboarding1()
            : const SpalashScreen(),
      ),
    );
  }

  ThemeData _buildPremiumTheme() {
    final base = ThemeData(brightness: Brightness.dark, fontFamily: AppFonts.body);
    return base.copyWith(
      scaffoldBackgroundColor: midnightPrimary,
      primaryColor: goldPrimary,
      canvasColor: midnightPrimary,
      colorScheme: const ColorScheme.dark(
        primary: goldPrimary,
        secondary: goldSecondary,
        surface: midnightSecondary,
        onPrimary: midnightPrimary,
        onSurface: ivory,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: midnightPrimary,
        foregroundColor: ivory,
        surfaceTintColor: midnightPrimary,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(color: ivory),
      textTheme: base.textTheme.apply(
        fontFamily: AppFonts.body,
        bodyColor: ivory,
        displayColor: ivory,
      ),
    );
  }
}

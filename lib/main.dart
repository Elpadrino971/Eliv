import 'dart:async';

import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Controllers/event_controller.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/locale_service.dart';
import 'package:artist/Global/translations/app_translations.dart';
import 'package:artist/firebase_options.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/spalash_screen.dart';
import 'package:artist/widgets/mini_player.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App verrouillee en portrait (design portrait-first) -> evite les
  // debordements en paysage.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await GetStorage.init();
  // Donnees de formatage des dates pour toutes les langues (mois/jours
  // localises selon la langue choisie).
  await initializeDateFormatting();

  // Services tiers protégés : si l'un échoue (Firebase iOS non configuré,
  // clé RevenueCat invalide, push indisponible…), l'app DÉMARRE quand même.
  // Sans ces try/catch, une erreur ici crashait l'app avant l'affichage.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('⚠️ Firebase init échouée (app continue): $e');
  }
  try {
    await SubscriptionController.init();
  } catch (e) {
    debugPrint('⚠️ RevenueCat init échouée (app continue): $e');
  }
  try {
    await PushNotificationSystem().setup();
  } catch (e) {
    debugPrint('⚠️ Push setup échouée (app continue): $e');
  }

  // Contrôleurs globaux disponibles dès le PREMIER écran. Avant, seul
  // l'Accueil enregistrait EventController : l'onglet Live (premier écran
  // après le splash / la connexion) faisait Get.find<EventController>() sans
  // qu'il existe -> exception -> page grise au lancement. `permanent` :
  // jamais supprimés par GetX. Les Get.put() restants dans les écrans
  // renvoient simplement ces instances.
  final authController = Get.put(AuthController(), permanent: true);
  Get.put(EventController(), permanent: true);
  Get.put(SubscriptionController(), permanent: true);
  // Textes légaux (CGU / confidentialité) demandés dès le démarrage, sans
  // bloquer : ils sont ainsi prêts avant l'écran d'inscription.
  unawaited(authController.getSettings());

  // Hors version store (debug/profile) : un écran qui plante affiche le
  // message d'erreur au lieu de la page grise muette, et l'erreur est écrite
  // dans le terminal même sans débogueur attaché (utile en Wi-Fi).
  if (!kReleaseMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // ignore: avoid_print
      print('VYBZZZ_ERROR ${details.exceptionAsString()}\n${details.stack}');
    };
    ErrorWidget.builder = (details) => Material(
          color: const Color(0xFF7A0000),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${details.exceptionAsString()}\n\n${details.stack}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
  }

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
        // Monte le mini-lecteur flottant (façon YouTube) AU-DESSUS de tous les
        // écrans, pour qu'il survive aux changements de page.
        builder: (context, child) =>
            MiniPlayerHost(child: child ?? const SizedBox.shrink()),
        // Pas d'écrans de présentation au premier lancement : chaque écran
        // avant le contenu fait perdre des utilisateurs. Splash -> Live + Feed
        // (ou connexion s'il n'y a pas de compte).
        home: const SpalashScreen(),
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

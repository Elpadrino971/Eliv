import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/OnBoarding/onboarding_1.dart';
import 'package:artist/firebase_options.dart';
import 'package:artist/services/push_notification.dart';
import 'package:artist/spalash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GetStorage.init();
  await SubscriptionController.init();
  await PushNotificationSystem().setup();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = box.read(themeKey) ?? true;

    return SafeArea(
      top: false,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          fontFamily: 'Google Sans',
          scaffoldBackgroundColor: whiteColor,
          appBarTheme: AppBarTheme(
            backgroundColor: whiteColor,
            foregroundColor: blackColor,
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Google Sans',
          scaffoldBackgroundColor: midnightPrimary,
          primaryColor: goldPrimary,
          colorScheme: const ColorScheme.dark(
            primary: goldPrimary,
            secondary: goldSecondary,
            surface: midnightSecondary,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: midnightPrimary,
            foregroundColor: ivory,
            surfaceTintColor: midnightPrimary,
            elevation: 0,
          ),
        ),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: (box.read('init') == null)
            ? const Onboarding1()
            : const SpalashScreen(),
      ),
    );
  }
}

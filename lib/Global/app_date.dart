import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// ────────────────────────────────────────────────────────────────────────
/// VybzzZ — Affichage des dates/heures
///
/// Regle d'or : un horaire d'event est stocke en UTC cote serveur ; il doit
/// TOUJOURS etre affiche dans le fuseau du SPECTATEUR. Ce helper applique
/// systematiquement `.toLocal()` + un format localise selon la langue active.
///
///   AppDate.dayDate(e.startDateTime)   -> "Sam. 26 juil." (selon la langue)
///   AppDate.time(e.startDateTime)      -> "8:00 PM"  (heure locale du tel)
///   AppDate.timeWithZone(...)          -> "3:00 PM (GMT-3)"  (Guyane)
///
/// Si le serveur envoie une heure "nue" (sans Z), `.toLocal()` est un no-op :
/// aucune regression par rapport a l'ancien affichage.
/// ────────────────────────────────────────────────────────────────────────
class AppDate {
  AppDate._();

  static String _locale() => Get.locale?.languageCode ?? 'en';

  /// Formate une date avec un pattern intl libre, en heure LOCALE + langue active.
  static String format(DateTime? dt, String pattern) {
    if (dt == null) return '';
    return DateFormat(pattern, _locale()).format(dt.toLocal());
  }

  /// "Sat, Jul 26" (localise)
  static String dayDate(DateTime? dt) => format(dt, 'EEE, MMM dd');

  /// "MMM dd, yyyy" (localise)
  static String fullDate(DateTime? dt) => format(dt, 'MMM dd, yyyy');

  /// "8:00 PM" (heure locale du spectateur)
  static String time(DateTime? dt) => format(dt, 'h:mm a');

  /// Decalage GMT du fuseau du spectateur, ex: "GMT+2" / "GMT-3".
  static String gmtLabel([DateTime? dt]) {
    final off = (dt?.toLocal() ?? DateTime.now()).timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs();
    final m = off.inMinutes.abs() % 60;
    return m == 0
        ? 'GMT$sign$h'
        : 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
  }

  /// "8:00 PM (GMT+2)" — heure locale + fuseau explicite (leve l'ambiguite).
  static String timeWithZone(DateTime? dt) {
    if (dt == null) return '';
    return '${time(dt)} (${gmtLabel(dt)})';
  }
}

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

  static bool get _en => _locale() == 'en';

  /// "Sat, Jul 26" en anglais, "sam. 26 juil." ailleurs (ordre jour-mois).
  static String dayDate(DateTime? dt) =>
      format(dt, _en ? 'EEE, MMM d' : 'EEE d MMM');

  /// "Sun, Oct 4, 2026" en anglais, "dim. 4 oct. 2026" ailleurs.
  static String fullDate(DateTime? dt) =>
      format(dt, _en ? 'EEE, MMM d, yyyy' : 'EEE d MMM yyyy');

  /// "8:00 PM" en anglais, "20:00" ailleurs (heure locale du spectateur).
  static String time(DateTime? dt) => format(dt, _en ? 'h:mm a' : 'HH:mm');

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

  /// COTE EMISSION (creation d'event) : prend une date "yyyy-MM-dd" et une heure
  /// "HH:mm:ss" saisies dans le fuseau LOCAL de l'artiste, et renvoie une chaine
  /// ISO8601 en UTC avec 'Z' (ex: "2026-07-26T18:00:00Z" pour 20h a Paris).
  /// C'est ce 'Z' qui permet ensuite a chaque spectateur de voir l'heure dans
  /// SON fuseau via .toLocal(). Si la saisie est invalide, on retombe sur
  /// l'ancien format "date heure" (aucune casse).
  static String localPartsToUtcIso(String date, String time) {
    if (date.isEmpty || time.isEmpty) return '$date $time'.trim();
    try {
      final utc = DateTime.parse('$date $time').toUtc();
      return DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(utc);
    } catch (_) {
      return '$date $time';
    }
  }
}

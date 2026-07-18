/// AppID uniquement (public, pas un secret). Le token de connexion (qui
/// remplace l'ancien `appSign`) est désormais généré côté serveur — voir
/// `ZegoController.fetchZegoToken()` + POST /api/live/zego-token. L'AppSign
/// ne doit JAMAIS revenir ici : c'est le secret maître du compte Zego, et le
/// laisser dans l'app compilée permet à quiconque la décompile de générer
/// des tokens illimités sur ton compte (facturation frauduleuse).
class ZegoCloudKeys {
  static const int appId = 266313543;
}

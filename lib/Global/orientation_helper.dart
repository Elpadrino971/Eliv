import 'package:flutter/services.dart';

/// Force la rotation de l'écran via du code natif iOS (canal 'vybzzz/orientation'),
/// car sur iOS 16+ `SystemChrome.setPreferredOrientations` ne pivote plus
/// l'interface (l'API iOS sous-jacente est dépréciée / inopérante). Sur Android,
/// SystemChrome suffit et le canal natif est simplement ignoré.
class OrientationHelper {
  static const MethodChannel _channel = MethodChannel('vybzzz/orientation');

  /// Bascule l'app en paysage (plein écran clip, façon Netflix/YouTube).
  static Future<void> forceLandscape() async {
    // Android + iOS < 16 : SystemChrome fonctionne.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // iOS 16+ : rotation réelle via l'API native (no-op ailleurs).
    try {
      await _channel.invokeMethod('landscape');
    } catch (_) {}
  }

  /// Restaure le portrait à la fermeture du clip.
  static Future<void> resetPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    try {
      await _channel.invokeMethod('portrait');
    } catch (_) {}
  }
}

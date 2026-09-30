import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Protection des concerts contre la capture d'écran.
///
/// - Android : FLAG_SECURE pendant un concert -> captures et enregistrements
///   d'écran noirs (natif, MainActivity.kt).
/// - iOS : Apple ne permet pas de bloquer une capture d'écran ; l'app est en
///   revanche prévenue quand l'écran est enregistré ou recopié, et
///   [CaptureShield] masque alors la vidéo en noir tant que ça dure.
///
/// [protectScreen] se compte : deux écrans de concert empilés (live puis
/// mini-lecteur) ne retirent la protection qu'à la fermeture du dernier.
const MethodChannel _channel = MethodChannel('vybzzz/screen');

final ValueNotifier<bool> screenCaptured = ValueNotifier<bool>(false);

int _depth = 0;
bool _listening = false;

void _listen() {
  if (_listening) return;
  _listening = true;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'captured') {
      screenCaptured.value = _depth > 0 && call.arguments == true;
    }
  });
}

Future<void> protectScreen(bool on) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  _listen();
  _depth += on ? 1 : -1;
  if (_depth < 0) _depth = 0;
  try {
    final captured = await _channel.invokeMethod<bool>('secure', {
      'on': _depth > 0,
    });
    screenCaptured.value = _depth > 0 && captured == true;
  } catch (_) {
    // Canal absent (ancienne version native) : pas de protection, pas de plantage.
  }
}

/// Recouvre [child] d'un écran noir pendant un enregistrement d'écran (iOS).
class CaptureShield extends StatelessWidget {
  const CaptureShield({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: screenCaptured,
            builder: (context, captured, _) {
              if (!captured) return const IgnorePointer(child: SizedBox.shrink());
              return const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      "Enregistrement de l'écran détecté.\nLe concert est masqué pendant l'enregistrement.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

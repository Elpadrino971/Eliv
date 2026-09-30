import 'package:flutter/material.dart';

/// Resserre l'interligne du texte des écrans Zego (liste « Audience », etc.).
///
/// Zego place chaque nom dans une case de hauteur fixe pensée pour la police
/// système ; avec la police de l'app, plus haute, le bas des lettres était
/// coupé (« riaht », « D I Wilson »). Le thème est capturé par les feuilles que
/// Zego ouvre depuis le live (InheritedTheme), donc la correction les suit.
class ZegoTextFix extends StatelessWidget {
  const ZegoTextFix({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    TextStyle? tight(TextStyle? s) => s?.copyWith(height: 1.0);
    return Theme(
      data: theme.copyWith(
        textTheme: t.copyWith(
          bodySmall: tight(t.bodySmall),
          bodyMedium: tight(t.bodyMedium),
          bodyLarge: tight(t.bodyLarge),
          labelSmall: tight(t.labelSmall),
          labelMedium: tight(t.labelMedium),
          labelLarge: tight(t.labelLarge),
          titleSmall: tight(t.titleSmall),
          titleMedium: tight(t.titleMedium),
          titleLarge: tight(t.titleLarge),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(height: 1.0),
        child: child,
      ),
    );
  }
}

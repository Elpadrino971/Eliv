import 'package:artist/widgets/empty_state.dart';
import 'package:artist/widgets/my_appBar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Pas encore de vrai flux de notifications côté backend (aucun agrégateur
/// follows/cadeaux/billets n'existe) -> état vide honnête plutôt que les
/// notifications fictives d'origine (faux tips, faux "The Weeknd" a aimé
/// ton annonce...). À remplacer une fois l'endpoint construit.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'home_alerts'.tr),
      body: const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        subtitle: 'Likes, new followers and ticket updates will show up here.',
      ),
    );
  }
}

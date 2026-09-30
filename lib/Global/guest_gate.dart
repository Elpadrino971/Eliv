import 'dart:async';

import 'package:artist/Auth/create_acount.dart';
import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mode visiteur : l'app s'ouvre sans compte (feed, lives, concerts). Le
/// compte n'est demandé qu'au moment où une action en a besoin (rejoindre un
/// live, prendre une place, écrire, offrir un cadeau, suivre…), via
/// [requireAccount]. Demander un compte dès l'ouverture faisait fuir les gens
/// (et Apple refuse les apps qui l'exigent pour simplement regarder).

/// Vrai tant que personne n'est connecté.
bool get isGuest =>
    (userModel.value.token ?? '').isEmpty || userModel.value.user?.id == null;

Completer<bool>? _pendingGate;
String? _gateRoute;

/// Un écran attend-il qu'on se connecte pour reprendre son action ?
bool get hasPendingAccountGate => _pendingGate != null;

/// Appelée après une connexion / inscription réussie. Si un écran avait
/// demandé le compte, on revient dessus (l'action reprend) au lieu de
/// repartir sur le feed. Renvoie vrai dans ce cas.
bool completeAccountGate() {
  final gate = _pendingGate;
  if (gate == null) return false;
  final route = _gateRoute;
  _pendingGate = null;
  _gateRoute = null;
  Get.until((r) => r.settings.name == route || r.isFirst);
  if (!gate.isCompleted) gate.complete(true);
  return true;
}

/// Renvoie vrai si un compte est connecté, en le demandant d'abord si besoin.
/// Faux si la personne choisit « Plus tard » ou ferme l'écran.
Future<bool> requireAccount({String? reason}) async {
  if (!isGuest) return true;
  final choice = await Get.bottomSheet<String>(
    _AccountSheet(reason: reason),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  if (choice != 'signup' && choice != 'login') return false;
  // Une demande précédente restée sans suite est abandonnée.
  final previous = _pendingGate;
  if (previous != null && !previous.isCompleted) previous.complete(false);
  final gate = Completer<bool>();
  _pendingGate = gate;
  _gateRoute = Get.currentRoute;
  await Get.to(
    () => choice == 'login'
        ? const LoginScreen(closable: true)
        : const CreateAcount(closable: true),
  );
  // Écran fermé sans se connecter : l'action est annulée.
  if (identical(_pendingGate, gate) && !gate.isCompleted) {
    _pendingGate = null;
    _gateRoute = null;
    gate.complete(false);
  }
  return gate.future;
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: midnightSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        22 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'guest_title'.tr,
            style: const TextStyle(
              color: ivory,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason ?? 'guest_reason_default'.tr,
            style: const TextStyle(color: textMuted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Get.back(result: 'signup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: goldPrimary,
              foregroundColor: midnightPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'guest_create'.tr,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Get.back(result: 'login'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ivory,
              side: BorderSide(color: goldSecondary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'guest_login'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'guest_later'.tr,
              style: const TextStyle(color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder d'un onglet réservé aux comptes (billets, profil).
class GuestTabPlaceholder extends StatelessWidget {
  const GuestTabPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.onLoggedIn,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: goldPrimary, size: 54),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (await requireAccount(reason: text)) onLoggedIn?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldPrimary,
                    foregroundColor: midnightPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'guest_cta'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

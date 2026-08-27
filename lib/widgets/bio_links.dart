import 'package:artist/Global/colors.dart';
import 'package:artist/Models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liens en bio (façon TikTok) : contact + réseaux, sous forme de puces
/// cliquables. N'affiche que les liens renseignés. Sécurité : n'ouvre que des
/// URLs http(s) ou mailto (jamais de schéma exotique type javascript:).
class BioLinks extends StatelessWidget {
  const BioLinks({super.key, required this.user});

  final User? user;

  Future<void> _open(String raw, {bool email = false}) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    Uri? uri;
    if (email) {
      uri = Uri(scheme: 'mailto', path: value);
    } else {
      if (!value.startsWith('http://') && !value.startsWith('https://')) {
        value = 'https://$value';
      }
      uri = Uri.tryParse(value);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return;
      }
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _label(String url) {
    var s = url.trim().replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (s.length > 26) s = '${s.substring(0, 26)}…';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null) return const SizedBox.shrink();

    final chips = <Widget>[];
    void add(IconData icon, String? value, {bool email = false}) {
      if (value == null || value.trim().isEmpty) return;
      chips.add(_chip(
        icon,
        email ? value.trim() : _label(value),
        () => _open(value, email: email),
      ));
    }

    add(Icons.email_outlined, u.contactEmail, email: true);
    add(Icons.link_rounded, u.linkWebsite);
    add(Icons.camera_alt_outlined, u.linkInstagram);
    add(Icons.music_note_rounded, u.linkTiktok);
    add(Icons.play_circle_outline, u.linkYoutube);
    add(Icons.library_music_outlined, u.linkSpotify);

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardDeep,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: goldPrimary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: goldPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: ivory,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

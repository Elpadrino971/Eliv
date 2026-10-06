import 'package:artist/Global/colors.dart';
import 'package:artist/Models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// En-tête compact côté fan (salle d'attente et live) : petit avatar de
/// l'artiste, nom + point rouge « LIVE » discret, et titre du concert en
/// dessous (1 ligne). Se place SOUS la barre du haut de Zego (voir le
/// décalage de 54 px dans les écrans), dans l'esprit de l'écran artiste.
class LiveStreamTopBar extends StatelessWidget {
  const LiveStreamTopBar({super.key, required this.event, this.isLive = true});
  final Event event;

  /// Affiche le point rouge « LIVE » (faux en salle d'attente avant l'heure).
  final bool isLive;

  static const double _avatarSize = 28;

  Widget _fallbackAvatar() => Image.asset(
    'assets/artist_image2.png',
    width: _avatarSize,
    height: _avatarSize,
    fit: BoxFit.cover,
  );

  @override
  Widget build(BuildContext context) {
    final artistName = (event.artist?.artistName?.isNotEmpty ?? false)
        ? event.artist!.artistName!
        : (event.artist?.fullName ?? 'live_artist_name_fallback'.tr);
    final title = event.name ?? 'live_event_fallback'.tr;
    final avatar = event.artist?.profileImage ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    width: _avatarSize,
                    height: _avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _fallbackAvatar(),
                  )
                : _fallbackAvatar(),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ivory,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      const LiveDot(),
                    ],
                  ],
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur « en direct » discret : point rouge + « LIVE ».
class LiveDot extends StatelessWidget {
  const LiveDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: liveRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'live_badge'.tr,
          style: const TextStyle(
            color: ivory,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

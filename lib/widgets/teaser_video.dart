import 'dart:async';

import 'package:artist/Global/mux.dart';
import 'package:artist/Models/event_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// URL du teaser vidéo d'un concert (`teaser_url`), ou null si absent/vide.
String? teaserUrlOf(Event event) {
  final url = (event.teaserUrl ?? '').trim();
  return url.isEmpty ? null : url;
}

/// Miniature du teaser (`teaser_poster`, URL complète), ou null.
String? teaserPosterOf(Event event) {
  final url = (event.teaserPoster ?? '').trim();
  return url.startsWith('http') ? url : null;
}

/// ────────────────────────────────────────────────────────────────────────
/// Teaser vidéo d'un concert (champ `teaser_url` : HLS Mux court, 15–60 s,
/// souvent vertical) joué MUET, EN BOUCLE, SANS contrôles, à la place de
/// l'affiche (accueil, popup « À la une », bannières).
///
///  • [poster] (miniature, décodée à 720 px max) reste affiché tant que la
///    première image vidéo n'est pas prête, puis fondu enchaîné ;
///  • en cas d'erreur (réseau, flux indisponible) → [fallback] (l'affiche) ;
///  • HLS plafonné à 720p ([Mux.mobileHls]) : démarrage rapide, peu de data ;
///  • un SEUL teaser actif à la fois dans toute l'app : quand un nouveau
///    teaser devient visible, le précédent est mis en pause ET libéré
///    (décodeur + tampons HLS) — il reprend quand il redevient l'actif
///    (ex. fermeture du popup « À la une » au-dessus de l'accueil) ;
///  • libéré quand l'app passe en arrière-plan, quand une page opaque le
///    recouvre (TickerMode désactivé) ou quand il sort de l'écran (moins de
///    la moitié visible), et bien sûr au dispose.
///
/// Le widget remplit la place que lui donne son parent : à placer dans une
/// zone de taille finie (Stack `fit: StackFit.expand`, `Positioned.fill`,
/// `SizedBox`…).
/// ────────────────────────────────────────────────────────────────────────
class TeaserVideo extends StatefulWidget {
  const TeaserVideo({
    super.key,
    required this.url,
    this.poster,
    this.fit = BoxFit.contain,
    this.fallback,
    this.priority = 1,
  });

  /// Priorité quand plusieurs teasers sont à l'écran : le plus prioritaire
  /// joue (2 = « À la une » en haut de l'accueil / popup, 1 = les autres).
  final int priority;

  /// URL HLS du teaser (https://stream.mux.com/<id>.m3u8).
  final String url;

  /// Miniature affichée pendant le chargement (URL complète), ou null.
  final String? poster;

  /// Cadrage de la vidéo (et du poster) dans la zone.
  final BoxFit fit;

  /// Affiché en cas d'erreur de lecture (et pendant le chargement quand il
  /// n'y a pas de poster). Typiquement l'affiche du concert.
  final Widget? fallback;

  @override
  State<TeaserVideo> createState() => _TeaserVideoState();
}

/// Registre statique : garantit qu'un seul [TeaserVideo] lit (et possède un
/// lecteur) à la fois. Les teasers visibles s'y déclarent candidats ; le
/// dernier arrivé devient l'actif, le précédent est mis en pause et libéré.
/// Quand l'actif disparaît (dispose, hors écran), le candidat précédent
/// reprend.
abstract final class _TeaserRegistry {
  static final List<_TeaserVideoState> _candidates = <_TeaserVideoState>[];
  static _TeaserVideoState? _active;
  static bool _electionScheduled = false;

  static void want(_TeaserVideoState state) {
    _candidates.remove(state);
    _candidates.add(state);
    _scheduleElection();
  }

  static void unwant(_TeaserVideoState state) {
    _candidates.remove(state);
    _scheduleElection();
  }

  /// Élection différée (microtâche) : jamais de setState pendant un build
  /// ou un dispose (arbre verrouillé).
  static void _scheduleElection() {
    if (_electionScheduled) return;
    _electionScheduled = true;
    scheduleMicrotask(_elect);
  }

  static void _elect() {
    _electionScheduled = false;
    _candidates.removeWhere((s) => !s.mounted);
    _TeaserVideoState? next;
    for (final c in _candidates) {
      if (next == null || c.widget.priority >= next.widget.priority) next = c;
    }
    if (identical(next, _active)) return;
    final previous = _active;
    _active = next;
    previous?._suspend();
    next?._resume();
  }
}

class _TeaserVideoState extends State<TeaserVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  /// Vrai dès que la vidéo a réellement avancé (première image affichée).
  bool _firstFrame = false;

  /// Lecture impossible : on affiche le [TeaserVideo.fallback].
  bool _failed = false;

  /// Désigné par le registre comme LE teaser qui lit.
  bool _elected = false;

  /// App au premier plan (pas en arrière-plan / écran verrouillé).
  bool _foreground = true;

  /// Faux quand une page opaque recouvre ce widget (route en dessous).
  bool _tickerEnabled = true;

  /// Au moins la moitié du widget est à l'écran.
  bool _onScreen = false;

  /// Déclaré candidat auprès du registre.
  bool _wanting = false;

  bool _checkScheduled = false;
  bool _needsAttach = true;
  Size _screen = Size.zero;
  final List<ScrollPosition> _positions = <ScrollPosition>[];

  static const Duration _fade = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    // URL inutilisable (ex. simple nom de fichier) : directement le secours,
    // sans jamais prendre la place du teaser actif.
    _failed = !_isPlayable(widget.url);
  }

  static bool _isPlayable(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static bool _isForeground(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.of(context);
    _needsAttach = true;
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant TeaserVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // Nouveau teaser : on repart de zéro (le build suit, pas de setState).
      _release();
      _failed = !_isPlayable(widget.url);
      scheduleMicrotask(() {
        if (mounted) _ensureController();
      });
      _scheduleVisibilityCheck();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _isForeground(state);
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (!foreground) {
      // Arrière-plan : décodeur et tampons HLS libérés, poster réaffiché.
      if (_controller != null) {
        _release();
        if (mounted) setState(() {});
      }
    } else {
      _ensureController();
      _scheduleVisibilityCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachScrollables();
    _release();
    _wanting = false;
    _TeaserRegistry.unwant(this);
    super.dispose();
  }

  // ── Visibilité ─────────────────────────────────────────────────────────

  /// Vérification regroupée en fin de frame (build, défilement, retour au
  /// premier plan) : position réelle du widget à l'écran.
  void _scheduleVisibilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      if (_needsAttach) {
        _needsAttach = false;
        _attachScrollables();
      }
      _onScreen = _computeOnScreen();
      _syncWanting();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Écoute tous les défilements englobants (accueil vertical, carrousels
  /// horizontaux, PageView) pour réévaluer la visibilité.
  void _attachScrollables() {
    _detachScrollables();
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final position = scrollable.position;
      position.addListener(_scheduleVisibilityCheck);
      _positions.add(position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
  }

  void _detachScrollables() {
    for (final position in _positions) {
      position.removeListener(_scheduleVisibilityCheck);
    }
    _positions.clear();
  }

  bool _computeOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final size = box.size;
    if (size.isEmpty || _screen.isEmpty) return false;
    // Il suffit d'être posé à l'écran : on ne calcule plus un pourcentage de
    // visibilité (trop fragile selon les listes / popups qui englobent le
    // widget). La priorité du registre départage les teasers.
    return true;
  }

  void _syncWanting() {
    final want = _onScreen && _tickerEnabled && !_failed;
    if (want == _wanting) return;
    _wanting = want;
    if (want) {
      _TeaserRegistry.want(this);
    } else {
      _TeaserRegistry.unwant(this);
    }
  }

  // ── Registre ───────────────────────────────────────────────────────────

  /// Appelé par le registre : ce teaser devient l'actif.
  void _resume() {
    if (!mounted) return;
    _elected = true;
    _ensureController();
  }

  /// Appelé par le registre : un autre teaser prend la main (ou celui-ci
  /// n'est plus visible) -> pause + libération, retour au poster.
  void _suspend() {
    _elected = false;
    if (_controller == null) return;
    _release();
    if (mounted) setState(() {});
  }

  // ── Lecteur ────────────────────────────────────────────────────────────

  void _ensureController() {
    if (!mounted || !_elected || !_foreground || _failed) return;
    if (_controller != null) return;
    if (!_isPlayable(widget.url)) {
      _fail();
      return;
    }
    // HLS Mux plafonné à 720p (`?max_resolution=720p`).
    final uri = Uri.parse(Mux.mobileHls(widget.url.trim()));
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    _firstFrame = false;
    controller.addListener(_onControllerValue);
    controller.setLooping(true);
    controller.setVolume(0);
    controller
        .initialize()
        .then((_) {
          // Lecteur remplacé / libéré entre-temps : ne rien relancer.
          if (!mounted || !identical(_controller, controller)) return;
          controller
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() {});
        })
        .catchError((_) {
          if (!mounted || !identical(_controller, controller)) return;
          _fail();
        });
  }

  void _onControllerValue() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    if (value.hasError) {
      // Jamais de dispose pendant la notification des écouteurs.
      scheduleMicrotask(() {
        if (mounted && identical(_controller, controller)) _fail();
      });
      return;
    }
    if (!_firstFrame &&
        value.isInitialized &&
        value.position > Duration.zero) {
      setState(() => _firstFrame = true);
    }
  }

  void _fail() {
    _failed = true;
    _release();
    _syncWanting();
    if (mounted) setState(() {});
  }

  void _release() {
    final controller = _controller;
    _controller = null;
    _firstFrame = false;
    if (controller != null) {
      controller.removeListener(_onControllerValue);
      controller.dispose();
    }
  }

  // ── Rendu ──────────────────────────────────────────────────────────────

  Widget? _poster() {
    final url = (widget.poster ?? '').trim();
    if (url.isEmpty) return null;
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      // Miniature décodée à 720 px max (écran de téléphone, mémoire légère).
      memCacheWidth: 720,
      placeholder: (_, __) => widget.fallback ?? const SizedBox.shrink(),
      errorWidget: (_, __, ___) => widget.fallback ?? const SizedBox.shrink(),
    );
  }

  Widget _video(VideoPlayerController controller) {
    final size = controller.value.size;
    final w = size.width > 0 ? size.width : 9.0;
    final h = size.height > 0 ? size.height : 16.0;
    return FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: w, height: h, child: VideoPlayer(controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _screen = MediaQuery.sizeOf(context);
    _scheduleVisibilityCheck();

    if (_failed) {
      return widget.fallback ?? _poster() ?? const SizedBox.shrink();
    }

    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;
    final showVideo = initialized && _firstFrame;
    final poster = _poster() ?? widget.fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          AnimatedOpacity(
            opacity: showVideo ? 0 : 1,
            duration: _fade,
            child: poster,
          ),
        if (initialized)
          AnimatedOpacity(
            opacity: showVideo ? 1 : 0,
            duration: _fade,
            curve: Curves.easeIn,
            child: _video(controller!),
          ),
      ],
    );
  }
}

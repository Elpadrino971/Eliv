import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/widgets/featured_event_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class SpalashScreen extends StatefulWidget {
  const SpalashScreen({super.key});

  @override
  State<SpalashScreen> createState() => _SpalashScreenState();
}

class _SpalashScreenState extends State<SpalashScreen>
    with TickerProviderStateMixin {
  // Logo : démarre petit -> grandit
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0.25, end: 1.0).animate(
    CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
    ),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _introController,
    curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
  );
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _introController,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  // Paillettes dorées + halo qui respire
  late final AnimationController _sparkleController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Flash de transition (or -> blanc) à la validation
  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Fond d'écran / animation personnalisés depuis l'admin (facultatif -> repli
  // sur les assets locaux si rien n'est configuré ou si le réseau est lent).
  String? _bgImageUrl;
  String? _logoUrl;
  Color _accent = goldPrimary; // couleur des écritures principales (admin)
  double _overlayOpacity = 0; // voile de contraste sur le fond (0..0.85)
  String _animationStyle = 'sparkles';
  VideoPlayerController? _videoController;

  // ── Relance douce ──
  // iOS tue l'app suspendue (mémoire/inactivité) : sans ceci, chaque retour
  // rejouait le splash complet + « glisser pour entrer ». Si un utilisateur
  // est connecté et que l'app a été utilisée il y a moins de 12 h
  // (canSoftRelaunch), on affiche seulement le logo ~700 ms puis on ramène
  // directement sur le dernier onglet ouvert.
  late final bool _soft = canSoftRelaunch();
  Timer? _softTimer;
  static const Duration _softLogoDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    if (_soft) {
      // Logo seul (fondu + zoom courts) ; pas d'appel splash-settings ni de
      // vidéo de fond : rien à charger, on repart tout de suite.
      _introController.duration = _softLogoDuration;
      _introController.forward();
      _softTimer = Timer(_softLogoDuration, _softEnter);
    } else {
      _introController.forward();
      unawaited(_loadSplashConfig());
    }
    // Le feed « Pour toi » (premier écran après le splash) se charge pendant
    // l'animation, pour être prêt à l'arrivée sur l'onglet Live.
    unawaited(preloadLiveFeed());
    // Concert « à la une » (popup après le splash) : l'appel part dès
    // maintenant pour que le popup s'affiche sans délai à l'arrivée.
    unawaited(prefetchFeaturedEvent());
  }

  /// Recharge la session locale (`box['user']`) et l'identité RevenueCat.
  /// Renvoie vrai si un utilisateur est connecté.
  bool _restoreSession() {
    final hasUser = box.read('user') != null;
    if (hasUser) {
      userModel.value = UserModel.fromJson(box.read('user'));
      final id = userModel.value.user?.id;
      if (id != null) unawaited(SubscriptionController.syncIdentity(id));
    }
    return hasUser;
  }

  /// Relance douce : retour direct sur le dernier onglet (Live par défaut),
  /// sans geste. Le popup « À la une » garde sa propre règle (une fois par
  /// session / fermé aujourd'hui).
  void _softEnter() {
    if (!mounted) return;
    if (!_restoreSession()) {
      // Session disparue entre-temps : parcours normal.
      Get.offAll(() => LoginScreen());
      return;
    }
    Get.offAll(() => MyBottomBar(index: readLastTab() ?? 2));
    unawaited(showFeaturedEventIfAny());
  }

  Future<void> _loadSplashConfig() async {
    try {
      final res = await http
          .get(Uri.parse('${APIs.mainIP}/api/splash-settings'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return;
      final data = (jsonDecode(res.body)?['data'] ?? {}) as Map;
      final videoUrl = (data['background_video'] as String?)?.trim();
      final imageUrl = (data['background_image'] as String?)?.trim();
      final logoUrl = (data['logo_image'] as String?)?.trim();
      final textColor = (data['text_color'] as String?)?.trim();
      final overlayRaw = data['overlay'];
      final style = (data['animation_style'] as String?)?.trim();

      if (!mounted) return;
      setState(() {
        if (style != null && style.isNotEmpty) _animationStyle = style;
        if (imageUrl != null && imageUrl.isNotEmpty) _bgImageUrl = imageUrl;
        if (logoUrl != null && logoUrl.isNotEmpty) _logoUrl = logoUrl;
        if (textColor != null && textColor.isNotEmpty) _accent = _parseColor(textColor, goldPrimary);
        final ov = overlayRaw is num ? overlayRaw.toDouble() : double.tryParse('${overlayRaw ?? ''}');
        if (ov != null) _overlayOpacity = (ov / 100).clamp(0.0, 0.85);
      });

      if (videoUrl != null && videoUrl.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await controller.initialize();
        if (!mounted) {
          unawaited(controller.dispose());
          return;
        }
        await controller.setLooping(true);
        await controller.setVolume(0);
        unawaited(controller.play());
        setState(() => _videoController = controller);
      }
    } catch (e) {
      // Silencieux : la page de lancement retombe sur ses assets locaux.
      myPrint('splash-settings: $e');
    }
  }

  Widget _localBackgroundFallback() {
    return Image.asset(
      'assets/launch_bg.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [midnightSecondary, midnightPrimary],
          ),
        ),
      ),
    );
  }

  Widget _background() {
    final video = _videoController;
    if (video != null && video.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }
    if (_bgImageUrl != null && _bgImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _bgImageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _localBackgroundFallback(),
        errorWidget: (_, __, ___) => _localBackgroundFallback(),
      );
    }
    return _localBackgroundFallback();
  }

  // Parse une couleur hex "#RRGGBB" (ou "RRGGBB") venue de l'admin.
  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  // Logo emblème : image configurée dans l'admin (réseau) si présente, sinon
  // l'asset local, sinon le texte "VybzzZ". Comme le fond -> modifiable depuis
  // le VPS/admin, sans nouvelle version de l'app.
  Widget _localLogo(double w, double h) {
    return Image.asset(
      'assets/launch_logo.png',
      width: w * 0.80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Padding(
        padding: EdgeInsets.symmetric(vertical: h * 0.12),
        child: Text(
          'VybzzZ',
          style: TextStyle(
            fontFamily: AppFonts.logo,
            color: _accent,
            fontSize: 46,
            fontWeight: FontWeight.w600,
            letterSpacing: 6,
          ),
        ),
      ),
    );
  }

  Widget _logo(double w, double h) {
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _logoUrl!,
        width: w * 0.80,
        fit: BoxFit.contain,
        placeholder: (_, __) => _localLogo(w, h),
        errorWidget: (_, __, ___) => _localLogo(w, h),
      );
    }
    return _localLogo(w, h);
  }

  // ── Effets animés de la page de lancement ────────────────────────────────
  // Chaque style est piloté depuis l'admin (champ `animation_style`). Le
  // backend peut renvoyer un style "de saison" (ex. halloween) automatiquement.
  List<Widget> _effectLayers(double w, double h) {
    switch (_animationStyle) {
      case 'none':
        return const [];
      case 'fade':
        return [_breathingHalo(w)];
      case 'liquid':
        return [_liquidLayer()];
      case 'equalizer':
        return [
          _breathingHalo(w),
          _paintedLayer((p) => _EqualizerPainter(progress: p)),
        ];
      case 'spotlights':
        return [
          _paintedLayer((p) => _SpotlightPainter(progress: p)),
          _breathingHalo(w),
        ];
      case 'bokeh':
        return [_paintedLayer((p) => _BokehPainter(progress: p))];
      case 'halloween':
        return [
          _breathingHalo(w, color: const Color(0xFFFF7A18)),
          _paintedLayer((p) => _HalloweenPainter(progress: p)),
        ];
      case 'sparkles':
      default:
        return [
          _breathingHalo(w),
          _paintedLayer((p) => _SparklePainter(progress: p)),
        ];
    }
  }

  // Halo central qui respire (comble le vide + met le logo en valeur).
  Widget _breathingHalo(double w,
      {Color color = goldPrimary,
      Alignment align = const Alignment(0, -0.35)}) {
    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (context, _) {
        final pulse = 0.10 +
            (math.sin(_sparkleController.value * math.pi * 2) + 1) / 2 * 0.10;
        return Align(
          alignment: align,
          child: Container(
            width: w * 0.9,
            height: w * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: pulse), Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }

  // Enveloppe un CustomPainter plein écran piloté par l'horloge ambiante.
  Widget _paintedLayer(CustomPainter Function(double progress) make) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, _) =>
            CustomPaint(painter: make(_sparkleController.value)),
      ),
    );
  }

  // Dégradé « liquide » façon Apple : des couleurs qui coulent lentement.
  Widget _liquidLayer() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, _) {
          final t = _sparkleController.value;
          final a = math.sin(t * math.pi * 2);
          final b = (math.cos(t * math.pi * 2) + 1) / 2;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(a, -1),
                end: Alignment(-a, 1),
                colors: [
                  midnightPrimary.withValues(alpha: 0.0),
                  goldPrimary.withValues(alpha: 0.10 + 0.08 * b),
                  midnightSecondary.withValues(alpha: 0.28),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onConfirmed() async {
    // Petit punch haptique + flash lumineux, puis navigation
    HapticFeedback.heavyImpact();
    await _flashController.forward();
    if (!mounted) return;
    final hasUser = _restoreSession();
    // Ouverture directe sur le Live + Feed (VybzLiveScreen = index 2) au lieu de
    // l'Accueil : l'utilisateur tombe tout de suite dans "Pour toi / En direct /
    // Clips". Le X de cet écran ramène à l'Accueil (MyBottomBar index 0).
    Get.offAll(() => hasUser ? MyBottomBar(index: 2) : LoginScreen());
    // Popup « À la une » (utilisateur connecté uniquement, non bloquant,
    // silencieux en cas d'échec réseau).
    if (hasUser) unawaited(showFeaturedEventIfAny());
  }

  @override
  void dispose() {
    _softTimer?.cancel();
    _introController.dispose();
    _sparkleController.dispose();
    _flashController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Écran de relance douce : fond bleu nuit (mêmes assets que le splash),
  /// halo qui respire et logo en fondu — pas de piliers ni de slider.
  Widget _softBuild(double w, double h) {
    return Scaffold(
      backgroundColor: midnightPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _localBackgroundFallback(),
          _breathingHalo(w, align: Alignment.center),
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: _localLogo(w, h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = Get.height;
    final w = Get.width;

    if (_soft) return _softBuild(w, h);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fond : image/vidéo admin si configurée, sinon assets locaux
          _background(),

          // ── Voile de contraste (réglable depuis l'admin) : assombrit le fond
          // pour rendre le texte lisible sur n'importe quelle image.
          if (_overlayOpacity > 0)
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: _overlayOpacity)),
            ),

          // ── Couche d'effet animé (choisie depuis l'admin : paillettes,
          // égaliseur, projecteurs, dégradé liquide, bokeh, Halloween…).
          ..._effectLayers(w, h),

          // ── Contenu
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: h * 0.10),

                // Logo emblème "V" : petit -> grand (agrandi à 0.80)
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: _logo(w, h),
                  ),
                ),

                FadeTransition(
                  opacity: _taglineFade,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'LIVE CONCERTS',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Phrase courte pour combler le vide central
                      Text(
                        'Exclusive live events. Anytime. Anywhere.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          color: ivory.withValues(alpha: 0.65),
                          fontSize: 13,
                          height: 1.4,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Bloc bas : scrim sombre derrière piliers + slider (lisibilité)
                FadeTransition(
                  opacity: _taglineFade,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC071426)],
                        stops: [0.0, 0.45],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Pillar(
                              icon: Icons.explore_outlined,
                              label: 'common_discover'.tr,
                            ),
                            const _PillarDivider(),
                            const _Pillar(
                              icon: Icons.confirmation_number_outlined,
                              label: 'BOOK',
                            ),
                            const _PillarDivider(),
                            const _Pillar(icon: Icons.graphic_eq, label: 'LIVE'),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _SlideToEnter(
                          shimmer: _sparkleController,
                          onConfirmed: _onConfirmed,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Flash de transition (or -> blanc) par-dessus tout
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) {
              if (_flashController.value == 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: _flashController.value),
                          goldPrimary.withValues(
                            alpha: _flashController.value * 0.8,
                          ),
                          midnightPrimary.withValues(
                            alpha: _flashController.value,
                          ),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Paillettes dorées qui tombent.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress});
  final double progress;

  static final List<_Particle> _particles = List.generate(46, (i) {
    final rnd = math.Random(i * 7 + 3);
    return _Particle(
      x: rnd.nextDouble(),
      speed: 0.4 + rnd.nextDouble() * 0.8,
      phase: rnd.nextDouble(),
      radius: 0.6 + rnd.nextDouble() * 1.8,
      spread: 0.2 + rnd.nextDouble() * 0.6,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = goldPrimary;
    for (final p in _particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final dy = t * size.height * 0.55;
      final dx =
          (p.x + math.sin(t * math.pi * 2) * 0.02 * p.spread) * size.width;
      final opacity = (1.0 - t) * 0.9;
      paint.color = goldPrimary.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  _Particle({
    required this.x,
    required this.speed,
    required this.phase,
    required this.radius,
    required this.spread,
  });
  final double x;
  final double speed;
  final double phase;
  final double radius;
  final double spread;
}

/// Égaliseur audio : barres dorées qui dansent au rythme, avec reflet.
/// Placé dans l'espace vide entre le tagline et le bloc bas.
class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({required this.progress});
  final double progress;
  static const int _bars = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.60;
    final maxH = size.height * 0.16;
    const gap = 5.0;
    final bw = (size.width - gap * (_bars + 1)) / _bars;
    final phase2 = progress * math.pi * 2;
    for (var i = 0; i < _bars; i++) {
      final ph = i * 0.35;
      final v = (math.sin(phase2 * 3 + ph) + 1) / 2;
      final v2 = (math.sin(phase2 * 5 + ph * 1.7) + 1) / 2;
      final amp = v * 0.7 + v2 * 0.3;
      final barH = 6 + amp * maxH;
      final x = gap + i * (bw + gap);
      final rect = Rect.fromLTWH(x, baseY - barH, bw, barH);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            goldPrimary.withValues(alpha: 0.14),
            goldPrimary.withValues(alpha: 0.55),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bw / 2)),
        paint,
      );
      // Reflet doux sous la ligne de base.
      final r2 = Rect.fromLTWH(x, baseY + 2, bw, barH * 0.45);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r2, Radius.circular(bw / 2)),
        Paint()..color = goldPrimary.withValues(alpha: 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => old.progress != progress;
}

/// Projecteurs de scène : faisceaux lumineux qui balaient et convergent
/// vers le logo (mélange additif -> effet lumière).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origins = [
      Offset(size.width * 0.18, -20),
      Offset(size.width * 0.82, -20),
      Offset(size.width * 0.5, -20),
    ];
    final target = Offset(size.width * 0.5, size.height * 0.28);
    final len = size.height * 0.95;
    const halfWidth = 46.0;
    for (var i = 0; i < origins.length; i++) {
      final o = origins[i];
      final sweep = math.sin(progress * math.pi * 2 + i * 2.1) * 0.16;
      final dir = target - o;
      final ang = math.atan2(dir.dy, dir.dx) + sweep;
      final end = o + Offset(math.cos(ang), math.sin(ang)) * len;
      final perp = Offset(-math.sin(ang), math.cos(ang)) * halfWidth;
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(end.dx - perp.dx, end.dy - perp.dy)
        ..lineTo(end.dx + perp.dx, end.dy + perp.dy)
        ..close();
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            goldPrimary.withValues(alpha: 0.18),
            goldPrimary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: o, radius: len));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.progress != progress;
}

/// Lumières de foule (bokeh) : halos flous qui flottent doucement, façon
/// téléphones allumés dans le public d'un concert.
class _BokehPainter extends CustomPainter {
  _BokehPainter({required this.progress});
  final double progress;

  static final List<_Orb> _orbs = List.generate(20, (i) {
    final rnd = math.Random(i * 13 + 5);
    return _Orb(
      x: rnd.nextDouble(),
      baseY: rnd.nextDouble(),
      radius: 10 + rnd.nextDouble() * 34,
      speed: 0.15 + rnd.nextDouble() * 0.4,
      phase: rnd.nextDouble(),
      warm: rnd.nextDouble() > 0.4,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in _orbs) {
      final t = (progress * o.speed + o.phase) % 1.0;
      final y = (o.baseY - t) % 1.0 * size.height;
      final x = (o.x + math.sin((t + o.phase) * math.pi * 2) * 0.03) * size.width;
      final alpha = (math.sin(t * math.pi) * 0.5).clamp(0.0, 0.5);
      final color = o.warm ? goldPrimary : ivory;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, o.radius * 0.5);
      canvas.drawCircle(Offset(x, y), o.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BokehPainter old) => old.progress != progress;
}

class _Orb {
  _Orb({
    required this.x,
    required this.baseY,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.warm,
  });
  final double x;
  final double baseY;
  final double radius;
  final double speed;
  final double phase;
  final bool warm;
}

/// Thème Halloween : voile violet, braises orange qui montent et quelques
/// chauves-souris qui traversent lentement. Activable depuis l'admin ou
/// automatiquement pendant la période (voir backend, style "auto").
class _HalloweenPainter extends CustomPainter {
  _HalloweenPainter({required this.progress});
  final double progress;

  static const Color _orange = Color(0xFFFF7A18);
  static const Color _purple = Color(0xFF6A2CC0);

  static final List<_Particle> _embers = List.generate(40, (i) {
    final rnd = math.Random(i * 11 + 2);
    return _Particle(
      x: rnd.nextDouble(),
      speed: 0.3 + rnd.nextDouble() * 0.7,
      phase: rnd.nextDouble(),
      radius: 0.8 + rnd.nextDouble() * 2.2,
      spread: 0.3 + rnd.nextDouble() * 0.8,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Voile violet dans les coins (ambiance).
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [Colors.transparent, _purple.withValues(alpha: 0.22)],
        stops: const [0.6, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Braises orange qui montent (du bas vers le haut).
    final ember = Paint();
    for (final p in _embers) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final dy = size.height - t * size.height * 0.7;
      final dx =
          (p.x + math.sin(t * math.pi * 2) * 0.03 * p.spread) * size.width;
      final opacity = (math.sin(t * math.pi) * 0.9).clamp(0.0, 0.9);
      ember.color = Color.lerp(_orange, const Color(0xFFFFD166), t)!
          .withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), p.radius, ember);
    }

    // Quelques chauves-souris qui traversent lentement.
    for (var i = 0; i < 3; i++) {
      final t = (progress * (0.4 + i * 0.15) + i * 0.33) % 1.0;
      final bx = t * (size.width + 120) - 60;
      final by = size.height * (0.18 + i * 0.14) +
          math.sin(t * math.pi * 4) * 12;
      final flap = (math.sin(progress * math.pi * 2 * 6 + i) + 1) / 2;
      _drawBat(canvas, Offset(bx, by), 16 + i * 4.0, flap);
    }
  }

  void _drawBat(Canvas canvas, Offset c, double s, double flap) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final wing = 0.5 + flap * 0.5; // battement d'ailes
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..cubicTo(c.dx - s * 0.5, c.dy - s * wing, c.dx - s * 1.1,
          c.dy + s * 0.1, c.dx - s * 1.5, c.dy - s * 0.2)
      ..cubicTo(c.dx - s * 1.1, c.dy + s * 0.2, c.dx - s * 0.7,
          c.dy + s * 0.35, c.dx, c.dy + s * 0.25)
      ..cubicTo(c.dx + s * 0.7, c.dy + s * 0.35, c.dx + s * 1.1,
          c.dy + s * 0.2, c.dx + s * 1.5, c.dy - s * 0.2)
      ..cubicTo(c.dx + s * 1.1, c.dy + s * 0.1, c.dx + s * 0.5,
          c.dy - s * wing, c.dx, c.dy)
      ..close();
    canvas.drawPath(path, paint);
    // Petit corps.
    canvas.drawCircle(Offset(c.dx, c.dy + s * 0.05), s * 0.18, paint);
  }

  @override
  bool shouldRepaint(_HalloweenPainter old) => old.progress != progress;
}

/// Bouton "glisser pour entrer" — haptique, traînée lumineuse, halo qui suit le doigt.
class _SlideToEnter extends StatefulWidget {
  const _SlideToEnter({required this.onConfirmed, required this.shimmer});
  final VoidCallback onConfirmed;
  final Animation<double> shimmer;

  @override
  State<_SlideToEnter> createState() => _SlideToEnterState();
}

class _SlideToEnterState extends State<_SlideToEnter> {
  double _dragX = 0;
  bool _confirmed = false;
  int _lastHapticStep = 0;

  static const double _height = 62;
  static const double _knob = 54;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = constraints.maxWidth - _knob - 8;
        final pct = maxX <= 0 ? 0.0 : (_dragX / maxX).clamp(0.0, 1.0);

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: midnightPrimary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(color: goldSecondary, width: 1.4),
            boxShadow: [
              // Halo global qui s'intensifie quand on approche du bout
              BoxShadow(
                color: goldPrimary.withValues(alpha: 0.15 + pct * 0.35),
                blurRadius: 18 + pct * 22,
                spreadRadius: pct * 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Traînée lumineuse dorée derrière le curseur
                FractionallySizedBox(
                  widthFactor: (pct * 0.9 + 0.14).clamp(0.0, 1.0),
                  child: Container(
                    height: _height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          goldPrimary.withValues(alpha: 0.0),
                          goldPrimary.withValues(alpha: 0.55),
                          goldPrimary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                ),

                // Texte + lumière (shimmer) qui balaie
                Center(
                  child: AnimatedBuilder(
                    animation: widget.shimmer,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (rect) {
                          final dx =
                              (widget.shimmer.value * 2 - 0.5) * rect.width;
                          return LinearGradient(
                            colors: [
                              ivory.withValues(alpha: 0.55),
                              Colors.white,
                              ivory.withValues(alpha: 0.55),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                            begin: Alignment(-1 + dx / rect.width * 2, 0),
                            end: Alignment(1 + dx / rect.width * 2, 0),
                          ).createShader(rect);
                        },
                        child: child,
                      );
                    },
                    child: Opacity(
                      opacity: (1 - pct).clamp(0.25, 1.0),
                      child: Text(
                        'SLIDE TO ENTER  ›››',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          color: pct > 0.4 ? midnightPrimary : ivory,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Curseur draggable + halo qui suit le doigt
                Positioned(
                  left: 4 + _dragX,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      if (_confirmed) return;
                      setState(() {
                        _dragX = (_dragX + d.delta.dx).clamp(0.0, maxX);
                      });
                      // Petits crans haptiques pendant le glissement
                      final step = (pct * 5).floor();
                      if (step != _lastHapticStep) {
                        _lastHapticStep = step;
                        HapticFeedback.selectionClick();
                      }
                    },
                    onHorizontalDragEnd: (_) {
                      if (_confirmed) return;
                      if (pct > 0.85) {
                        setState(() {
                          _dragX = maxX;
                          _confirmed = true;
                        });
                        widget.onConfirmed();
                      } else {
                        HapticFeedback.lightImpact();
                        setState(() => _dragX = 0);
                      }
                    },
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: kGoldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: goldPrimary.withValues(alpha: 0.4 + pct * 0.4),
                            blurRadius: 14 + pct * 20,
                            spreadRadius: 1 + pct * 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        _confirmed ? Icons.check : Icons.arrow_forward,
                        color: midnightPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: midnightPrimary.withValues(alpha: 0.45),
            border: Border.all(color: goldSecondary, width: 1.4),
          ),
          child: Icon(icon, color: goldPrimary, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            shadows: [
              Shadow(color: Color(0xCC000000), blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillarDivider extends StatelessWidget {
  const _PillarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: goldSecondary.withValues(alpha: 0.3),
    );
  }
}

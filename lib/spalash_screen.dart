import 'dart:async';
import 'dart:math' as math;

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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

  @override
  void initState() {
    super.initState();
    _introController.forward();
  }

  void _onConfirmed() async {
    // Petit punch haptique + flash lumineux, puis navigation
    HapticFeedback.heavyImpact();
    await _flashController.forward();
    final hasUser = box.read('user') != null;
    if (hasUser) {
      userModel.value = UserModel.fromJson(box.read('user'));
      final id = userModel.value.user?.id;
      if (id != null) unawaited(SubscriptionController.syncIdentity(id));
    }
    Get.offAll(() => hasUser ? MyBottomBar() : LoginScreen());
  }

  @override
  void dispose() {
    _introController.dispose();
    _sparkleController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = Get.height;
    final w = Get.width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fond : image foule + spot doré
          Image.asset(
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
          ),

          // ── Halo doré central qui respire (comble le vide + met le logo en valeur)
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, _) {
              final pulse =
                  0.10 + (math.sin(_sparkleController.value * math.pi * 2) + 1) / 2 * 0.10;
              return Align(
                alignment: const Alignment(0, -0.35),
                child: Container(
                  width: w * 0.9,
                  height: w * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        goldPrimary.withValues(alpha: pulse),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Paillettes dorées animées
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, _) => CustomPaint(
                painter: _SparklePainter(progress: _sparkleController.value),
              ),
            ),
          ),

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
                    child: Image.asset(
                      'assets/launch_logo.png',
                      width: w * 0.80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Padding(
                        padding: EdgeInsets.symmetric(vertical: h * 0.12),
                        child: const Text(
                          'VybzzZ',
                          style: TextStyle(
                            fontFamily: AppFonts.logo,
                            color: goldPrimary,
                            fontSize: 46,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
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
                          color: goldPrimary,
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
                          children: const [
                            _Pillar(
                              icon: Icons.explore_outlined,
                              label: 'DISCOVER',
                            ),
                            _PillarDivider(),
                            _Pillar(
                              icon: Icons.confirmation_number_outlined,
                              label: 'BOOK',
                            ),
                            _PillarDivider(),
                            _Pillar(icon: Icons.graphic_eq, label: 'LIVE'),
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

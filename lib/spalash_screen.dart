import 'package:artist/Auth/login_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Global/app_fonts.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SpalashScreen extends StatefulWidget {
  const SpalashScreen({super.key});

  @override
  State<SpalashScreen> createState() => _SpalashScreenState();
}

class _SpalashScreenState extends State<SpalashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _lineWidth;
  late final Animation<double> _bottomFade;

  // Spot lumineux doré qui respire
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _lineWidth = Tween<double>(begin: 0.0, end: 120.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
      ),
    );
    _bottomFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _introController.forward();
  }

  void _enter() {
    final hasUser = box.read('user') != null;
    if (hasUser) {
      userModel.value = UserModel.fromJson(box.read('user'));
    }
    Get.offAll(() => hasUser ? MyBottomBar() : LoginScreen());
  }

  @override
  void dispose() {
    _introController.dispose();
    _glowController.dispose();
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
          // ── Fond bleu nuit
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [midnightSecondary, midnightPrimary],
              ),
            ),
          ),

          // ── Spot lumineux doré depuis le haut (qui respire)
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) {
              final intensity = 0.10 + (_glowController.value * 0.10);
              return Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: w,
                  height: h * 0.5,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.1),
                      radius: 1.0,
                      colors: [
                        goldPrimary.withValues(alpha: intensity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Foule de concert en bas (teintée bleu nuit)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: SizedBox(
                height: h * 0.42,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/live_image.png', fit: BoxFit.cover),
                    // Overlay pour fondre dans le bleu nuit + lisibilité
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            midnightPrimary,
                            Color(0x99071426),
                            Color(0xE6071426),
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenu
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: h * 0.10),

                // Wordmark + tagline (fondu + zoom + halo)
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: goldPrimary.withValues(
                                      alpha: 0.2 + _glowController.value * 0.3,
                                    ),
                                    blurRadius: 40 + _glowController.value * 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/logo7.png',
                            width: w * 0.62,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'LIVE BEGINS HERE',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            color: ivory,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedBuilder(
                          animation: _lineWidth,
                          builder: (context, _) => Container(
                            width: _lineWidth.value,
                            height: 1.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  goldPrimary.withValues(alpha: 0),
                                  goldPrimary,
                                  goldPrimary.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Les 3 piliers + CTA (fondu bas)
                FadeTransition(
                  opacity: _bottomFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            _Pillar(icon: Icons.explore_outlined, label: 'DISCOVER'),
                            _PillarDivider(),
                            _Pillar(
                              icon: Icons.confirmation_number_outlined,
                              label: 'BOOK',
                            ),
                            _PillarDivider(),
                            _Pillar(icon: Icons.graphic_eq, label: 'LIVE'),
                          ],
                        ),
                        const SizedBox(height: 30),
                        _EnterButton(onTap: _enter),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un pilier : icône ronde contour or + label Montserrat.
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
            border: Border.all(color: goldSecondary, width: 1.4),
          ),
          child: Icon(icon, color: goldPrimary, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            color: ivory,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
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

/// Bouton or dégradé "ENTER VYBZZZ →".
class _EnterButton extends StatelessWidget {
  const _EnterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: kGoldGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: goldPrimary.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ENTER VYBZZZ',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                color: midnightPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward, color: midnightPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/ai_scan_overlay.dart' show kAiAccent;
import '../widgets/app_logo.dart';
import 'home_screen.dart';

/// Animated splash: expanding scan pulses, the shield draws itself, the
/// targeting ring locks in, then the wordmark rises — and the whole thing
/// dissolves into the home screen. Pure Flutter, no packages.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _main = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1900));
  late final AnimationController _pulses = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _main.forward();
    _pulses.repeat();
    Future.delayed(const Duration(milliseconds: 2450), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _main.dispose();
    _pulses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandGreenDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _pulses]),
        builder: (context, _) {
          final t = _main.value;
          // Wordmark timing: rises and fades in over the last third.
          final textT =
              Curves.easeOut.transform(((t - 0.62) / 0.38).clamp(0.0, 1.0));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Deep gradient backdrop.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [kBrandGreen, kBrandGreenDark],
                  ),
                ),
              ),
              // Expanding scan pulses behind the mark.
              Align(
                alignment: const Alignment(0, -0.18),
                child: CustomPaint(
                  size: const Size.square(340),
                  painter: _PulsePainter(_pulses.value),
                ),
              ),
              // The mark draws itself.
              Align(
                alignment: const Alignment(0, -0.18),
                child: CustomPaint(
                  size: const Size.square(150),
                  painter: AppLogoPainter(progress: t),
                ),
              ),
              // Wordmark + tagline.
              Align(
                alignment: const Alignment(0, 0.38),
                child: Opacity(
                  opacity: textT,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - textT)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SafeStand',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CHECK BEFORE YOU PAY',
                          style: TextStyle(
                            color: kAiAccent.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer.
              Align(
                alignment: const Alignment(0, 0.92),
                child: Opacity(
                  opacity: textT * 0.6,
                  child: const Text(
                    'Works offline · A risk signal, not a legal ruling',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Concentric scan pulses radiating outward — the satellite motif.
class _PulsePainter extends CustomPainter {
  final double t;
  _PulsePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = maxR * (0.35 + 0.65 * p);
      final fade = (1 - p) * 0.35;
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..color = kAiAccent.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + 2 * (1 - p),
      );
    }
    // faint rotating sweep
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: maxR * 0.75),
      t * 2 * math.pi,
      math.pi / 5,
      false,
      Paint()
        ..color = kAiAccent.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.t != t;
}

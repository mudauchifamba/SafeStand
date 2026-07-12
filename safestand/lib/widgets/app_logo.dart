import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ai_scan_overlay.dart' show kAiAccent;

/// SafeStand brand colours.
const kBrandGreen = Color(0xFF0E6B4F);
const kBrandGreenDark = Color(0xFF073D2C);

/// The SafeStand mark: a shield (protection) holding a targeting ring
/// (the satellite/AI check). Painted in code so the exact same mark renders
/// the splash animation and generates the launcher icon.
///
/// [progress] animates the mark: 0 → nothing, 1 → fully drawn.
/// [withBackground] paints the rounded gradient tile (launcher icon style).
class AppLogoPainter extends CustomPainter {
  final double progress;
  final bool withBackground;

  AppLogoPainter({this.progress = 1.0, this.withBackground = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final u = s / 100; // unit scale: logo designed on a 100x100 grid
    final cx = size.width / 2;
    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0));

    if (withBackground) {
      final r = s * 0.22;
      final rect = RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(r));
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kBrandGreen, kBrandGreenDark],
          ).createShader(Offset.zero & size),
      );
      // soft glow behind the mark
      canvas.drawCircle(
        Offset(cx, size.height * 0.52),
        s * 0.34,
        Paint()
          ..shader = RadialGradient(colors: [
            kAiAccent.withValues(alpha: 0.22),
            kAiAccent.withValues(alpha: 0.0),
          ]).createShader(
              Rect.fromCircle(center: Offset(cx, size.height * 0.52), radius: s * 0.34)),
      );
    }

    // --- Shield outline -----------------------------------------------
    final shield = Path()
      ..moveTo(cx, 8 * u + (size.height - s) / 2)
      ..lineTo(cx + 36 * u, 20 * u + (size.height - s) / 2)
      ..lineTo(cx + 36 * u, 48 * u + (size.height - s) / 2)
      ..cubicTo(
          cx + 36 * u, 70 * u + (size.height - s) / 2,
          cx + 20 * u, 86 * u + (size.height - s) / 2,
          cx, 93 * u + (size.height - s) / 2)
      ..cubicTo(
          cx - 20 * u, 86 * u + (size.height - s) / 2,
          cx - 36 * u, 70 * u + (size.height - s) / 2,
          cx - 36 * u, 48 * u + (size.height - s) / 2)
      ..lineTo(cx - 36 * u, 20 * u + (size.height - s) / 2)
      ..close();

    final shieldPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Draw the shield progressively (trace the outline).
    if (t < 1.0) {
      for (final metric in shield.computeMetrics()) {
        canvas.drawPath(
            metric.extractPath(0, metric.length * t), shieldPaint);
      }
    } else {
      canvas.drawPath(shield, shieldPaint);
    }

    // --- Targeting ring + crosshair (appears after the shield) ---------
    final ringT =
        Curves.easeOutBack.transform(((progress - 0.55) / 0.45).clamp(0.0, 1.0));
    if (ringT > 0) {
      final centre = Offset(cx, 50 * u + (size.height - s) / 2);
      final ringPaint = Paint()
        ..color = kAiAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * u
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(centre, 15 * u * ringT, ringPaint);
      // crosshair ticks
      const tick = 6.0;
      for (final a in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          centre + dir * (15 + 3) * u * ringT,
          centre + dir * (15 + tick) * u * ringT,
          ringPaint,
        );
      }
      canvas.drawCircle(
          centre, 3.2 * u * ringT, Paint()..color = kAiAccent);
    }
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter old) =>
      old.progress != progress || old.withBackground != withBackground;
}

/// Convenience widget for static uses of the mark.
class AppLogo extends StatelessWidget {
  final double size;
  final bool withBackground;

  const AppLogo({super.key, this.size = 96, this.withBackground = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: AppLogoPainter(withBackground: withBackground),
    );
  }
}

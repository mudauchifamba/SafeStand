import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Accent colour for AI / "tech" surfaces across the app — the scan
/// animation, the AI reading card, the analyse button.
const kAiAccent = Color(0xFF19E3C2);
const kAiAccentError = Color(0xFFFF6B5E);

enum ScanState { idle, scanning, success, error }

/// A cinematic "satellite targeting" scan animation, overlaid on a tile.
///
/// Purely decorative — it signals that an AI analysis is in flight and gives
/// a short "target lock" payoff when it resolves, then fades to reveal the
/// clean imagery underneath. Intended as one child inside an already-clipped
/// Stack (see SatelliteView), so it does no clipping of its own.
class AiScanOverlay extends StatefulWidget {
  final ScanState state;

  const AiScanOverlay({super.key, required this.state});

  @override
  State<AiScanOverlay> createState() => _AiScanOverlayState();
}

class _AiScanOverlayState extends State<AiScanOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _resolve = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _syncControllers(null, widget.state);
  }

  @override
  void didUpdateWidget(covariant AiScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _syncControllers(oldWidget.state, widget.state);
    }
  }

  void _syncControllers(ScanState? from, ScanState to) {
    if (to == ScanState.scanning) {
      _loop.repeat();
      _pulse.repeat(reverse: true);
    } else {
      _loop.stop();
      _pulse.stop();
    }
    if (to == ScanState.success || to == ScanState.error) {
      _resolve
        ..reset()
        ..forward();
    } else if (to == ScanState.idle) {
      _resolve.reset();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _pulse.dispose();
    _resolve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == ScanState.idle) return const SizedBox.shrink();

    final active = widget.state == ScanState.scanning;
    final resolved = !active;
    final accent =
        widget.state == ScanState.error ? kAiAccentError : kAiAccent;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_loop, _pulse, _resolve]),
        builder: (context, _) {
          final t = _loop.value;
          final pulseT = _pulse.value;
          final resolveT = _resolve.value;
          final fadingOut = resolved && _resolve.isCompleted;

          return AnimatedOpacity(
            opacity: fadingOut ? 0 : 1,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black.withValues(
                      alpha: active ? 0.32 : 0.16 * (1 - resolveT) + 0.05),
                ),
                if (active) ...[
                  Transform.rotate(
                    angle: t * 2 * math.pi,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          colors: [
                            accent.withValues(alpha: 0),
                            accent.withValues(alpha: 0),
                            accent.withValues(alpha: 0.5),
                            accent.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.72, 0.97, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(0, -1 + 2 * t),
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          accent.withValues(alpha: 0),
                          accent,
                          accent.withValues(alpha: 0),
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: accent.withValues(alpha: 0.85),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 0.12,
                    child: CustomPaint(painter: _GridPainter(color: accent)),
                  ),
                ],
                ..._corners(
                    accent, active ? 0.55 + 0.45 * pulseT : (resolved ? 1 : 0)),
                if (resolved)
                  Center(
                    child: Container(
                      width: 36 + resolveT * 150,
                      height: 36 + resolveT * 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: (1 - resolveT) * 0.9),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Opacity(
                    opacity: active ? 0.65 + 0.35 * pulseT : 1,
                    child: Text(
                      active
                          ? 'ANALYZING SATELLITE IMAGERY…'
                          : widget.state == ScanState.success
                              ? 'AI READING COMPLETE'
                              : 'ANALYSIS FAILED',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        fontFamily: 'monospace',
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 5)
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _corners(Color color, double opacity) {
    final o = opacity.clamp(0.0, 1.0);
    return [
      _corner(Alignment.topLeft, color, o, top: true, left: true),
      _corner(Alignment.topRight, color, o, top: true, left: false),
      _corner(Alignment.bottomLeft, color, o, top: false, left: true),
      _corner(Alignment.bottomRight, color, o, top: false, left: false),
    ];
  }

  Widget _corner(Alignment alignment, Color color, double opacity,
      {required bool top, required bool left}) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Opacity(
          opacity: opacity,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(
              painter: _CornerPainter(color: color, top: top, left: left),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;

  _CornerPainter({required this.color, required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final y = top ? 0.0 : size.height;
    final x = left ? 0.0 : size.width;
    final dy = top ? size.height * 0.65 : -size.height * 0.65;
    final dx = left ? size.width * 0.65 : -size.width * 0.65;
    final path = Path()
      ..moveTo(x, y + dy)
      ..lineTo(x, y)
      ..lineTo(x + dx, y);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const divisions = 6;
    for (var i = 1; i < divisions; i++) {
      final dx = size.width / divisions * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      final dy = size.height / divisions * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

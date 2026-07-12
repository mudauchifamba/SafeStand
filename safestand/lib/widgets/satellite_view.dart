import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ai_scan_overlay.dart';

/// Shows free Esri World Imagery satellite tiles for a coordinate, so a
/// remote buyer can see with their own eyes what the claimed location looks
/// like (packed settlement vs bare land vs wetland).
///
/// This is the one SafeStand feature that needs internet — acceptable because
/// the remote-check user is by definition online (diaspora). It degrades
/// gracefully to a text note when offline.
class SatelliteView extends StatelessWidget {
  final double lat;
  final double lon;
  final String caption;
  final int zoom;
  final ScanState scanState;

  const SatelliteView({
    super.key,
    required this.lat,
    required this.lon,
    required this.caption,
    this.zoom = 16,
    this.scanState = ScanState.idle,
  });

  // Web-Mercator fractional tile coordinates for the centre point.
  (double, double) _tileXYf() {
    final n = (1 << zoom).toDouble();
    final x = (lon + 180) / 360 * n;
    final latRad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            n;
    return (x.clamp(0, n - 1), y.clamp(0, n - 1));
  }

  String _url(int x, int y) =>
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
      'MapServer/tile/$zoom/$y/$x';

  @override
  Widget build(BuildContext context) {
    final (xf, yf) = _tileXYf();
    final cx = xf.floor();
    final cy = yf.floor();
    // Exact point's position within the 3x3 grid, as a 0..1 fraction.
    final fx = (xf - (cx - 1)) / 3;
    final fy = (yf - (cy - 1)) / 3;

    final frameColor = scanState == ScanState.idle
        ? Theme.of(context).colorScheme.outlineVariant
        : kAiAccent.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: frameColor, width: 1.4),
            boxShadow: scanState == ScanState.idle
                ? null
                : [
                    BoxShadow(
                        color: kAiAccent.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 1),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // 3x3 tile grid around the centre = roughly 700m x 700m at z16.
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GridView.count(
                    crossAxisCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var dy = -1; dy <= 1; dy++)
                        for (var dx = -1; dx <= 1; dx++)
                          Image.network(
                            _url(cx + dx, cy + dy),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            loadingBuilder: (c, child, p) => p == null
                                ? child
                                : Container(
                                    color: Colors.black12,
                                    child: const Center(
                                        child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))),
                                  ),
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.black12,
                              child: const Center(
                                  child: Icon(Icons.cloud_off, size: 18)),
                            ),
                          ),
                    ],
                  ),
                  // Crosshair marking the exact coordinate being shown.
                  Align(
                    alignment: FractionalOffset(fx, fy),
                    child: const IgnorePointer(
                      child: Icon(Icons.add_circle_outline,
                          size: 34,
                          color: Colors.redAccent,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4)
                          ]),
                    ),
                  ),
                  AiScanOverlay(state: scanState),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$caption\nCentred on ${lat.toStringAsFixed(5)}, '
          '${lon.toStringAsFixed(5)} (red marker).',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(height: 1.4),
        ),
        Text(
          'Imagery © Esri World Imagery. Needs internet; shown for context '
          'only.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

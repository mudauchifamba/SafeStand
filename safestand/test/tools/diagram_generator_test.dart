// Renders the system architecture diagram to docs/architecture_diagram.png.
// Regenerate after architecture changes:
//   flutter test test/tools/diagram_generator_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _green = Color(0xFF0E6B4F);
const _greenDark = Color(0xFF073D2C);
const _teal = Color(0xFF0FA98F); // AI accent, darkened for white paper
const _tealFill = Color(0xFFE2F7F2);
const _greenFill = Color(0xFFE7F1EC);
const _greyFill = Color(0xFFF3F4F4);
const _ink = Color(0xFF1E2523);

/// flutter_test renders the placeholder "Ahem" font by default; load real
/// Roboto faces from the Flutter SDK so the PNG has readable text.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  expect(root, isNotNull, reason: 'FLUTTER_ROOT not set');
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final bytes = File('$dir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void _text(Canvas c, String s, Offset centre, double width,
    {double size = 17,
    FontWeight weight = FontWeight.w400,
    Color color = _ink}) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.3)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: width);
  tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
}

void _box(Canvas c, Rect r, String title, List<String> lines,
    {Color fill = Colors.white,
    Color border = _green,
    Color titleColor = _ink,
    bool dashed = false}) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
  c.drawRRect(rr, Paint()..color = fill);
  final borderPaint = Paint()
    ..color = border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  if (dashed) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, d + 9), borderPaint);
        d += 15;
      }
    }
  } else {
    c.drawRRect(rr, borderPaint);
  }

  if (lines.isEmpty) {
    _text(c, title, r.center, r.width - 28,
        size: 18, weight: FontWeight.w700, color: titleColor);
    return;
  }
  final cy = r.center.dy;
  _text(c, title, Offset(r.center.dx, cy - 13 - (lines.length - 1) * 9),
      r.width - 28,
      size: 18, weight: FontWeight.w700, color: titleColor);
  _text(c, lines.join('\n'),
      Offset(r.center.dx, cy + 13 + (lines.length - 1) * 1), r.width - 28,
      size: 14, color: _ink.withValues(alpha: 0.75));
}

void _arrow(Canvas c, Offset from, Offset to,
    {Color color = _green, bool dashed = false}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  final line = Path()
    ..moveTo(from.dx, from.dy)
    ..lineTo(to.dx, to.dy);
  if (dashed) {
    for (final m in line.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  } else {
    c.drawPath(line, paint);
  }
  final dir = (to - from);
  final len = dir.distance;
  final u = Offset(dir.dx / len, dir.dy / len);
  final n = Offset(-u.dy, u.dx);
  final head = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(to.dx - u.dx * 12 + n.dx * 6, to.dy - u.dy * 12 + n.dy * 6)
    ..lineTo(to.dx - u.dx * 12 - n.dx * 6, to.dy - u.dy * 12 - n.dy * 6)
    ..close();
  c.drawPath(head, Paint()..color = color);
}

void main() {
  test('generate architecture diagram PNG', () async {
    await _loadFonts();

    const w = 1730.0, h = 1170.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

    _text(c, 'SafeStand — System Architecture', const Offset(w / 2, 40), w,
        size: 30, weight: FontWeight.w800, color: _greenDark);
    _text(
        c,
        'v1 has no backend server — the phone is the system. Offline by '
        'default; online AI only when the user invokes it.',
        const Offset(w / 2, 76),
        w - 200,
        size: 15.5,
        color: _ink.withValues(alpha: 0.7));

    // Users
    _box(c, const Rect.fromLTWH(170, 106, 420, 64), 'Local home-seeker',
        ['works fully offline'],
        fill: _greenFill);
    _box(c, const Rect.fromLTWH(880, 106, 420, 64), 'Diaspora buyer',
        ['online, checking remotely'],
        fill: _greenFill);

    // App container
    const app = Rect.fromLTWH(60, 208, 1330, 830);
    c.drawRRect(RRect.fromRectAndRadius(app, const Radius.circular(16)),
        Paint()..color = const Color(0xFFFAFBFB));
    c.drawRRect(
        RRect.fromRectAndRadius(app, const Radius.circular(16)),
        Paint()
          ..color = _greenDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _text(c, 'SafeStand app  ·  Flutter (Android)  ·  all core logic on-device',
        const Offset(725, 236), 1200,
        size: 16.5, weight: FontWeight.w700, color: _greenDark);

    _arrow(c, const Offset(380, 170), const Offset(380, 262));
    _arrow(c, const Offset(1090, 170), const Offset(1090, 262));

    // ---- Flow 1
    _text(c, 'FLOW 1 — SCAN A DOCUMENT  (fully offline)',
        const Offset(380, 288), 560,
        size: 14.5, weight: FontWeight.w800, color: _green);
    _box(c, const Rect.fromLTWH(140, 312, 480, 62), 'Camera / gallery',
        ['photograph the offer letter or agreement of sale']);
    _arrow(c, const Offset(380, 374), const Offset(380, 402));
    _box(c, const Rect.fromLTWH(140, 402, 480, 62), 'ML Kit OCR   [AI-1]',
        ['on-device text recognition, incl. stamp text'],
        fill: _tealFill, border: _teal);
    _arrow(c, const Offset(380, 464), const Offset(380, 492));
    _box(
        c,
        const Rect.fromLTWH(140, 492, 480, 78),
        'Trained fraud classifier  [AI-2 — ours]',
        ['TF-IDF + logistic regression · ~50 KB · offline · 17/17 held-out'],
        fill: _tealFill,
        border: _teal);
    _arrow(c, const Offset(380, 570), const Offset(380, 598));
    _box(c, const Rect.fromLTWH(140, 598, 480, 62), 'Red-flag rule engine',
        ['explainability layer — model decides, rules explain'],
        fill: _greyFill, border: _ink.withValues(alpha: 0.45));

    // ---- Flow 2
    _text(c, 'FLOW 2 — CHECK A STAND  (offline core + optional online AI)',
        const Offset(1090, 288), 640,
        size: 14.5, weight: FontWeight.w800, color: _green);
    _box(c, const Rect.fromLTWH(790, 312, 600, 62), 'Inputs',
        ['claimed area · seller · stand no. · pin · seller\'s photos']);
    _arrow(c, const Offset(940, 374), const Offset(915, 402));
    _arrow(c, const Offset(1240, 374), const Offset(1265, 402));
    _box(
        c,
        const Rect.fromLTWH(790, 402, 280, 104),
        'Offline checks',
        ['documented cases DB · wetlands DB', 'EXIF forensics · pin geometry'],
        fill: _greenFill);
    _box(
        c,
        const Rect.fromLTWH(1110, 402, 280, 104),
        'Online AI   [AI-3]',
        ['3a satellite land-class + vlei signs', '3b photo content — judged BLIND'],
        fill: _tealFill,
        border: _teal);
    _arrow(c, const Offset(1250, 506), const Offset(1250, 534));
    _box(c, const Rect.fromLTWH(1110, 534, 280, 78), 'Cross-examination',
        ['deterministic code compares 3a vs 3b', 'the AI never grades itself'],
        fill: _greyFill, border: _ink.withValues(alpha: 0.45));

    // ---- Scorer + verdict
    _arrow(c, const Offset(380, 660), const Offset(565, 722));
    _arrow(c, const Offset(930, 506), const Offset(775, 718));
    _arrow(c, const Offset(1250, 612), const Offset(935, 722));
    _box(
        c,
        const Rect.fromLTWH(430, 722, 640, 74),
        'Deterministic risk scorer  (unit-tested)',
        ['combines every signal · no AI in the final arithmetic'],
        fill: Colors.white,
        border: _greenDark);
    _arrow(c, const Offset(750, 796), const Offset(750, 824));

    const verdict = Rect.fromLTWH(430, 824, 640, 84);
    _box(c, verdict, '', []);
    _text(c, 'GREEN / AMBER / RED verdict', const Offset(762, 852), 560,
        size: 18.5, weight: FontWeight.w800);
    _text(c, 'plain-language cited reasons  +  authority next steps',
        const Offset(750, 882), 600,
        size: 14, color: _ink.withValues(alpha: 0.75));
    for (final (i, col) in [
      const Color(0xFF2E7D32),
      const Color(0xFFEF6C00),
      const Color(0xFFC62828)
    ].indexed) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(460 + i * 26.0, 842, 18, 18),
              const Radius.circular(5)),
          Paint()..color = col);
    }

    // ---- Bundled data strip (ambient: grounds every check)
    _box(
        c,
        const Rect.fromLTWH(140, 940, 1250, 66),
        'Bundled data  ·  versioned JSON, ~100 KB, cited sources',
        ['known cases · red-flag rules · gazetteer · wetlands · classifier weights'],
        fill: _greenFill);

    // ---- External services (right column, outside the app)
    _box(
        c,
        const Rect.fromLTWH(1460, 402, 240, 86),
        'Esri World Imagery',
        ['satellite tiles'],
        dashed: true,
        border: _teal,
        fill: Colors.white);
    _box(
        c,
        const Rect.fromLTWH(1460, 522, 240, 86),
        'Groq API',
        ['vision LLM (Llama-4)'],
        dashed: true,
        border: _teal,
        fill: Colors.white);
    _arrow(c, const Offset(1460, 440), const Offset(1394, 440),
        dashed: true, color: _teal);
    _arrow(c, const Offset(1460, 560), const Offset(1394, 480),
        dashed: true, color: _teal);
    _text(c, 'HTTPS · online only\ninvoked explicitly by the user',
        const Offset(1580, 650), 230,
        size: 13.5, color: _ink.withValues(alpha: 0.65));

    // ---- Legend
    _text(c, 'Legend:', const Offset(120, 1094), 200,
        size: 15, weight: FontWeight.w800, color: _greenDark);
    void chip(double x, Color fill, Color border, String label, double lw) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 1084, 20, 20), const Radius.circular(6)),
          Paint()..color = fill);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 1084, 20, 20), const Radius.circular(6)),
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _text(c, label, Offset(x + 30 + lw / 2, 1094), lw + 40, size: 14.5);
    }

    chip(180, _tealFill, _teal, 'AI component', 100);
    chip(360, _greenFill, _green, 'curated data (cited)', 140);
    chip(590, _greyFill, _ink.withValues(alpha: 0.45), 'deterministic code',
        130);

    // Render at 2x for print quality.
    final picture = rec.endRecording();
    final rec2 = ui.PictureRecorder();
    final c2 = Canvas(rec2);
    c2.scale(2, 2);
    c2.drawPicture(picture);

    final bytes = await (await rec2
            .endRecording()
            .toImage((w * 2).toInt(), (h * 2).toInt()))
        .toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/architecture_diagram.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
  });
}

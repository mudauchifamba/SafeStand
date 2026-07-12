// Not a test in the usual sense: renders the AppLogoPainter to the PNGs
// flutter_launcher_icons consumes. Run when the logo changes:
//   flutter test test/tools/icon_generator_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safestand/widgets/app_logo.dart';

Future<void> _savePng(String path, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate launcher icon PNGs', () async {
    const size = 1024.0;

    // Full icon: gradient tile + mark (legacy/round icon).
    {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      AppLogoPainter(withBackground: true)
          .paint(canvas, const Size.square(size));
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      await _savePng('assets/icon/app_icon.png', img);
    }

    // Adaptive foreground: mark only, centred in the ~66% safe zone,
    // transparent background.
    {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      const inset = size * 0.22;
      canvas.translate(inset, inset);
      AppLogoPainter().paint(canvas, const Size.square(size - 2 * inset));
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      await _savePng('assets/icon/app_icon_foreground.png', img);
    }

    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
  });
}

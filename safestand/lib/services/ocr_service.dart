import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin wrapper around ML Kit's on-device text recognizer.
///
/// Runs entirely offline — no image or text leaves the device. This matters
/// both for privacy (users are sharing a document tied to their savings) and
/// for reach (the buyers most at risk often have unreliable mobile data).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract all text from an image file at [imagePath].
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  void dispose() {
    _recognizer.close();
  }
}
